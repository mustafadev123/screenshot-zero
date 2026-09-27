import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/analysis/mlkit_screenshot_text_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  const image = ImportedImage(path: '/private/local.png', name: 'event.png');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'unsupported desktop returns fallback without creating native recognizer',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      final extractor = MlKitScreenshotTextExtractor();
      expect((await extractor.extract(image)).error, contains('unavailable'));
      await extractor.close();
      expect(calls, isEmpty);
    },
  );
  test(
    'native errors do not leak file paths and recognizer is released',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'vision#startTextRecognizer') {
              throw PlatformException(code: 'unreadable', message: image.path);
            }
            return null;
          });
      final extractor = MlKitScreenshotTextExtractor();
      final result = await extractor.extract(image);
      expect(result.error, isNot(contains(image.path)));
      expect(result.text, isEmpty);
      await extractor.close();
      expect(calls.map((c) => c.method), [
        'vision#startTextRecognizer',
        'vision#closeTextRecognizer',
      ]);
    },
  );
  test('empty native OCR is a normal result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'vision#startTextRecognizer'
              ? {'text': '', 'blocks': <Object>[]}
              : null;
        });
    final extractor = MlKitScreenshotTextExtractor();
    final result = await extractor.extract(image);
    expect(result.error, isNull);
    expect(result.text, isEmpty);
    expect(calls.single.arguments['imageData']['path'], image.path);
    await extractor.close();
  });
}
