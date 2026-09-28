import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/title_quality.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/domain/models/screenshot_item.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/archive/archive_provider.dart';
import 'package:screenshot_zero/features/archive/data/archive_repository_io.dart';
import 'package:screenshot_zero/features/archive/archive_detail.dart';
import 'package:screenshot_zero/shared/widgets/imported_image_view.dart';
import 'package:screenshot_zero/features/analysis/multimodal/hybrid_analysis.dart';
import 'package:screenshot_zero/features/analysis/multimodal/multimodal_service.dart';
import 'package:screenshot_zero/app/router.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';

import 'multimodal_test.dart' show local, response, MemoryConsent;
import 'archive_persistence_test.dart' show sample;
import 'widget_test.dart' show launch, tapText;
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  testWidgets(
    'Archive lazily renders 250 records and Home counts persisted entries',
    (tester) async {
      final container = await launch(tester);
      final controller = container.read(archiveProvider.notifier);
      for (var i = 0; i < 250; i++) {
        await controller.save(
          sample('/missing.png', ScreenshotIntent.reference, 'Saved reference'),
        );
      }
      container.read(inboxProvider.notifier).replaceCollection([]);
      container.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
      expect(find.text('250'), findsOneWidget);
      container.read(routerProvider).go('/home/archive');
      await tester.pumpAndSettle();
      expect(find.byType(ImportedImageView).evaluate().length, lessThan(20));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'development archive clear requires confirmation and preserves demo',
    (tester) async {
      final container = await launch(tester);
      await container
          .read(archiveProvider.notifier)
          .save(
            sample(
              '/missing.png',
              ScreenshotIntent.reference,
              'Saved reference',
            ),
          );
      container.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Demo options'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Clear development archive');
      await tapText(tester, 'Cancel');
      expect(container.read(archiveProvider).items, hasLength(1));
      await tester.tap(find.byTooltip('Demo options'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Clear development archive');
      await tapText(tester, 'Clear archive');
      expect(container.read(archiveProvider).items, isEmpty);
      expect(container.read(inboxProvider), hasLength(8));
    },
  );
  test('weak counts, chrome, timestamps and numeric noise are rejected without rejecting entities', () {
    for (final text in [
      '284 members',
      '19 Transactions',
      '9:41',
      '87%',
      'Back',
      'Settings',
      '1234 5678 9012',
      'x' * 110,
    ]) {
      expect(TitleQuality.weak(text), true, reason: text);
    }
    for (final text in [
      'Assignment 12',
      'iPhone 17',
      'A small-town concert',
      'Sunday Table',
      'Campus Research Symposium',
    ]) {
      expect(TitleQuality.weak(text), false, reason: text);
    }
  });
  test('reference summaries use evidence, not fixed screenshot titles', () {
    expect(TitleQuality.reference('19 transactions'), 'Transactions');
    expect(
      TitleQuality.reference('Today: 2100 calories protein 80g'),
      'Nutrition summary',
    );
    expect(
      TitleQuality.reference('284 members', text: 'Study group\n284 members'),
      'Group details',
    );
    expect(TitleQuality.reference('284 members'), 'Saved reference');
    expect(TitleQuality.reference('ExampleBrand'), 'Saved reference');
    expect(
      TitleQuality.reference('Learning to sketch trees'),
      'Learning to sketch trees',
    );
  });
  test('strong visual Reference replaces brand fragment but not strong local entities', () {
    final hybrid = HybridAnalysis(
      service: const UnavailableMultimodalService(),
      consent: MemoryConsent(true),
    );
    final resolved = hybrid.resolve(
      local('ExampleBrand'),
      MultimodalResult.fromJson(response(title: 'Kitchen appliance')),
    );
    expect(resolved.title, 'Kitchen appliance');
    expect(resolved.intent, ScreenshotIntent.reference);
    expect(resolved.subtitle, TitleQuality.referenceCopy);
    final task = local('Assignment 12\nDue May 12, 2027\nSubmit PDF');
    expect(
      hybrid.resolve(
        task,
        MultimodalResult.fromJson(
          response(category: 'task', title: 'Homework'),
        ),
      ),
      same(task),
    );
    expect(
      hybrid
          .resolve(
            local(),
            MultimodalResult.fromJson(response(title: '284 members')),
          )
          .title,
      TitleQuality.referenceFallback,
    );
  });
  test('250 records retain original bytes, independent of decoy UI image; restart numbering and debug clear', () async {
    final temp = await Directory.systemTemp.createTemp('polish-archive-');
    addTearDown(() => temp.delete(recursive: true));
    final source = await File('test/fixtures/orientation/orientation-6.jpg')
        .copy('${temp.path}/import.jpg');
    final decoy = File('${temp.path}/rendered-ui.png');
    await decoy.writeAsBytes([1, 2, 3, 4]);
    final repo = FileArchiveRepository(
      directory: () async => Directory('${temp.path}/support'),
    );
    var container = ProviderContainer(
      overrides: [archiveRepositoryProvider.overrideWithValue(repo)],
    );
    for (var i = 0; i < 125; i++) {
      expect(
        await container
            .read(archiveProvider.notifier)
            .save(
              sample(
                source.path,
                ScreenshotIntent.reference,
                'Saved reference',
              ),
            ),
        true,
      );
    }
    container.dispose();
    container = ProviderContainer(
      overrides: [archiveRepositoryProvider.overrideWithValue(repo)],
    );
    await container.read(archiveProvider.notifier).ensureReady();
    for (var i = 125; i < 250; i++) {
      expect(
        await container
            .read(archiveProvider.notifier)
            .save(
              sample(
                source.path,
                ScreenshotIntent.reference,
                'Saved reference',
              ),
            ),
        true,
      );
    }
    final watch = Stopwatch()..start();
    final records = await repo.load();
    watch.stop();
    debugPrint('250-record archive reload: ${watch.elapsedMilliseconds}ms');
    expect(records, hasLength(250));
    expect(
      records.map((item) => item.archiveNumber).toSet(),
      Set.of(List.generate(250, (i) => i + 1)),
    );
    expect(
      records.map((item) => item.importedImage!.path).toSet(),
      hasLength(1),
    );
    expect(
      await File(records.first.importedImage!.path).readAsBytes(),
      await source.readAsBytes(),
    );
    expect(
      await File(records.first.importedImage!.path).readAsBytes(),
      isNot(await decoy.readAsBytes()),
    );
    expect(
      await container.read(archiveProvider.notifier).clearDevelopment(),
      true,
    );
    expect(await repo.load(), isEmpty);
    expect(await source.exists(), true);
    expect(await decoy.exists(), true);
    container.dispose();
  });
  testWidgets('long actionable titles fit stack and archive with large text', (
    tester,
  ) async {
    final container = await launch(
      tester,
      size: const Size(360, 640),
      scale: 1.6,
    );
    final item = ScreenshotItem(
      id: 99,
      title: List.filled(12, 'A long research symposium title').join(' '),
      intent: ScreenshotIntent.event,
      subtitle: 'A long venue and address with details that wrap naturally',
      metadata: const [],
      artwork: ScreenshotArtwork.exhibition,
      primaryAction: 'Add to Calendar',
      archiveLabel: 'Saved event',
    );
    container.read(inboxProvider.notifier).replaceCollection([item]);
    container.read(routerProvider).go('/home/stack');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Save');
    await tapText(tester, 'View archive');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(item.title));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'legacy reference display cleanup hides obsolete copy without mutating record',
    (tester) async {
      const item = ScreenshotItem(
        id: 1,
        title: '284 members',
        intent: ScreenshotIntent.reference,
        subtitle: 'We couldn’t confidently identify an action.',
        metadata: [],
        importedImage: ImportedImage(path: '/missing.jpg', name: 'Test image'),
        primaryAction: 'Save Reference',
        archiveLabel: 'Saved reference',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArchiveDetail(item: item, showDiagnostics: false),
          ),
        ),
      );
      expect(find.text(TitleQuality.referenceCopy), findsOneWidget);
      expect(find.text('284 members'), findsNothing);
      expect(item.title, '284 members');
      expect(find.textContaining('OCR diagnostics'), findsNothing);
    },
  );
}
