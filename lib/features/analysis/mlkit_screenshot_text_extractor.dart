import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/imported_image.dart';
import 'screenshot_text_extractor.dart';

class MlKitScreenshotTextExtractor implements ScreenshotTextExtractor {
  MlKitScreenshotTextExtractor({this._recognizer});

  TextRecognizer? _recognizer;

  @override
  Future<ExtractedTextResult> extract(ImportedImage image) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return const ExtractedTextResult(
        text: '',
        error: 'OCR is unavailable on this platform',
      );
    }
    try {
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      final lines = [
        for (final block in recognized.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty) line.text.trim(),
      ];
      return ExtractedTextResult(
        text: lines.join('\n'),
        lines: lines,
        regions: [
          for (var i = 0; i < recognized.blocks.length; i++)
            for (final line in recognized.blocks[i].lines)
              OcrTextRegion(
                text: line.text,
                height: line.boundingBox.height,
                block: i,
                top: line.boundingBox.top,
                left: line.boundingBox.left,
                width: line.boundingBox.width,
              ),
        ],
      );
    } catch (_) {
      return const ExtractedTextResult(
        text: '',
        error: 'Could not read text from this image',
      );
    }
  }

  Future<void> close() async => _recognizer?.close();
}
