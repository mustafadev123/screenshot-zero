import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/features/import_preview/import_provider.dart';
import 'package:screenshot_zero/features/subscription/analysis_quota.dart';
import 'package:screenshot_zero/features/subscription/subscription_provider.dart';

import 'support/fake_image_import_service.dart';

class FixedExtractor implements ScreenshotTextExtractor {
  @override
  Future<ExtractedTextResult> extract(ImportedImage image) async =>
      const ExtractedTextResult(text: 'Remember this');
}

ProviderContainer makeContainer({required bool pro, int used = 0}) {
  final store = MemoryAnalysisQuotaStore()..count = used;
  return ProviderContainer(
    overrides: [
      analysisQuotaStoreProvider.overrideWithValue(store),
      revenueCatServiceProvider.overrideWithValue(
        FakeRevenueCatService(pro: pro),
      ),
      screenshotTextExtractorProvider.overrideWithValue(FixedExtractor()),
      imageImportServiceProvider.overrideWithValue(FakeImageImportService()),
    ],
  );
}

Future<ImportProcessResult> processImages(
  ProviderContainer container,
  int count,
) async {
  final service =
      container.read(imageImportServiceProvider) as FakeImageImportService;
  service.result = ImageImportResult(
    images: List.generate(
      count,
      (index) => ImportedImage(path: '/tmp/$index.png', name: '$index.png'),
    ),
  );
  await container.read(importProvider.notifier).pick();
  return container.read(importProvider.notifier).processWithResult();
}

void main() {
  test('free users can process from zero and one image at 9 of 10', () async {
    final zero = makeContainer(pro: false);
    expect(
      (await processImages(zero, 1)).outcome,
      ImportProcessOutcome.processed,
    );
    zero.dispose();

    final nine = makeContainer(pro: false, used: 9);
    expect(
      (await processImages(nine, 1)).outcome,
      ImportProcessOutcome.processed,
    );
    nine.dispose();
  });

  test(
    'free users are blocked at the limit without losing selection',
    () async {
      final container = makeContainer(pro: false, used: 10);
      final service =
          container.read(imageImportServiceProvider) as FakeImageImportService;
      service.result = ImageImportResult(
        images: [const ImportedImage(path: '/tmp/one.png', name: 'one.png')],
      );
      await container.read(importProvider.notifier).pick();
      final result = await container
          .read(importProvider.notifier)
          .processWithResult();
      expect(result.outcome, ImportProcessOutcome.requiresPro);
      expect(container.read(importProvider).images, hasLength(1));
      container.dispose();
    },
  );

  test('Pro users can process unlimited batches', () async {
    final container = makeContainer(pro: true, used: 10);
    expect(
      (await processImages(container, 20)).outcome,
      ImportProcessOutcome.processed,
    );
    container.dispose();
  });

  test('cancelled import and removed images do not consume quota', () async {
    final store = MemoryAnalysisQuotaStore();
    final service = FakeImageImportService();
    final container = ProviderContainer(
      overrides: [
        analysisQuotaStoreProvider.overrideWithValue(store),
        revenueCatServiceProvider.overrideWithValue(
          FakeRevenueCatService(pro: false),
        ),
        screenshotTextExtractorProvider.overrideWithValue(FixedExtractor()),
        imageImportServiceProvider.overrideWithValue(service),
      ],
    );
    await container.read(importProvider.notifier).pick();
    expect(store.count, 0);
    service.result = ImageImportResult(
      images: [
        const ImportedImage(path: '/tmp/removed.png', name: 'removed.png'),
      ],
    );
    await container.read(importProvider.notifier).pick();
    container.read(importProvider.notifier).removeAt(0);
    expect(store.count, 0);
    container.dispose();
  });

  test(
    'purchase and restore update entitlement state through the provider',
    () async {
      final service = FakeRevenueCatService(pro: false);
      final container = ProviderContainer(
        overrides: [revenueCatServiceProvider.overrideWithValue(service)],
      );
      final subscription = container.read(subscriptionProvider.notifier);
      await subscription.ensureReady();
      expect(container.read(subscriptionProvider).isPro, isFalse);
      await subscription.purchase('monthly');
      expect(container.read(subscriptionProvider).isPro, isTrue);
      expect((await subscription.restore()).succeeded, isTrue);
      container.dispose();
    },
  );
}
