import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/screenshot_analyzer.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';

void main() {
  const analyzer = HeuristicScreenshotAnalyzer();
  const anonymous = ImportedImage(path: '/tmp/0001.png', name: '0001.png');
  final fixtures = jsonDecode(
    File('test/fixtures/ocr_windows.json')
        .readAsStringSync()
        .replaceFirst('\ufeff', ''),
  ) as List;
  // Expected labels are test assertions, never inputs to the classifier.
  final expected = <String, (ScreenshotIntent, String, Map<String, String>)>{
    'event_symposium.png.png': (
      ScreenshotIntent.event,
      'Campus Research Symposium',
      {
        'date': 'October 18, 2026',
        'time': '7:30 PM',
        'venue': 'Student Center Ballroom',
      },
    ),
    'place_restaurant.png.png': (
      ScreenshotIntent.place,
      'Sunday Table',
      {
        'address': '48 Peachtree Street, Atlanta, GA',
        'hours': 'open until 9:00 PM',
      },
    ),
    'product_runner.png.png': (
      ScreenshotIntent.product,
      'Everyday Runner',
      {'price': '\$89', 'size': '9', 'color': 'Cloud / Chalk'},
    ),
    'read_article.png.png': (
      ScreenshotIntent.read,
      'How Small Models Are Changing AI',
      {'author': 'Maya Rahman', 'source': 'The Daily Ledger'},
    ),
    'task_assignment.png.png': (
      ScreenshotIntent.task,
      'Assignment 3',
      {
        'course': 'csc 6851',
        'due_date': 'sep 30, 2026',
        'due_time': '11:59 PM',
      },
    ),
  };
  for (final fixture in fixtures) {
    test('local Windows OCR regression: ${fixture['file']}', () {
      final result = analyzer.analyze(
        image: anonymous,
        text: ExtractedTextResult(
          text: fixture['text'] as String,
          lines: List<String>.from(fixture['lines'] as List),
        ),
      );
      final (intent, title, fields) = expected[fixture['file']]!;
      expect(result.intent, intent);
      expect(result.title, title);
      for (final field in fields.entries) {
        expect(
          result.extractedFields[field.key],
          field.value,
          reason: field.key,
        );
      }
      final misleading = analyzer.analyze(
        image: const ImportedImage(
          path: '/event/product.jpg',
          name: 'Homework concert shoe article.png',
        ),
        text: ExtractedTextResult(text: fixture['text'] as String),
      );
      expect(misleading.intent, result.intent);
      expect(misleading.extractedFields, result.extractedFields);
      final item = result.toItem(id: 1, image: anonymous).complete();
      expect(item.importedImage, same(anonymous));
      expect(item.extractedFields, result.extractedFields);
      expect(item.rawOcrText, fixture['text']);
    });
  }
  ScreenshotAnalysisResult analyze(String text) => analyzer.analyze(
    image: anonymous,
    text: ExtractedTextResult(text: text),
  );
  test('generic rules survive entirely different titles', () {
    expect(
      analyze('Alpine Hiker\n\$74\nSize 11\nAdd to cart').title,
      'Alpine Hiker',
    );
    expect(
      analyze('Chemistry Workshop\nMay 12, 2027\n6 PM\nBuy tickets').intent,
      ScreenshotIntent.event,
    );
    expect(
      analyze('Homework 7\nBIO 210\nDue May 14, 2027').intent,
      ScreenshotIntent.task,
    );
  });
  test('clock, lone signals and keyword substrings are insufficient', () {
    for (final text in [
      '10:24\n87%',
      'October 18 7:30 PM',
      'A showcase of overdue sizing',
      '\$42',
      'Restaurant',
    ]) {
      expect(analyze(text).intent, ScreenshotIntent.reference, reason: text);
    }
  });
  test('two strongly supported categories safely conflict', () {
    final result = analyze(
      'Assignment 4\nDue October 18, 2026 7:30 PM\nSubmit PDF\nCSC 300\nConcert\nTickets available',
    );
    expect(result.intent, ScreenshotIntent.reference);
    expect(result.matchedSignals, contains('conflicting_categories'));
  });
  test('no arbitrary venue or source and no coupon price', () {
    expect(
      analyze('Jazz Concert\nMay 12, 2027\n7 PM\nBuy tickets')
          .extractedFields['venue'],
      isNull,
    );
    expect(
      analyze(
        'A new chapter for libraries\nBy Alex Reed\nArticle\nLibraries are changing how communities learn and gather. Read more about the story and its impact on cities.',
      ).extractedFields['source'],
      isNull,
    );
    expect(
      analyze('SAVE BIG\n\$20 OFF \$30+\nORDER NOW\nCODE SHOP20')
          .extractedFields['price'],
      isNull,
    );
  });
}
