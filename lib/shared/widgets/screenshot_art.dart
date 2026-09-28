import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/models/screenshot_item.dart';
import 'screenshot_illustration.dart';

/// A fixed-size, local screenshot facsimile, scaled like an image asset.
class ScreenshotArt extends StatelessWidget {
  const ScreenshotArt({super.key, required this.item, this.radius = 4});
  final ScreenshotItem item;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${item.title}, demo screenshot',
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 300,
            height: 390,
            child: MediaQuery.withNoTextScaling(
              child: _Artwork(artwork: item.artwork!),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.artwork});
  final ScreenshotArtwork artwork;

  Widget type(
    String text,
    double size, {
    Color color = AppColors.ink,
    bool serif = false,
    double spacing = 0,
    FontWeight weight = FontWeight.w500,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      height: 1.02,
      color: color,
      letterSpacing: spacing,
      fontFamily: serif ? 'serif' : 'Roboto',
      fontWeight: weight,
    ),
  );

  Widget get rule => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: artwork == ScreenshotArtwork.concert
        ? AppColors.ink
        : AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: switch (artwork) {
        ScreenshotArtwork.concert => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type(
              'LIVE / WORLD TOUR 2026',
              9,
              color: AppColors.paper,
              spacing: 2,
            ),
            const SizedBox(height: 22),
            type(
              'EVENING',
              43,
              color: AppColors.paper,
              spacing: -2,
              weight: FontWeight.w800,
            ),
            const SizedBox(height: 5),
            type(
              'ECHOES / LIVE SESSION',
              10,
              color: AppColors.paper,
              spacing: 2,
            ),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.orbit),
            ),
            type('OCT 18   /   ATLANTA', 20, color: AppColors.paper),
            const SizedBox(height: 9),
            type(
              'RIVERSIDE HALL · 7:30 PM',
              9,
              color: AppColors.paper,
              spacing: 1,
            ),
          ],
        ),
        ScreenshotArtwork.restaurant => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type('THE NEIGHBORHOOD GUIDE', 9, spacing: 1.8),
            rule,
            type('Sunday\nTable.', 42, serif: true),
            const SizedBox(height: 12),
            const Expanded(
              child: ColoredBox(
                color: AppColors.wash,
                child: ScreenshotIllustration(kind: IllustrationKind.plate),
              ),
            ),
            const SizedBox(height: 14),
            type('Good food. Long afternoons.', 16, serif: true),
            const SizedBox(height: 8),
            type('48 PEACHTREE ST.  /  ATLANTA', 9, spacing: 1),
          ],
        ),
        ScreenshotArtwork.shoes => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                type('STRIDE®', 20, weight: FontWeight.w900),
                type('SHOP / 03', 9),
              ],
            ),
            const SizedBox(height: 20),
            type('Made for\nthe everyday.', 31, spacing: -1),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.shoe),
            ),
            rule,
            type('Everyday runner', 20),
            const SizedBox(height: 8),
            type(
              'CLOUD / CHALK                                      \$120',
              10,
            ),
            const SizedBox(height: 16),
            Container(
              height: 29,
              color: AppColors.ink,
              alignment: Alignment.center,
              child: type(
                'CHOOSE YOUR SIZE',
                9,
                color: AppColors.paper,
                spacing: 2,
              ),
            ),
          ],
        ),
        ScreenshotArtwork.article => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type('The Sunday Edit', 26, serif: true),
            rule,
            type('CULTURE     /     ISSUE 042', 9, spacing: 1),
            const SizedBox(height: 18),
            type('The art of\npaying\nattention.', 37, serif: true),
            const SizedBox(height: 14),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.window),
            ),
            const SizedBox(height: 14),
            type(
              'A slower way to see the everyday.\nWords by Nora Ellis · 6 min read',
              11,
              serif: true,
            ),
          ],
        ),
        ScreenshotArtwork.assignment => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type('STUDIO / UNIVERSITY', 11, spacing: 2),
            rule,
            type('DES 204', 12, color: AppColors.graphite),
            const SizedBox(height: 16),
            type('Design\nresearch\nessay', 39, spacing: -1.5),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.wash,
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 20),
                  const SizedBox(width: 12),
                  type('OCT 02 · 11:59 PM', 12),
                ],
              ),
            ),
            const SizedBox(height: 22),
            type(
              '01   Observe an everyday object.\n\n02   Document its design decisions.\n\n03   Submit 1,500 words as a PDF.',
              12,
            ),
            const Spacer(),
            type('ASSIGNMENT 04 / FALL SEMESTER', 9, spacing: 1),
          ],
        ),
        ScreenshotArtwork.reference => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type('FIELD NOTES     /     NO. 016', 9, spacing: 1.5),
            rule,
            type('A better cup\nof coffee.', 35, serif: true),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.coffee),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [type('1:16', 32), type('94°', 32), type('3:00', 32)],
            ),
            const SizedBox(height: 9),
            type(
              'RATIO                      WATER                   TIME',
              9,
              spacing: 1,
            ),
            rule,
            type('Bloom 30 sec. Pour slowly. Enjoy.', 12, serif: true),
          ],
        ),
        ScreenshotArtwork.exhibition => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            type('WESTSIDE GALLERY', 10, spacing: 2),
            const SizedBox(height: 18),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.window),
            ),
            const SizedBox(height: 20),
            type('After\nthe light', 45, serif: true),
            rule,
            type('CONTEMPORARY PHOTOGRAPHY', 9, spacing: 1),
            const SizedBox(height: 10),
            type('06 NOV 2026  /  6 PM', 15),
          ],
        ),
        ScreenshotArtwork.lamp => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                type('FORM', 23, spacing: 4),
                type('OBJECT NO. 08', 9),
              ],
            ),
            const Expanded(
              child: ScreenshotIllustration(kind: IllustrationKind.lamp),
            ),
            type('A pool of light.', 31, serif: true),
            const SizedBox(height: 12),
            type('The reading lamp / Brushed steel', 12),
            rule,
            type(
              '\$89                   MADE FOR QUIET EVENINGS',
              9,
              spacing: .6,
            ),
          ],
        ),
      },
    ),
  );
}
