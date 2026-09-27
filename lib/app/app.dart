import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import '../features/import_preview/import_provider.dart';
import '../features/subscription/subscription_provider.dart';
import 'app_keys.dart';

class ScreenshotZeroApp extends ConsumerStatefulWidget {
  const ScreenshotZeroApp({super.key});

  @override
  ConsumerState<ScreenshotZeroApp> createState() => _ScreenshotZeroAppState();
}

class _ScreenshotZeroAppState extends ConsumerState<ScreenshotZeroApp> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.paper,
        systemNavigationBarColor: AppColors.paper,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverSelection());
    // Eagerly refresh the same RevenueCat service used by the paywall,
    // purchase, restore, and entitlement listener paths.
    ref.read(subscriptionProvider.notifier).ensureReady();
  }

  Future<void> _recoverSelection() async {
    if (!mounted) return;
    final recovered = await ref.read(importProvider.notifier).recover();
    if (!mounted) return;
    if (recovered) {
      ref.read(routerProvider).go('/home/import');
    } else {
      final notice = ref.read(importProvider).notice;
      if (notice != null) {
        screenshotZeroMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Screenshot Zero',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: screenshotZeroMessengerKey,
    theme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    routerConfig: ref.watch(routerProvider),
  );
}
