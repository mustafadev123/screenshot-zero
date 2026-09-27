import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/app/app.dart';
import 'package:screenshot_zero/app/router.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';
import 'package:screenshot_zero/mock/mock_screenshots.dart';

import '../test/support/test_fonts.dart';
import '../test/support/fake_image_import_service.dart';

import 'package:screenshot_zero/features/import_preview/import_provider.dart';

void main() {
  setUpAll(loadTestFonts);
  testWidgets('capture prototype screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        imageImportServiceProvider.overrideWithValue(FakeImageImportService()),
      ],
    );
    addTearDown(container.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: boundary, child: const ScreenshotZeroApp()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('01-onboarding');
    for (var page = 2; page <= 3; page++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await capture('01-onboarding-$page');
    }
    for (final (name, path) in [
      ('02-home', '/home'),
      ('03-import', '/home/import'),
      ('04-stack', '/home/stack'),
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      await capture(name);
    }
    for (final item in mockScreenshots) {
      container.read(inboxProvider.notifier).process(item.id);
    }
    for (final (name, path) in [
      ('05-zero', '/home/zero'),
      ('06-archive', '/home/archive'),
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      await capture(name);
    }
  });
}
