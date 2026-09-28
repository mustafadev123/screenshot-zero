import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/app/app.dart';
import 'package:screenshot_zero/app/router.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';
import 'package:screenshot_zero/features/archive/archive_provider.dart';
import 'package:screenshot_zero/features/archive/data/archive_repository.dart';
import 'package:screenshot_zero/mock/mock_screenshots.dart';
import 'package:screenshot_zero/shared/widgets/page_frame.dart';

import 'support/test_fonts.dart';
import 'support/fake_image_import_service.dart';

import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/features/import_preview/import_provider.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/actions/screenshot_action_service.dart';
import 'package:screenshot_zero/features/subscription/analysis_quota.dart';
import 'package:screenshot_zero/features/subscription/subscription_provider.dart';

Future<ProviderContainer> launch(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool reduceMotion = false,
  ImageImportService? importService,
  ScreenshotTextExtractor? textExtractor,
  ScreenshotActionService? actionService,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final container = ProviderContainer(
    overrides: [
      archiveRepositoryProvider.overrideWithValue(MemoryArchiveRepository()),
      analysisQuotaStoreProvider.overrideWithValue(MemoryAnalysisQuotaStore()),
      revenueCatServiceProvider.overrideWithValue(FakeRevenueCatService()),
      if (actionService != null)
        screenshotActionServiceProvider.overrideWithValue(actionService),
      imageImportServiceProvider.overrideWithValue(
        importService ?? FakeImageImportService(),
      ),
      screenshotTextExtractorProvider.overrideWithValue(
        textExtractor ?? EmptyScreenshotTextExtractor(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ScreenshotZeroApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);
  testWidgets(
    'onboarding, eight demo actions, zero, archive, detail and reset',
    (tester) async {
      final container = await launch(tester);
      expect(
        find.text('Your screenshots are unfinished intentions.'),
        findsOneWidget,
      );
      await tapText(tester, 'Next');
      expect(find.text('From saved.\nTo done.'), findsOneWidget);
      await tapText(tester, 'Next');
      await tapText(tester, 'Start with screenshots');
      expect(find.text('08'), findsOneWidget);
      await tapText(tester, 'Continue clearing');
      for (final item in mockScreenshots) {
        expect(find.text(item.title), findsOneWidget);
        await tapText(tester, item.primaryAction.toUpperCase());
        expect(tester.takeException(), isNull);
      }
      expect(find.text('You’re clear.'), findsOneWidget);
      expect(
        container.read(inboxProvider).where((item) => item.processed).length,
        8,
      );
      await tapText(tester, 'View archive');
      await tapText(tester, 'EVENTS');
      expect(find.text('Evening Echoes'), findsOneWidget);
      expect(find.text('Sunday Table'), findsNothing);
      await tapText(tester, 'Evening Echoes');
      expect(
        find.text('Demo record · no external action was taken'.toUpperCase()),
        findsOneWidget,
      );
      await tapText(tester, 'Back to archive');
      await tester.tap(find.byTooltip('Back to home'));
      await tester.pumpAndSettle();
      expect(find.text('00'), findsOneWidget);
      await tester.tap(find.byTooltip('Demo options'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Reset demo');
      expect(find.text('08'), findsOneWidget);
      expect(
        container.read(inboxProvider).every((item) => !item.processed),
        isTrue,
      );
    },
  );

  testWidgets(
    'mixed skip, save and primary actions reach zero without skipped cards',
    (tester) async {
      final container = await launch(tester);
      container.read(routerProvider).go('/home/stack');
      await tester.pumpAndSettle();
      await tapText(tester, 'Skip');
      expect(find.text('Sunday Table'), findsOneWidget);
      expect(
        container.read(inboxProvider).any((item) => item.id == 1),
        isFalse,
      );
      expect(find.text('SKIPPED FOR NOW'), findsOneWidget);
      expect(
        container.read(inboxProvider).where((item) => item.processed),
        isEmpty,
      );
      await tapText(tester, 'Save');
      expect(
        container
            .read(inboxProvider)
            .singleWhere((item) => item.id == 2)
            .savedOnly,
        isTrue,
      );
      for (final item in mockScreenshots.skip(2).take(5)) {
        await tapText(tester, item.primaryAction.toUpperCase());
      }
      expect(find.text(mockScreenshots.last.title), findsOneWidget);
      await tapText(tester, 'Skip');
      expect(find.text('You’re clear.'), findsOneWidget);
      expect(container.read(routerProvider).state.uri.path, '/home/zero');
      expect(container.read(inboxProvider).length, 6);
      expect(
        container.read(inboxProvider).every((item) => item.processed),
        isTrue,
      );
    },
  );

  testWidgets('consecutive skips dismiss every card and reach Inbox Zero', (
    tester,
  ) async {
    final container = await launch(tester);
    container.read(routerProvider).go('/home/stack');
    await tester.pumpAndSettle();
    for (final item in mockScreenshots) {
      expect(find.text(item.title), findsOneWidget);
      await tapText(tester, 'Skip');
      expect(
        container.read(inboxProvider).any((current) => current.id == item.id),
        isFalse,
      );
    }
    expect(container.read(inboxProvider), isEmpty);
    expect(container.read(archiveProvider).items, isEmpty);
    expect(container.read(routerProvider).state.uri.path, '/home/zero');
    expect(find.text('You’re clear.'), findsOneWidget);
    container.read(routerProvider).go('/home/stack');
    await tester.pumpAndSettle();
    expect(find.text('You’re clear.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  for (final scenario in [
    (360.0, 640.0, 1.0),
    (430.0, 932.0, 1.0),
    (360.0, 640.0, 1.6),
  ]) {
    testWidgets(
      'screens fit ${scenario.$1}x${scenario.$2}, text ${scenario.$3}',
      (tester) async {
        final container = await launch(
          tester,
          size: Size(scenario.$1, scenario.$2),
          scale: scenario.$3,
          reduceMotion: true,
        );
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Next');
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Next');
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Explore demo');
        expect(tester.takeException(), isNull);
        for (final route in ['/home/import', '/home/stack', '/home/archive']) {
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
        }
        container.read(routerProvider).go('/home/stack');
        await tester.pumpAndSettle();
        for (final item in mockScreenshots) {
          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: item.title);
        }
        expect(find.text('You’re clear.'), findsOneWidget);
        await tapText(tester, 'View archive');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
