import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/screenshot_image.dart';
import '../zero_stack/inbox_provider.dart';
import '../import_preview/import_button.dart';
import '../import_preview/import_provider.dart';
import '../subscription/analysis_quota.dart';
import '../subscription/subscription_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider);
    final waiting = items.where((item) => !item.processed).toList();
    final processed = items.length - waiting.length;
    return PageFrame(
      label: 'Screenshot Zero',
      showBack: false,
      trailing: PopupMenuButton<String>(
        tooltip: 'Demo options',
        itemBuilder: (_) {
          final subscription = ref.read(subscriptionProvider);
          return [
            PopupMenuItem(
              value: 'pro',
              child: Text(
                subscription.isPro
                    ? 'Screenshot Zero Pro · Active'
                    : 'Upgrade to Pro',
              ),
            ),
            const PopupMenuItem(
              value: 'restore',
              child: Text('Restore purchases'),
            ),
            if (kDebugMode)
              const PopupMenuItem(
                value: 'reset-quota',
                child: Text('Reset free usage'),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'reset', child: Text('Reset demo')),
            const PopupMenuItem(
              value: 'intro',
              child: Text('Replay introduction'),
            ),
          ];
        },
        onSelected: (value) {
          if (value == 'reset') {
            ref.read(importProvider.notifier).clear();
            ref.read(inboxProvider.notifier).reset();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Demo reset. Eight fresh intentions.'),
              ),
            );
          } else if (value == 'pro') {
            context.go('/home/pro');
          } else if (value == 'restore') {
            ref.read(subscriptionProvider.notifier).restore().then((result) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message ?? 'No active Pro purchase found.',
                  ),
                ),
              );
            });
          } else if (value == 'reset-quota') {
            ref.read(analysisQuotaProvider.notifier).reset();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Free usage reset for this build.')),
            );
          } else {
            context.go('/onboarding');
          }
        },
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                const SizedBox(
                  width: 6,
                  height: 6,
                  child: ColoredBox(color: AppColors.signal),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaLabel(
                    items.any((item) => item.importedImage != null)
                        ? 'Your screenshot inbox'
                        : 'Demo screenshot inbox',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              label: '${waiting.length} screenshots waiting',
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: motionDuration(context),
                    child: Text(
                      waiting.length.toString().padLeft(2, '0'),
                      key: ValueKey(waiting.length),
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(fontSize: 174),
                    ),
                  ),
                ),
              ),
            ),
            Text('waiting', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(
              waiting.isEmpty
                  ? 'A little room for what’s next.'
                  : 'Things you saved for later.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            if (waiting.isNotEmpty)
              SizedBox(
                height: 112,
                child: Row(
                  children: [
                    for (final item in waiting.take(4))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Transform.rotate(
                            angle: item.id.isEven ? .035 : -.035,
                            child: ScreenshotImage(item: item),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: MetaLabel('Nothing waiting. Everything has a place.'),
              ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: waiting.isEmpty ? 'Enjoy your zero' : 'Continue clearing',
              onPressed: () =>
                  context.go(waiting.isEmpty ? '/home/zero' : '/home/stack'),
            ),
            const Center(child: ImportButton()),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Summary(label: 'Today', count: processed),
                ),
                Expanded(
                  child: _Summary(label: 'This week', count: processed),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            TextButton(
              onPressed: () => context.go('/home/archive'),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('The archive')),
                  Text(processed.toString().padLeft(2, '0')),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: MetaLabel('A little less later.')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MetaLabel(label),
      const SizedBox(height: 8),
      Text(
        '$count processed',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.ink),
      ),
    ],
  );
}
