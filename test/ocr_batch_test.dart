import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/features/import_preview/import_provider.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';

import 'support/fake_image_import_service.dart';

class ControlledExtractor implements ScreenshotTextExtractor {
  final requests = <ImportedImage>[];
  final completions = <Completer<ExtractedTextResult>>[];
  @override
  Future<ExtractedTextResult> extract(ImportedImage image) {
    requests.add(image);
    final completer = Completer<ExtractedTextResult>();
    completions.add(completer);
    return completer.future;
  }
}

void main() {
  final images = List.generate(
    3,
    (i) => ImportedImage(path: '/tmp/$i.png', name: '$i.png'),
  );
  late ControlledExtractor extractor;
  late ProviderContainer container;
  setUp(() {
    extractor = ControlledExtractor();
    container = ProviderContainer(
      overrides: [
        screenshotTextExtractorProvider.overrideWithValue(extractor),
        imageImportServiceProvider.overrideWithValue(
          FakeImageImportService()..result = ImageImportResult(images: images),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  test(
    'batch stays sequential and a failed image preserves subsequent items',
    () async {
      final controller = container.read(importProvider.notifier);
      await controller.pick();
      final processing = controller.process();
      expect(container.read(importProvider).progress, 'Reading 1 of 3');
      expect(extractor.requests.length, 1);
      expect(await controller.process(), isFalse);
      extractor.completions[0].complete(
        const ExtractedTextResult(
          text: 'Assignment 8\nDue May 12, 2027\nSubmit PDF',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(importProvider).progress, 'Reading 2 of 3');
      extractor.completions[1].completeError(StateError('broken file'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(importProvider).progress, 'Reading 3 of 3');
      extractor.completions[2].complete(
        const ExtractedTextResult(text: 'Concert\nMay 12, 2027\n7 PM'),
      );
      expect(await processing, isTrue);
      final items = container.read(inboxProvider);
      expect(items.map((i) => i.intent), [
        ScreenshotIntent.task,
        ScreenshotIntent.reference,
        ScreenshotIntent.event,
      ]);
      expect(items[1].title, 'Unsorted screenshot');
      for (var i = 0; i < images.length; i++) {
        expect(items[i].importedImage, same(images[i]));
        expect(items[i].artwork, isNull);
      }
      container.read(inboxProvider.notifier).process(items.first.id);
      expect(
        container.read(inboxProvider).first.rawOcrText,
        items.first.rawOcrText,
      );
      container.read(inboxProvider.notifier).reset();
      expect(container.read(inboxProvider), hasLength(8));
      expect(
        container.read(inboxProvider).every((i) => i.importedImage == null),
        isTrue,
      );
      expect(extractor.requests.length, 3);
    },
  );
  test('cancelled OCR cannot overwrite a reset demo collection', () async {
    final controller = container.read(importProvider.notifier);
    await controller.pick();
    final processing = controller.process();
    controller.clear();
    container.read(inboxProvider.notifier).reset();
    extractor.completions.single.complete(
      const ExtractedTextResult(text: 'Concert May 12 7 PM'),
    );
    expect(await processing, isFalse);
    expect(extractor.requests.length, 1);
    expect(container.read(inboxProvider), hasLength(8));
    expect(container.read(importProvider).busy, isFalse);
  });
}
