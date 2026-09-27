import 'package:flutter/material.dart';

import '../../domain/models/screenshot_item.dart';
import 'imported_image_view.dart';
import 'screenshot_art.dart';

class ScreenshotImage extends StatelessWidget {
  const ScreenshotImage({super.key, required this.item, this.radius = 4});
  final ScreenshotItem item;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = item.importedImage;
    return image == null
        ? ScreenshotArt(item: item, radius: radius)
        : ImportedImageView(image: image, radius: radius);
  }
}
