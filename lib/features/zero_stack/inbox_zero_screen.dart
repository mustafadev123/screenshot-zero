import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/page_frame.dart';
import '../import_preview/import_button.dart';

class InboxZeroScreen extends StatelessWidget {
  const InboxZeroScreen({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    label: 'Inbox Zero',
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: 'View archive',
          onPressed: () => context.go('/home/archive'),
        ),
        const ImportButton(label: 'Import more'),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - AppSpacing.page * 2,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motionDuration(context, 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(scale: .95 + .05 * value, child: child),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MetaLabel('Everything in its place'),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -.07,
                      child: Container(
                        width: 180,
                        height: 210,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Text(
                      '0',
                      style: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(fontSize: 220),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(width: 28, height: 3, color: AppColors.signal),
                const SizedBox(height: 24),
                Text(
                  'You’re clear.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing waiting. Everything has a place.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
