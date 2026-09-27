import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.label,
    required this.child,
    this.footer,
    this.trailing,
    this.showBack = true,
    this.onBack,
  });
  final String label;
  final Widget child;
  final Widget? footer;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        tooltip: 'Back to home',
                        onPressed: onBack ?? () => context.go('/home'),
                        icon: const Icon(Icons.arrow_back, size: 21),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.crop_free, size: 22),
                      ),
                    Expanded(child: MetaLabel(label, color: AppColors.ink)),
                    ?trailing,
                  ],
                ),
              ),
              Expanded(child: child),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    12,
                    AppSpacing.page,
                    12,
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MetaLabel extends StatelessWidget {
  const MetaLabel(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: textAlign,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, size: 20),
        ],
      ),
    ),
  );
}

Duration motionDuration(BuildContext context, [int milliseconds = 320]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
