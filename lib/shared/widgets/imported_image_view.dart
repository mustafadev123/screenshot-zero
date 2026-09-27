import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/models/imported_image.dart';
import 'image_source/image_provider_native.dart'
    if (dart.library.js_interop) 'image_source/image_provider_web.dart';

class ImportedImageView extends StatelessWidget {
  const ImportedImageView({super.key, required this.image, this.radius = 4});
  final ImportedImage image;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Selected image: ${image.name}',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: AppColors.wash,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ratio = MediaQuery.devicePixelRatioOf(context);
            final width = (constraints.maxWidth * ratio)
                .clamp(64.0, 1440.0)
                .round();
            final height = (constraints.maxHeight * ratio)
                .clamp(64.0, 1440.0)
                .round();
            return Image(
              key: ValueKey(image.path),
              image: ResizeImage(
                selectedImageProvider(image.path),
                width: width,
                height: height,
                policy: ResizeImagePolicy.fit,
              ),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              frameBuilder: (_, child, frame, synchronous) =>
                  synchronous || frame != null
                  ? child
                  : const _ImagePlaceholder(label: 'Opening image'),
              errorBuilder: (_, _, _) =>
                  const _ImagePlaceholder(label: 'Image unavailable'),
            );
          },
        ),
      ),
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              color: AppColors.graphite,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
