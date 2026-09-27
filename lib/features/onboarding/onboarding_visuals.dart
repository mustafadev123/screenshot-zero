import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../mock/mock_screenshots.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/screenshot_art.dart';

class OnboardingStack extends StatelessWidget {
  const OnboardingStack({super.key, this.cleared = false});
  final bool cleared;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: motionDuration(context, 850),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight * .8;
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var index = 2; index >= 0; index--)
                Transform.translate(
                  offset: Offset((index - 1) * 37 * value, index * 6),
                  child: Transform.rotate(
                    angle: (index - 1) * .13 * value,
                    child: Container(
                      width: height * .77,
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: .08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ScreenshotArt(
                        item: mockScreenshots[cleared ? index + 5 : index],
                      ),
                    ),
                  ),
                ),
              if (cleared)
                Positioned(
                  bottom: 4,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.signal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const MetaLabel(
                      'A little less later.',
                      color: AppColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class TransformationVisual extends StatelessWidget {
  const TransformationVisual({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = (constraints.maxHeight - 24) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 24,
        children: [
          for (final (index, label, icon) in [
            (0, 'Calendar', Icons.calendar_today_outlined),
            (1, 'Maps', Icons.near_me_outlined),
            (2, 'Wishlist', Icons.bookmark_border),
            (4, 'Reminder', Icons.schedule),
          ])
            SizedBox(
              width: (constraints.maxWidth - 16) / 2,
              height: height,
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: .9,
                      child: Transform.rotate(
                        angle: index.isEven ? -.045 : .045,
                        child: ScreenshotArt(item: mockScreenshots[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right,
                        size: 15,
                        color: AppColors.signal,
                      ),
                      const SizedBox(width: 6),
                      Icon(icon, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
