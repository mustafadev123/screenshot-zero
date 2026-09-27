import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/page_frame.dart';
import 'subscription_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);
    if (subscription.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) {
          context.pop(true);
        }
      });
    }
    return PageFrame(
      label: 'Screenshot Zero Pro',
      showBack: true,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
          for (final package in subscription.packages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PrimaryButton(
                label:
                    'START PRO · ${package.price}${package.period.isEmpty ? '' : ' / ${package.period}'}',
                onPressed: subscription.loading
                    ? null
                    : () => _purchase(package.identifier),
              ),
            ),
          TextButton(
            onPressed: subscription.loading ? null : _restore,
            child: const Text('Restore purchases'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          28,
          AppSpacing.page,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MetaLabel('A CLEARER ROLL'),
            const SizedBox(height: 18),
            Text(
              'Keep clearing.',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 18),
            const Text(
              'Screenshot Zero Pro keeps the darkroom open for every screenshot that comes next.',
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 18),
            const _ProLine('Unlimited screenshot processing'),
            const _ProLine('Batch screenshot analysis'),
            const _ProLine('Future premium intelligence features'),
            const SizedBox(height: 26),
            if (subscription.loading)
              const Center(child: CircularProgressIndicator())
            else if (subscription.packages.isEmpty)
              Text(
                subscription.error ??
                    'Pro offerings are unavailable right now.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.graphite),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(String identifier) async {
    final result = await ref
        .read(subscriptionProvider.notifier)
        .purchase(identifier);
    if (!mounted || result.succeeded || result.result.name == 'cancelled') {
      return;
    }
    setState(() => _message = result.message ?? 'Purchase was not completed.');
  }

  Future<void> _restore() async {
    final result = await ref.read(subscriptionProvider.notifier).restore();
    if (!mounted) return;
    setState(() {
      _message = result.succeeded
          ? 'Pro restored.'
          : result.message ?? 'No active Pro purchase found.';
    });
  }
}

class _ProLine extends StatelessWidget {
  const _ProLine(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        const Icon(Icons.check, size: 18, color: AppColors.signal),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
