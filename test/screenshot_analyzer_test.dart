import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/screenshot_analyzer.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';

void main() {
  const analyzer = HeuristicScreenshotAnalyzer();
  const image = ImportedImage(
    path: '/tmp/screenshot.png',
    name: 'screenshot.png',
  );

  ScreenshotAnalysisResult analyze(String text, {List<String>? lines}) =>
      analyzer.analyze(
        image: image,
        text: ExtractedTextResult(text: text, lines: lines ?? text.split('\n')),
      );

  test('classifies task signals and extracts due details', () {
    final result = analyze('CSC 6851 Assignment 3 Due Sep 30 11:59 PM');
    expect(result.intent, ScreenshotIntent.task);
    expect(result.extractedFields['due_date'], 'Sep 30');
    expect(result.extractedFields['due_time'], '11:59 PM');
    expect(result.extractedFields['course'], 'CSC 6851');
  });

  test('classifies product signals and extracts price', () {
    final result = analyze(r'Everyday Runner $120 Size 9 In Stock');
    expect(result.intent, ScreenshotIntent.product);
    expect(result.extractedFields['price'], '\$120');
    expect(result.title, 'Everyday Runner');
  });

  test('classifies promotional commerce text as product', () {
    final result = analyze(
      r'GRUBHUB+ PRIME $20 OFF $30+ CODE DEALS20 ORDER NOW',
    );
    expect(result.intent, ScreenshotIntent.product);
    expect(result.confidence, greaterThanOrEqualTo(.42));
    expect(result.matchedSignals, contains('contains_order_now'));
    expect(result.matchedSignals, contains('contains_code'));
  });

  test('classifies place signals and extracts address', () {
    final result = analyze('Sunday Table 48 Peachtree Street Open until 9 PM');
    expect(result.intent, ScreenshotIntent.place);
    expect(result.extractedFields['address'], '48 Peachtree Street');
  });

  test('classifies event signals and extracts date and time', () {
    final result = analyze(
      'Research Symposium October 18 7:30 PM Student Center',
    );
    expect(result.intent, ScreenshotIntent.event);
    expect(result.extractedFields['date'], 'October 18');
    expect(result.extractedFields['time'], '7:30 PM');
  });

  test('classifies article-style text as read', () {
    final lines = [
      'The future of public libraries',
      'By Morgan Lee',
      'Article',
      'Libraries are changing how communities learn and gather.',
      'Read more about the story and its impact on cities.',
    ];
    final result = analyze(lines.join('\n'), lines: lines);
    expect(result.intent, ScreenshotIntent.read);
    expect(
      result.extractedFields['headline'],
      'The future of public libraries',
    );
  });

  test('uses reference for ambiguous and empty OCR', () {
    expect(analyze('Remember this').intent, ScreenshotIntent.reference);
    final empty = analyze('');
    expect(empty.intent, ScreenshotIntent.reference);
    expect(empty.title, 'Unsorted screenshot');
    expect(empty.metadata, isEmpty);
  });

  test('keeps a readable reference title when classification is unclear', () {
    final result = analyze(
      'Initial Evaluation Plan\nThe prototype will use a compact model...',
    );
    expect(result.intent, ScreenshotIntent.reference);
    expect(result.title, 'Initial Evaluation Plan');
    expect(result.title, isNot('Unsorted screenshot'));
  });

  test('distinguishes OCR errors from empty OCR', () {
    final result = analyzer.analyze(
      image: image,
      text: const ExtractedTextResult(
        text: '',
        error: 'Image file is not readable',
      ),
    );
    expect(result.intent, ScreenshotIntent.reference);
    expect(result.title, 'Unsorted screenshot');
    expect(result.matchedSignals, contains('ocr_error'));
    expect(result.ocrError, 'Image file is not readable');
  });

  test('does not fabricate absent fields', () {
    final result = analyze('Buy this thing');
    expect(result.intent, ScreenshotIntent.reference);
    expect(result.extractedFields['price'], isNull);
    expect(result.extractedFields['address'], isNull);
    expect(result.extractedFields['date'], isNull);
  });
}
