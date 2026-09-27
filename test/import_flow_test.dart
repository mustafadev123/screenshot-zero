import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/app/router.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/features/import_preview/import_provider.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';
import 'package:screenshot_zero/shared/widgets/imported_image_view.dart';
import 'package:screenshot_zero/shared/widgets/page_frame.dart';

import 'support/fake_image_import_service.dart';
import 'support/test_fonts.dart';
import 'widget_test.dart' show launch, tapText;

List<ImportedImage> selectedImages(int count) => List.generate(
  count,
  (i) => ImportedImage(
    path: File('test/fixtures/selected${i % 3 == 0 ? '' : '-${i % 3}'}.png')
        .absolute
        .path,
    name: 'Screenshot ${i + 1}.png',
  ),
);

void main() {
  setUpAll(loadTestFonts);

  for (final size in [const Size(360, 640), const Size(430, 932)]) {
    testWidgets(
      'real files preview, remove, skip/save, completion and archive at $size',
      (tester) async {
        final images = selectedImages(3);
        final service = FakeImageImportService()
          ..result = ImageImportResult(images: images);
        final container = await launch(
          tester,
          importService: service,
          size: size,
        );
        await tapText(tester, 'Skip intro');
        final previous = container.read(inboxProvider);
        await tester.runAsync(() => tapText(tester, 'Import screenshots'));
        expect(find.text('3 selected'), findsOneWidget);
        expect(container.read(inboxProvider), same(previous));
        expect(find.byType(ImportedImageView), findsWidgets);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null),
          isTrue,
        );
        final decoded =
            tester.widgetList<Image>(find.byType(Image)).first.image
                as ResizeImage;
        expect(decoded.imageProvider, isA<FileImage>());
        expect(
          (decoded.imageProvider as FileImage).file.path,
          images.first.path,
        );
        expect(decoded.policy, ResizeImagePolicy.fit);
        await tester.tap(find.byTooltip('Remove screenshot 2'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        await tapText(tester, 'Process 2 screenshots');
        expect(container.read(importProvider).images, isEmpty);
        expect(container.read(inboxProvider).length, 2);
        expect(
          container.read(inboxProvider).first.importedImage,
          same(images.first),
        );
        expect(
          container.read(inboxProvider).every((item) => item.artwork == null),
          isTrue,
        );
        expect(find.text('01 / 02'), findsOneWidget);
        await tapText(tester, 'Skip');
        expect(
          container.read(inboxProvider).first.importedImage,
          same(images.last),
        );
        await tapText(tester, 'Save');
        expect(find.text('02 / 02'), findsOneWidget);
        await tapText(tester, 'SAVE REFERENCE');
        expect(find.text('You’re clear.'), findsOneWidget);
        await tapText(tester, 'View archive');
        expect(find.byType(ImportedImageView), findsNWidgets(2));
        expect(
          container.read(inboxProvider).every((item) => item.processed),
          isTrue,
        );
        await tester.tap(find.text('Unsorted screenshot').first);
        await tester.pumpAndSettle();
        expect(find.byType(ImportedImageView), findsNWidgets(3));
        await tapText(tester, 'Back to archive');
        container.read(routerProvider).go('/onboarding');
        await tester.pumpAndSettle();
        await tapText(tester, 'Next');
        await tapText(tester, 'Next');
        await tapText(tester, 'Explore demo');
        expect(container.read(inboxProvider).length, 8);
        expect(
          container
              .read(inboxProvider)
              .every((item) => item.importedImage == null),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancel/error preserve existing inbox; double taps open one picker',
    (tester) async {
      final service = FakeImageImportService();
      final container = await launch(tester, importService: service);
      await tapText(tester, 'Skip intro');
      container.read(inboxProvider.notifier).process(1);
      final previous = container.read(inboxProvider);
      await tapText(tester, 'Import screenshots');
      expect(container.read(routerProvider).state.uri.path, '/home');
      expect(container.read(inboxProvider), same(previous));
      expect(find.byType(SnackBar), findsNothing);
      service.result = const ImageImportResult(
        notice: 'Couldn’t open those images. Please try again.',
      );
      await tapText(tester, 'Import screenshots');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(container.read(inboxProvider), same(previous));
      final pending = Completer<ImageImportResult>();
      service.pending = pending.future;
      final first = container.read(importProvider.notifier).pick();
      final second = await container.read(importProvider.notifier).pick();
      expect(second, isFalse);
      expect(service.pickCount, 3);
      pending.complete(const ImageImportResult());
      await first;
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'single selection, empty preview and image failure at large text',
    (tester) async {
      final service = FakeImageImportService()
        ..result = ImageImportResult(
          images: [
            ImportedImage(
              path: File('test/fixtures/does-not-exist.png').absolute.path,
              name: 'Unavailable image',
            ),
          ],
        );
      final container = await launch(
        tester,
        importService: service,
        size: const Size(360, 640),
        scale: 1.6,
      );
      await tapText(tester, 'Skip intro');
      await tapText(tester, 'Import screenshots');
      expect(find.text('Process 1 screenshot'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Image unavailable'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove screenshot 1'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      expect(find.text('Choose screenshots'), findsOneWidget);
      expect(container.read(inboxProvider).length, 8);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('20 selected images stay removable in the contact sheet', (
    tester,
  ) async {
    final service = FakeImageImportService()
      ..result = ImageImportResult(
        images: selectedImages(20),
        notice:
            'You can add up to 20 images at a time. The first 20 are selected.',
      );
    final container = await launch(
      tester,
      importService: service,
      size: const Size(360, 640),
    );
    await tapText(tester, 'Skip intro');
    await tapText(tester, 'Import screenshots');
    expect(find.text('20 selected'), findsOneWidget);
    expect(find.textContaining('first 20'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Remove screenshot 20'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Remove screenshot 20'));
    await tester.pumpAndSettle();
    expect(find.text('Process 19 screenshots'), findsOneWidget);
    await tapText(tester, 'Process 19 screenshots');
    expect(find.text('01 / 19'), findsOneWidget);
    expect(container.read(inboxProvider).length, 19);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup recovers selected images into preview only once', (
    tester,
  ) async {
    final service = FakeImageImportService()
      ..recovery = ImageImportResult(images: selectedImages(1));
    final container = await launch(tester, importService: service);
    expect(find.text('1 selected'), findsOneWidget);
    expect(container.read(inboxProvider).length, 8);
    await container.read(importProvider.notifier).recover();
    expect(service.recoverCount, 1);
    expect(tester.takeException(), isNull);
  });
}
