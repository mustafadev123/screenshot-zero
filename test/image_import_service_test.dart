import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';

class _Picker extends ImagePicker {
  List<XFile> files = [];
  PlatformException? error;
  LostDataResponse lost = LostDataResponse.empty();
  int? requestedLimit;
  bool? fullMetadata;
  double? width;
  int? quality;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    requestedLimit = limit;
    fullMetadata = requestFullMetadata;
    width = maxWidth;
    quality = imageQuality;
    if (error != null) throw error!;
    return files;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => lost;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'requests 20 without modifying originals, caps excess selection',
    () async {
      final picker = _Picker()
        ..files = List.generate(23, (i) => XFile('/selected/$i.png'));
      final result = await PickerImageImportService(picker: picker)
          .pickImages();
      expect(picker.requestedLimit, 20);
      expect(picker.fullMetadata, isFalse);
      expect(picker.width, isNull);
      expect(picker.quality, isNull);
      expect(result.images.length, 20);
      expect(result.images.last.path, '/selected/19.png');
      expect(result.notice, contains('first 20'));
    },
  );

  test('cancel is silent and plugin errors are translated', () async {
    final picker = _Picker();
    final service = PickerImageImportService(picker: picker);
    expect((await service.pickImages()).images, isEmpty);
    expect((await service.pickImages()).notice, isNull);
    picker.error = PlatformException(
      code: 'secret-internal-error',
      message: 'technical stack',
    );
    final result = await service.pickImages();
    expect(result.images, isEmpty);
    expect(result.notice, contains('try selecting'));
    expect(result.notice, isNot(contains('technical')));
  });

  test(
    'Android lost selections use the same limit and file representation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final picker = _Picker()
        ..lost = LostDataResponse(files: [XFile('/recovered.png')]);
      final result = await PickerImageImportService(picker: picker)
          .recoverLostImages();
      expect(result.images.single.path, '/recovered.png');
      picker.lost = LostDataResponse(
        exception: PlatformException(code: 'lost'),
      );
      expect(
        (await PickerImageImportService(
          picker: picker,
        ).recoverLostImages()).notice,
        isNotNull,
      );
    },
  );
}
