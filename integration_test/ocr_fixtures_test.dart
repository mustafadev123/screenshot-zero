import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/analysis/mlkit_screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/analysis/screenshot_analyzer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('five actual images through native ML Kit', (tester) async {
    const encoded = String.fromEnvironment('OCR_FIXTURES');
    expect(
      encoded,
      isNotEmpty,
      reason: 'Run tool/prepare_native_ocr_test.ps1 and pass --dart-define-from-file=build/ocr-test-defines.json',
    );
    final fixtures = jsonDecode(encoded) as List;
    expect(fixtures, hasLength(5));
    final directory = await Directory.systemTemp.createTemp('ocr-fixtures-');
    final extractor = MlKitScreenshotTextExtractor();
    try {
      for (var i = 0; i < fixtures.length; i++) {
        final fixture = fixtures[i] as Map;
        final file = File('${directory.path}/$i.png');
        await file.writeAsBytes(base64Decode(fixture['bytes'] as String));
        final image = ImportedImage(path: file.path, name: '$i.png');
        final text = await extractor.extract(image);
        expect(text.error, isNull, reason: 'Image $i');
        expect(text.text, isNotEmpty);
        final result = const HeuristicScreenshotAnalyzer().analyze(
          image: image,
          text: text,
        );
        // Diagnostics are returned by the test runner, never logged by production OCR.
        IntegrationTestWidgetsFlutterBinding.instance.reportData ??= {};
        IntegrationTestWidgetsFlutterBinding.instance.reportData!['image_$i'] =
            {
              'raw': text.text,
              'category': result.intent.name,
              'fields': result.extractedFields,
              'signals': result.matchedSignals,
              'confidence': result.confidence,
            };
        expect(
          result.intent.name,
          fixture['expected'],
          reason: 'Image $i: ${text.text}',
        );
      }
    } finally {
      await extractor.close();
      await directory.delete(recursive: true);
    }
  });
}
