import '../../domain/models/screenshot_intent.dart';
import '../../domain/models/title_quality.dart';
import 'ocr_document.dart';
import 'screenshot_text_extractor.dart';

class StructuredExtraction {
  const StructuredExtraction(
    this.title,
    this.subtitle,
    this.metadata,
    this.fields,
  );
  final String title;
  final String subtitle;
  final List<String> metadata;
  final Map<String, String> fields;

  factory StructuredExtraction.from(OcrDocument doc, ScreenshotIntent intent) {
    final fields = <String, String>{};
    final metadata = <String>[];
    final title = _title(doc, intent);
    if (title != null) {
      fields[intent == ScreenshotIntent.read ? 'headline' : 'title'] = title;
    }
    void add(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) fields[key] = value.trim();
    }

    String subtitle = 'Recognized text';
    switch (intent) {
      case ScreenshotIntent.task:
        final due = RegExp(
          r'\b(?:due|deadline)\b[^\n]*(?:\n[^\n]+)?',
          caseSensitive: false,
        ).firstMatch(doc.raw)?.group(0);
        if (due != null) {
          add('due_date', doc.first(OcrDocument.date, due));
          add('due_time', doc.first(OcrDocument.time, due));
        }
        add('course', doc.course);
        subtitle = [
          if (fields['due_date'] != null) 'Due ${fields['due_date']}',
          ?fields['due_time'],
        ].join(' · ');
        if (fields['course'] != null) metadata.add(fields['course']!);
      case ScreenshotIntent.event:
        add('date', doc.first(OcrDocument.date));
        add('time', doc.first(OcrDocument.time));
        final explicit = RegExp(
          r'(?:venue|location)\s*:\s*([^\n]+)',
          caseSensitive: false,
        ).firstMatch(doc.raw)?.group(1);
        final venueLine = doc.lines
            .where(
              (line) =>
                  OcrDocument.venue.hasMatch(line) &&
                  line.length < 100 &&
                  !line.endsWith('.'),
            )
            .firstOrNull;
        add(
          'venue',
          explicit ?? (venueLine == null ? null : _stripTemporal(venueLine)),
        );
        subtitle = [?fields['date'], ?fields['time']].join(' · ');
        if (fields['venue'] != null) metadata.add(fields['venue']!);
      case ScreenshotIntent.product:
        final prices = OcrDocument.price.allMatches(doc.raw);
        for (final price in prices) {
          final after = doc.raw.substring(price.end);
          if (!RegExp(
            r'^\s*(?:off|discount|coupon|\+)',
            caseSensitive: false,
          ).hasMatch(after)) {
            add('price', price.group(0));
            break;
          }
        }
        add(
          'size',
          RegExp(
            r'\bsize\s*:?\s*([\w./-]+)',
            caseSensitive: false,
          ).firstMatch(doc.raw)?.group(1),
        );
        final color = RegExp(
          r'\bcolou?r\s*:\s*([^\n]+)',
          caseSensitive: false,
        ).firstMatch(doc.raw)?.group(1);
        add(
          'color',
          color
              ?.split(
                RegExp(
                  r'\b(?:size|in stock|out of stock|quantity)\b',
                  caseSensitive: false,
                ),
              )
              .first
              .trim(),
        );
        add(
          'availability',
          RegExp(
            r'\b(?:in stock|out of stock|sold out|available now)\b',
            caseSensitive: false,
          ).firstMatch(doc.raw)?.group(0),
        );
        final specs = RegExp(
          r'\b\d+\s*(?:GB|TB)\s*(?:RAM|SSD|storage|memory)\b',
          caseSensitive: false,
        ).allMatches(doc.raw).map((m) => m.group(0)!).toList();
        if (specs.isNotEmpty) add('specifications', specs.join(' · '));
        subtitle = fields['price'] ?? 'Product details';
        metadata.addAll([
          ?fields['color'],
          if (fields['size'] != null) 'Size ${fields['size']}',
          ?fields['availability'],
          ?fields['specifications'],
        ]);
      case ScreenshotIntent.place:
        if (title != null && !OcrDocument.address.hasMatch(title)) {
          add('place', title);
        }
        add('address', doc.first(OcrDocument.address));
        add(
          'hours',
          RegExp(
            r'\b(?:open until|opens at|closes at)\s+\d{1,2}(?::\d{2})?\s*[AP]M\b|\b(?:open 24 hours|temporarily closed|permanently closed)\b',
            caseSensitive: false,
          ).firstMatch(doc.raw)?.group(0),
        );
        subtitle = fields['address'] ?? 'Place details';
        if (fields['hours'] != null) metadata.add(fields['hours']!);
      case ScreenshotIntent.read:
        final bylineIndex = doc.lines.indexWhere(
          (line) => OcrDocument.byline.hasMatch(line),
        );
        if (bylineIndex >= 0) {
          add(
            'author',
            OcrDocument.byline.firstMatch(doc.lines[bylineIndex])?.group(1),
          );
          if (bylineIndex + 1 < doc.lines.length) {
            final candidate = doc.lines[bylineIndex + 1];
            if (doc.lines.take(bylineIndex).contains(candidate) &&
                _titleLike(candidate)) {
              add('source', candidate);
            }
          }
        }
        add(
          'source',
          RegExp(
                r'^(?:source|publication)\s*:\s*(.+)$',
                multiLine: true,
                caseSensitive: false,
              ).firstMatch(doc.raw)?.group(1) ??
              fields['source'],
        );
        add(
          'url',
          RegExp(
            r'https?://[^\s]+',
            caseSensitive: false,
          ).firstMatch(doc.raw)?.group(0),
        );
        subtitle = fields['source'] ?? 'Saved for reading';
        if (fields['author'] != null) metadata.add('By ${fields['author']}');
      case ScreenshotIntent.reference:
        subtitle = TitleQuality.referenceCopy;
    }
    return StructuredExtraction(
      intent == ScreenshotIntent.reference
          ? TitleQuality.reference(title ?? '', text: doc.raw)
          : title ?? 'Saved screenshot',
      subtitle.isEmpty ? 'Recognized text' : subtitle,
      List.unmodifiable(metadata),
      Map.unmodifiable(fields),
    );
  }

  static String? _title(OcrDocument doc, ScreenshotIntent intent) {
    final candidates = doc.lines.where(_titleLike).toList();
    if (intent == ScreenshotIntent.task) {
      for (final line in doc.lines) {
        final withoutCourse = line
            .replaceFirst(OcrDocument.coursePattern, '')
            .trim();
        if (RegExp(
          r'^(?:assignment|homework|project|quiz|exam|essay|report)\s+\S+',
          caseSensitive: false,
        ).hasMatch(withoutCourse)) {
          return OcrDocument.shorten(
            withoutCourse
                .split(
                  RegExp(r'\b(?:due|deadline|submit)\b', caseSensitive: false),
                )
                .first
                .trim(),
          );
        }
      }
    }
    if (intent == ScreenshotIntent.product) {
      final priceIndex = doc.lines.indexWhere(OcrDocument.price.hasMatch);
      if (priceIndex >= 0) {
        final beforePrice = doc.lines[priceIndex]
            .split(OcrDocument.price)
            .first
            .trim();
        if (_titleLike(beforePrice)) return OcrDocument.shorten(beforePrice);
        for (var i = priceIndex - 1; i >= 0; i--) {
          if (_titleLike(doc.lines[i])) {
            return OcrDocument.shorten(doc.lines[i]);
          }
        }
      }
    }
    if (intent == ScreenshotIntent.read) {
      final byline = doc.lines.indexWhere(
        (line) => OcrDocument.byline.hasMatch(line),
      );
      if (byline > 0) {
        final headline = <String>[];
        for (var i = byline - 1; i >= 0 && headline.length < 2; i--) {
          final line = doc.lines[i];
          if (!_titleLike(line) || doc.lines.skip(byline + 1).contains(line)) {
            break;
          }
          headline.insert(0, line);
        }
        if (headline.isNotEmpty) {
          return OcrDocument.shorten(_headlineOrder(doc, headline).join(' '));
        }
      }
    }
    if (intent == ScreenshotIntent.event) {
      for (final line in doc.lines) {
        if (OcrDocument.eventWords.hasMatch(line)) {
          final index = doc.lines.indexOf(line);
          if (line.split(' ').length == 1 &&
              index > 0 &&
              _titleLike(doc.lines[index - 1])) {
            return OcrDocument.shorten('${doc.lines[index - 1]} $line');
          }
          return OcrDocument.shorten(_stripTemporal(line, before: true));
        }
      }
    }
    if (intent == ScreenshotIntent.place) {
      final addressIndex = doc.lines.indexWhere(OcrDocument.address.hasMatch);
      if (addressIndex >= 0) {
        final prefix = doc.lines[addressIndex]
            .split(OcrDocument.address)
            .first
            .trim();
        if (_titleLike(prefix)) return OcrDocument.shorten(prefix);
      }
      final businessNames = candidates
          .where((line) => !_streetLabel(line))
          .toList();
      if (businessNames.isNotEmpty) {
        // Prefer the business header above the address, not labels in the map.
        final addressTop = addressIndex < 0
            ? null
            : _region(doc, doc.lines[addressIndex])?.top;
        final headerNames = businessNames.where((line) {
          final top = _region(doc, line)?.top;
          return top != null && addressTop != null
              ? top < addressTop
              : addressIndex >= 0 && doc.lines.indexOf(line) < addressIndex;
        }).toList();
        final names = headerNames.isEmpty ? businessNames : headerNames;
        names.sort((a, b) {
          // Position is a tie-breaker within the header; oversized map labels
          // have already been excluded from the business-name candidates.
          final prominence = doc.prominence(b).compareTo(doc.prominence(a));
          if (prominence != 0) return prominence;
          final aTop = _region(doc, a)?.top;
          final bTop = _region(doc, b)?.top;
          if (aTop != null && bTop != null && aTop != bTop) {
            return aTop.compareTo(bTop);
          }
          return doc.lines.indexOf(a).compareTo(doc.lines.indexOf(b));
        });
        return OcrDocument.shorten(names.first);
      }
    }
    if (candidates.isEmpty) return null;
    final ranked = [...candidates]
      ..sort((a, b) {
        final order = doc.prominence(b).compareTo(doc.prominence(a));
        return order == 0
            ? candidates.indexOf(a).compareTo(candidates.indexOf(b))
            : order;
      });
    return OcrDocument.shorten(ranked.first);
  }

  static String _stripTemporal(String text, {bool before = false}) {
    if (before) return text.split(OcrDocument.date).first.trim();
    final time = OcrDocument.time.firstMatch(text);
    return time == null ? text : text.substring(time.end).trim();
  }

  static OcrTextRegion? _region(OcrDocument doc, String line) {
    final matches = doc.regions
        .where(
          (region) =>
              region.text.replaceAll(RegExp(r'\s+'), ' ').trim() == line,
        )
        .toList();
    // Repeated map/business labels are ambiguous: keep document order.
    return matches.length == 1 ? matches.single : null;
  }

  static bool _streetLabel(String line) => RegExp(
    r'\b(?:street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|court|ct|way|highway|hwy)\.?\s*(?:(?:N|S|E|W|NE|NW|SE|SW)\b)?\s*$',
    caseSensitive: false,
  ).hasMatch(line);

  static List<String> _headlineOrder(OcrDocument doc, List<String> lines) {
    if (lines.length != 2) return lines;
    final first = _region(doc, lines[0]);
    final second = _region(doc, lines[1]);
    if (first == null ||
        second == null ||
        first.top == null ||
        second.top == null ||
        first.left == null ||
        second.left == null ||
        first.width == null ||
        second.width == null) {
      return lines;
    }
    final overlap =
        (first.left! + first.width! < second.left! + second.width!
            ? first.left! + first.width!
            : second.left! + second.width!) -
        (first.left! > second.left! ? first.left! : second.left!);
    final shorterWidth = first.width! < second.width!
        ? first.width!
        : second.width!;
    final upper = first.top! < second.top! ? first : second;
    final lower = first.top! < second.top! ? second : first;
    final gap = lower.top! - (upper.top! + upper.height);
    // Only adjacent lines in the same column may be reconstructed. Do not
    // reorder columns, same-row fragments, or lines without known geometry.
    if (shorterWidth <= 0 ||
        overlap < shorterWidth * .5 ||
        gap < 0 ||
        gap >
            (first.height > second.height ? first.height : second.height) *
                1.5) {
      return lines;
    }
    return first.top! > second.top! ? lines.reversed.toList() : lines;
  }

  static bool _titleLike(String text) =>
      text.length >= 4 &&
      text.length <= 100 &&
      RegExp(r'[A-Za-z]{3}').hasMatch(text) &&
      !OcrDocument.isChrome(text) &&
      !text.contains('>') &&
      !text.endsWith('.') &&
      !text.endsWith(',') &&
      !OcrDocument.date.hasMatch(text) &&
      !OcrDocument.price.hasMatch(text) &&
      !OcrDocument.byline.hasMatch(text) &&
      !OcrDocument.address.hasMatch(text) &&
      !RegExp(
        r'^(?:\w{2,5}\s*\d{3,4}|assignment|restaurant\s*[•·]?\s*\$*|fall\s+\d{4}|points:.*|module:.*|(?:get|buy) tickets.*|add to cart|submit.*|size\b.*|colou?r\b.*|open until.*|.*\breviews\)?)$',
        caseSensitive: false,
      ).hasMatch(text);
}
