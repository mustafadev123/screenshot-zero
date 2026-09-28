import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (var orientation = 1; orientation <= 8; orientation++) {
    test(
      'native codec displays EXIF orientation $orientation upright',
      () async {
        final bytes = await File(
          'test/fixtures/orientation/orientation-$orientation.jpg',
        ).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect((image.width, image.height), (60, 100));
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (10 * image.width + 10) * 4;
        expect(pixels.getUint8(offset), greaterThan(220));
        expect(pixels.getUint8(offset + 1), lessThan(30));
        expect(pixels.getUint8(offset + 2), lessThan(30));
        image.dispose();
        codec.dispose();
      },
    );
  }
}
