import 'screenshot_text_extractor.dart';

class OcrDocument {
  OcrDocument(ExtractedTextResult result)
    : raw = result.text.trim(),
      regions = result.regions,
      lines = (result.lines.isEmpty ? result.text.split('\n') : result.lines)
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty && !isChrome(line))
          .toList();

  final String raw;
  final List<String> lines;
  final List<OcrTextRegion> regions;

  bool has(String expression) =>
      RegExp(expression, caseSensitive: false).hasMatch(raw);
  String? first(RegExp pattern, [String? source]) =>
      pattern.firstMatch(source ?? raw)?.group(0);
  bool get usable => lines.any((line) => RegExp(r'[A-Za-z]{3}').hasMatch(line));

  static final date = RegExp(
    r'\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?\s+(?:0?[1-9]|[12]\d|3[01])(?:st|nd|rd|th)?(?:,?\s+\d{4})?\b|\b\d{4}-\d{2}-\d{2}\b|\b(?:0?[1-9]|1[0-2])[/](?:0?[1-9]|[12]\d|3[01])(?:/\d{2,4})?\b',
    caseSensitive: false,
  );
  static final time = RegExp(
    r'\b(?:0?[1-9]|1[0-2])(?::[0-5]\d)?\s*[AP]M\b',
    caseSensitive: false,
  );
  static final price = RegExp(r'[$€£]\s?\d+(?:,\d{3})*(?:\.\d{2})?');
  static final address = RegExp(
    r'\b\d{1,5}[ \t]+(?:[A-Za-z0-9.-]+[ \t]+){1,7}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct)\b(?:\.?[,]?[ \t]+(?:[A-Za-z]+[ \t]+){0,3}[A-Za-z]+,[ \t]*[A-Z]{2}(?:[ \t]+\d{5})?)?',
    caseSensitive: false,
  );
  static final coursePattern = RegExp(
    r'\b[A-Z]{2,5}[ \t]*\d{3,4}\b',
    caseSensitive: false,
  );
  static final byline = RegExp(
    r'^By\s+([A-Za-zÀ-ž][A-Za-zÀ-ž .’\x27-]+)',
    caseSensitive: false,
  );
  static final venue = RegExp(
    r'\b(?:hall|center|centre|ballroom|stadium|arena|auditorium|theat(?:re|er)|gallery|convention center)\b',
    caseSensitive: false,
  );
  static final eventWords = RegExp(
    r'\b(?:symposium|concert|conference|festival|workshop|meetup|exhibition|performance|screening|seminar|webinar|show|event)\b',
    caseSensitive: false,
  );
  static final taskWords = RegExp(
    r'\b(?:assignment|homework|project|quiz|exam|essay|report)\b',
    caseSensitive: false,
  );

  String? get course {
    for (final match in coursePattern.allMatches(raw)) {
      final value = match.group(0)!;
      if (!RegExp(
        r'^(?:fall|spring|summer|winter|since|size|model|year|april|march|june|july|may)\b',
        caseSensitive: false,
      ).hasMatch(value)) {
        return value;
      }
    }
    return null;
  }

  double prominence(String candidate) {
    final heights = regions
        .where((region) => candidate.contains(region.text.trim()))
        .map((region) => region.height)
        .toList();
    if (heights.isEmpty || regions.isEmpty) return 0;
    final sorted = regions.map((r) => r.height).where((h) => h > 0).toList()
      ..sort();
    if (sorted.isEmpty) return 0;
    final largest = heights.reduce((a, b) => a > b ? a : b);
    return (largest / sorted[sorted.length ~/ 2] - 1).clamp(0.0, 2.0);
  }

  static bool isChrome(String line) {
    if (price.hasMatch(line)) return false;
    final plain = line
        .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9%]+$'), '')
        .trim();
    return RegExp(
          r'^(?:\d{1,2}:\d{2}|\d+(?:[.,]\d+)?%?|\d{2,3}0/0|[45]G|LTE|home|back|menu|overview|reviews|photos|about|save|share|call|cal l|directions|account|dashboard|calendar|to do|grades|discussions|assignments|instructions|submission details|world|technology|business|life|opinion|suggested|send to chat|done)$',
          caseSensitive: false,
        ).hasMatch(plain) ||
        (plain.toLowerCase().startsWith('home') && line.contains('>'));
  }

  static String shorten(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words.length > 12 ? '${words.take(12).join(' ')}…' : words.join(' ');
  }
}
