import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/archive/archive_screen.dart';
import '../features/home/home_screen.dart';
import '../features/import_preview/import_preview_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/zero_stack/inbox_provider.dart';
import '../features/zero_stack/inbox_zero_screen.dart';
import '../features/zero_stack/zero_stack_screen.dart';
import '../features/subscription/paywall_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'import',
            builder: (_, _) => const ImportPreviewScreen(),
          ),
          GoRoute(path: 'stack', builder: (_, _) => const ZeroStackScreen()),
          GoRoute(
            path: 'zero',
            redirect: (_, _) =>
                ref.read(inboxProvider).any((item) => !item.processed)
                ? '/home/stack'
                : null,
            builder: (_, _) => const InboxZeroScreen(),
          ),
          GoRoute(path: 'archive', builder: (_, _) => const ArchiveScreen()),
          GoRoute(path: 'pro', builder: (_, _) => const PaywallScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
