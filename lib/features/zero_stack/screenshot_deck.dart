import 'package:flutter/material.dart';

import '../../domain/models/screenshot_item.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/screenshot_image.dart';

class ScreenshotDeck extends StatelessWidget {
  const ScreenshotDeck({super.key, required this.waiting});
  final List<ScreenshotItem> waiting;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 300 / 390,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (waiting.length > 1)
            Positioned.fill(
              left: 8,
              right: 8,
              top: 10,
              bottom: -10,
              child: Transform.rotate(
                angle: .035,
                child: ScreenshotImage(item: waiting[1], radius: 12),
              ),
            ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: motionDuration(context),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.07, .025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: SizedBox.expand(
                key: ValueKey(waiting.first.id),
                child: ScreenshotImage(item: waiting.first, radius: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
