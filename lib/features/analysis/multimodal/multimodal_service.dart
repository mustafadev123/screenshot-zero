import 'dart:convert';

import '../../../domain/models/imported_image.dart';
import '../../../domain/models/screenshot_intent.dart';
import '../screenshot_analyzer.dart';

class MultimodalRequest {
  const MultimodalRequest({required this.image, required this.local});
  final ImportedImage image;
  final ScreenshotAnalysisResult local;
  String get ocrText => local.rawText;
}

/// Implement with a secure backend adapter, never a server API key in Flutter.
/// The backend must treat image/OCR content as data, not instructions, and infer
/// saving intent conservatively. An object alone is not evidence of an action.
abstract class MultimodalAnalysisService {
  bool get available;
  Future<MultimodalResult> analyze(MultimodalRequest request);
}

class UnavailableMultimodalService implements MultimodalAnalysisService {
  const UnavailableMultimodalService();
  @override
  bool get available => false;
  @override
  Future<MultimodalResult> analyze(MultimodalRequest request) =>
      Future.error(StateError('No multimodal backend configured'));
}

/// Strict response contract. Unknown keys, categories, types, fenced JSON,
/// oversized responses and unsafe URLs are rejected, not guessed or repaired.
class MultimodalResult {
  const MultimodalResult._(
    this.category,
    this.title,
    this.confidence,
    this.reason,
    this.fields,
    this.evidence,
  );
  final ScreenshotIntent category;
  final String title;
  final double confidence;
  final String reason;
  final Map<String, String> fields;
  final Set<String> evidence;

  static const fieldNames = {
    'date',
    'time',
    'venue',
    'address',
    'price',
    'variant',
    'size',
    'author',
    'publication',
    'url',
    'dueDate',
    'dueTime',
  };
  static const evidenceNames = {
    'shopping_controls',
    'event_details',
    'place_listing',
    'article_layout',
    'task_instructions',
  };

  factory MultimodalResult.fromJson(String source) {
    if (source.length > 12000) {
      throw const FormatException('Response too large');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value.keys.any(
          (key) => !{
            'category',
            'title',
            'confidence',
            'reason',
            'evidence',
            ...fieldNames,
          }.contains(key),
        )) {
      throw const FormatException('Invalid response shape');
    }
    String text(String key, int limit) {
      final v = value[key];
      if (v is! String ||
          v.trim().isEmpty ||
          v.length > limit ||
          RegExp(r'[\x00-\x1f]').hasMatch(v)) {
        throw FormatException('Invalid $key');
      }
      return v.trim();
    }

    final category = ScreenshotIntent.values
        .where((v) => v.name == value['category'])
        .firstOrNull;
    final confidence = value['confidence'];
    if (category == null ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const FormatException('Invalid category/confidence');
    }
    final fields = <String, String>{};
    for (final key in fieldNames) {
      if (value.containsKey(key)) fields[key] = text(key, 300);
    }
    if (fields['url'] case final String url) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !{'https', 'http'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid URL');
      }
    }
    final evidence = value['evidence'] ?? <String>[];
    if (evidence is! List ||
        evidence.length > evidenceNames.length ||
        evidence.any((v) => v is! String || !evidenceNames.contains(v))) {
      throw const FormatException('Invalid evidence');
    }
    return MultimodalResult._(
      category,
      text('title', 100),
      confidence.toDouble(),
      text('reason', 500),
      Map.unmodifiable(fields),
      Set.unmodifiable(evidence.cast<String>()),
    );
  }

  bool get hasActionEvidence =>
      category == ScreenshotIntent.reference ||
      evidence.contains(switch (category) {
        ScreenshotIntent.product => 'shopping_controls',
        ScreenshotIntent.event => 'event_details',
        ScreenshotIntent.place => 'place_listing',
        ScreenshotIntent.read => 'article_layout',
        ScreenshotIntent.task => 'task_instructions',
        ScreenshotIntent.reference => '',
      });
}
