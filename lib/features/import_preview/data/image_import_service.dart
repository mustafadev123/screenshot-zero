import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../domain/models/imported_image.dart';

const maxImportImages = 20;

class ImageImportResult {
  const ImageImportResult({this.images = const [], this.notice});

  final List<ImportedImage> images;
  final String? notice;
}

abstract class ImageImportService {
  Future<ImageImportResult> pickImages();
  Future<ImageImportResult> recoverLostImages();
}

class PickerImageImportService implements ImageImportService {
  PickerImageImportService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker() {
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
    }
  }

  final ImagePicker _picker;

  @override
  Future<ImageImportResult> pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        limit: maxImportImages,
        requestFullMetadata: false,
      );
      return _convert(files);
    } on PlatformException {
      return _failure;
    } catch (_) {
      return _failure;
    }
  }

  @override
  Future<ImageImportResult> recoverLostImages() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ImageImportResult();
    }
    try {
      final result = await _picker.retrieveLostData();
      if (result.isEmpty) return const ImageImportResult();
      if (result.exception != null) return _failure;
      return _convert(result.files ?? []);
    } catch (_) {
      return _failure;
    }
  }

  ImageImportResult _convert(List<XFile> files) => ImageImportResult(
    images: List.unmodifiable(
      files
          .take(maxImportImages)
          .map((file) => ImportedImage(path: file.path, name: file.name)),
    ),
    notice: files.length > maxImportImages
        ? 'You can add up to 20 images at a time. The first 20 are selected.'
        : null,
  );

  static const _failure = ImageImportResult(
    notice: 'Couldn’t open those images. Please try selecting them again.',
  );
}
