import '../../domain/models/imported_image.dart';

class ExtractedTextResult {
  const ExtractedTextResult({
    required this.text,
    this.lines = const [],
    this.error,
    this.regions = const [],
  });

  final String text;
  final List<String> lines;
  final String? error;
  final List<OcrTextRegion> regions;

  bool get isUsable => text.trim().isNotEmpty && error == null;
}

class OcrTextRegion {
  const OcrTextRegion({
    required this.text,
    required this.height,
    required this.block,
    this.top,
    this.left,
    this.width,
  });
  final String text;
  final double height;
  final int block;
  // Optional layout metadata used only by structured title extraction.
  final double? top;
  final double? left;
  final double? width;
}

abstract class ScreenshotTextExtractor {
  Future<ExtractedTextResult> extract(ImportedImage image);
}
