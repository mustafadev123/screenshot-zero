import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/multimodal/hybrid_analysis.dart';
import 'package:screenshot_zero/features/analysis/multimodal/multimodal_service.dart';
import 'package:screenshot_zero/features/analysis/multimodal/visual_consent.dart';
import 'package:screenshot_zero/features/analysis/screenshot_analyzer.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/features/import_preview/import_provider.dart';
import 'package:screenshot_zero/features/subscription/analysis_quota.dart';
import 'package:screenshot_zero/features/subscription/subscription_provider.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';

import 'support/fake_image_import_service.dart';

class MemoryConsent implements VisualConsentStore {
  MemoryConsent(this.value);
  bool? value;
  @override
  Future<bool?> read() async => value;
  @override
  Future<void> write(bool allowed) async {
    value = allowed;
  }
}

class MockVisualService implements MultimodalAnalysisService {
  MockVisualService(this.response);
  final Future<String> Function() response;
  int calls = 0;
  MultimodalRequest? lastRequest;
  @override
  bool get available => true;
  @override
  Future<MultimodalResult> analyze(MultimodalRequest request) async {
    calls++;
    lastRequest = request;
    return MultimodalResult.fromJson(await response());
  }
}

class FailingConsent extends MemoryConsent {
  FailingConsent() : super(null);
  @override
  Future<void> write(bool allowed) async =>
      throw StateError('Storage unavailable');
}

const image = ImportedImage(
  path: '/image.png',
  name: 'not-used-for-classification.png',
);
ScreenshotAnalysisResult local([String text = '']) =>
    const HeuristicScreenshotAnalyzer().analyze(
      image: image,
      text: ExtractedTextResult(text: text),
    );
String response({
  String category = 'reference',
  String title = 'Food photo',
  double confidence = .9,
  List<String> evidence = const [],
  Map<String, String> fields = const {},
}) => jsonEncode({
  'category': category,
  'title': title,
  'confidence': confidence,
  'reason': 'Visible evidence only',
  'evidence': evidence,
  ...fields,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final choice in ['Continue', 'Not now']) {
    testWidgets('visual disclosure returns explicit $choice decision', (
      tester,
    ) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await requestVisualConsent(context);
              },
              child: const Text('Analyze'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('recognized text may be sent'),
        findsOneWidget,
      );
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      expect(answer, choice == 'Continue');
    });
  }
  test('failed consent persistence prevents upload', () async {
    final service = MockVisualService(() async => response());
    final original = local();
    final result =
        await HybridAnalysis(
          service: service,
          consent: FailingConsent(),
        ).refine(
          image: image,
          local: original,
          isPro: true,
          requestConsent: () async => true,
        );
    expect(result, same(original));
    expect(service.calls, 0);
  });
  test('cancelled session ignores a late model result', () async {
    final pending = Completer<String>();
    final started = Completer<void>();
    final service = MockVisualService(() {
      started.complete();
      return pending.future;
    });
    var active = true;
    final original = local();
    final result =
        HybridAnalysis(service: service, consent: MemoryConsent(true)).refine(
          image: image,
          local: original,
          isPro: true,
          stillActive: () => active,
        );
    await started.future;
    active = false;
    pending.complete(response());
    expect(await result, same(original));
  });
  test(
    'empty food image gives descriptive Reference; raw reason is not exposed',
    () async {
      final service = MockVisualService(() async => response());
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(true),
      ).refine(image: image, local: local(), isPro: true);
      expect(result.intent, ScreenshotIntent.reference);
      expect(result.title, 'Food photo');
      expect(result.metadata, isEmpty);
      expect(service.lastRequest!.ocrText, isEmpty);
      expect(service.lastRequest!.image, same(image));
    },
  );
  for (final scenario in [
    (
      'product',
      'Everyday Runner',
      'shopping_controls',
      {'price': r'$89', 'variant': 'Chalk', 'size': '9'},
    ),
    (
      'event',
      'Evening concert',
      'event_details',
      {'date': 'October 12, 2027', 'time': '7 PM', 'venue': 'Town Hall'},
    ),
  ]) {
    test(
      'weak OCR plus evidenced ${scenario.$1} normalizes existing actions',
      () async {
        final service = MockVisualService(
          () async => response(
            category: scenario.$1,
            title: scenario.$2,
            evidence: [scenario.$3],
            fields: scenario.$4,
          ),
        );
        final result = await HybridAnalysis(
          service: service,
          consent: MemoryConsent(true),
        ).refine(image: image, local: local('tiny'), isPro: true);
        expect(result.intent.name, scenario.$1);
        expect(result.title, scenario.$2);
        expect(
          result.primaryAction,
          scenario.$1 == 'product' ? 'Add to Wishlist' : 'Add to Calendar',
        );
        expect(
          result.extractedFields[scenario.$1 == 'product' ? 'color' : 'venue'],
          scenario.$1 == 'product' ? 'Chalk' : 'Town Hall',
        );
      },
    );
  }
  for (final text in [
    'Assignment 8\nDue May 12, 2027\nSubmit PDF',
    'Running shoes\n\$89\nSize 9\nAdd to cart',
  ]) {
    test('strong local result never invokes visual analysis: $text', () async {
      final service = MockVisualService(() async => response());
      final original = local(text);
      expect(original.confidence, greaterThanOrEqualTo(.8));
      final result =
          await HybridAnalysis(
            service: service,
            consent: MemoryConsent(null),
          ).refine(
            image: image,
            local: original,
            isPro: true,
            requestConsent: () => throw StateError('Must not ask'),
          );
      expect(result, same(original));
      expect(service.calls, 0);
    });
  }
  for (final failure in ['offline', 'malformed', 'timeout']) {
    test('$failure preserves exact local result', () async {
      final service = MockVisualService(() async {
        if (failure == 'offline') throw StateError('network unavailable');
        if (failure == 'timeout') return Completer<String>().future;
        return '{broken';
      });
      final original = local();
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(true),
        policy: const FallbackPolicy(timeout: Duration(milliseconds: 10)),
      ).refine(image: image, local: original, isPro: true);
      expect(result, same(original));
    });
  }
  test('unconfigured adapter preserves local without asking consent', () async {
    final original = local();
    final result =
        await HybridAnalysis(
          service: const UnavailableMultimodalService(),
          consent: MemoryConsent(null),
        ).refine(
          image: image,
          local: original,
          isPro: true,
          requestConsent: () => throw StateError('Must not ask'),
        );
    expect(result, same(original));
  });
  test(
    'low confidence remains Reference and object alone never becomes Product',
    () async {
      final hybrid = HybridAnalysis(
        service: const UnavailableMultimodalService(),
        consent: MemoryConsent(true),
      );
      expect(
        hybrid
            .resolve(
              local(),
              MultimodalResult.fromJson(
                response(category: 'product', confidence: .4),
              ),
            )
            .intent,
        ScreenshotIntent.reference,
      );
      final object = hybrid.resolve(
        local(),
        MultimodalResult.fromJson(
          response(category: 'product', title: 'Running shoes'),
        ),
      );
      expect(object.intent, ScreenshotIntent.reference);
      expect(object.primaryAction, 'Save Reference');
      expect(object.title, 'Running shoes');
    },
  );
  test('conflicting high confidence resolves to Reference; same category stays local', () {
    final hybrid = HybridAnalysis(
      service: const UnavailableMultimodalService(),
      consent: MemoryConsent(true),
    );
    final task = local('Assignment 8\nDue May 12, 2027\nSubmit PDF');
    expect(
      hybrid
          .resolve(
            task,
            MultimodalResult.fromJson(response(category: 'product')),
          )
          .intent,
      ScreenshotIntent.reference,
    );
    expect(
      hybrid.resolve(
        task,
        MultimodalResult.fromJson(response(category: 'task')),
      ),
      same(task),
    );
  });
  test('decline persisted, free gating, and missing consent callback prevent uploads', () async {
    final service = MockVisualService(() async => response());
    final consent = MemoryConsent(null);
    final hybrid = HybridAnalysis(service: service, consent: consent);
    var prompts = 0;
    Future<bool> decline() async {
      prompts++;
      return false;
    }

    await hybrid.refine(
      image: image,
      local: local(),
      isPro: false,
      requestConsent: decline,
    );
    await hybrid.refine(image: image, local: local(), isPro: true);
    expect(prompts, 0);
    await hybrid.refine(
      image: image,
      local: local(),
      isPro: true,
      requestConsent: decline,
    );
    await hybrid.refine(
      image: image,
      local: local(),
      isPro: true,
      requestConsent: decline,
    );
    expect(prompts, 1);
    expect(consent.value, false);
    expect(service.calls, 0);
  });
  test('consent survives store recreation, acceptance precedes upload; cancellation prevents it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesVisualConsentStore();
    final service = MockVisualService(() async {
      expect(await SharedPreferencesVisualConsentStore().read(), true);
      return response();
    });
    final hybrid = HybridAnalysis(service: service, consent: store);
    await hybrid.refine(
      image: image,
      local: local(),
      isPro: true,
      requestConsent: () async => true,
    );
    expect(service.calls, 1);
    await hybrid.refine(
      image: image,
      local: local(),
      isPro: true,
      stillActive: () => false,
    );
    expect(service.calls, 1);
    await store.write(false);
    expect(await SharedPreferencesVisualConsentStore().read(), false);
  });
  test('strict JSON rejects unknown types, fields, categories, fenced output and unsafe URLs', () {
    for (final raw in [
      '[]',
      '```json\n{}\n```',
      response(category: 'new_intent'),
      response(confidence: 1.2),
      response(title: ''),
      response(fields: {'url': 'javascript:alert(1)'}),
      response(fields: {'unexpected': 'value'}),
      response(evidence: ['shoe']),
      '{"category":"product","title":7,"confidence":0.9,"reason":"x"}',
    ]) {
      expect(() => MultimodalResult.fromJson(raw), throwsFormatException);
    }
  });
  test('real import integration uses Pro snapshot, refines once, counts quota once', () async {
    final visual = MockVisualService(() async => response());
    final revenueCat = FakeRevenueCatService()..pro = true;
    final container = ProviderContainer(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(revenueCat),
        analysisQuotaStoreProvider.overrideWithValue(
          MemoryAnalysisQuotaStore(),
        ),
        imageImportServiceProvider.overrideWithValue(
          FakeImageImportService()
            ..result = const ImageImportResult(images: [image]),
        ),
        screenshotTextExtractorProvider.overrideWithValue(
          EmptyScreenshotTextExtractor(),
        ),
        multimodalServiceProvider.overrideWithValue(visual),
        visualConsentStoreProvider.overrideWithValue(MemoryConsent(true)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(importProvider.notifier);
    await controller.pick();
    expect(await controller.process(), true);
    expect(container.read(inboxProvider).single.title, 'Food photo');
    expect(container.read(analysisQuotaProvider), 1);
    expect(visual.calls, 1);
  });
}
