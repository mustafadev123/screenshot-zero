import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/screenshot_analyzer.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';

const analyzer = HeuristicScreenshotAnalyzer();
const image = ImportedImage(path: '/tmp/anonymous.png', name: 'anonymous.png');

OcrTextRegion region(
  String text,
  double top,
  double height, {
  double left = 24,
  double width = 300,
  int block = 0,
}) => OcrTextRegion(
  text: text,
  top: top,
  left: left,
  width: width,
  height: height,
  block: block,
);

ScreenshotAnalysisResult analyze(
  List<String> lines,
  List<OcrTextRegion> regions,
) => analyzer.analyze(
  image: image,
  text: ExtractedTextResult(
    text: lines.join('\n'),
    lines: lines,
    regions: regions,
  ),
);

void main() {
  test('place business header beats a more prominent map street label', () {
    final lines = [
      'Sunday Table',
      'Restaurant',
      '48 Peachtree Street, Atlanta, GA',
      'Open until 9 PM',
      'Andrew Young St NE',
    ];
    final result = analyze(lines, [
      region(lines[0], 100, 32),
      region(lines[1], 150, 18),
      region(lines[2], 230, 18),
      region(lines[3], 260, 18),
      region(lines[4], 700, 60),
    ]);
    expect(result.intent, ScreenshotIntent.place);
    expect(result.title, 'Sunday Table');
    expect(result.extractedFields['place'], 'Sunday Table');
    expect(
      result.extractedFields['address'],
      '48 Peachtree Street, Atlanta, GA',
    );
  });

  test('place uses geometry for header even when map block arrives first', () {
    final lines = [
      'Riverside Station',
      'West Main Rd NW',
      'Cedar Kitchen',
      'Restaurant',
      '12 Maple Avenue, Austin, TX',
      'Open until 8 PM',
    ];
    final result = analyze(lines, [
      region(lines[0], 650, 64),
      region(lines[1], 700, 48),
      region(lines[2], 90, 30),
      region(lines[3], 140, 16),
      region(lines[4], 200, 16),
      region(lines[5], 230, 16),
    ]);
    expect(result.title, 'Cedar Kitchen');
    expect(result.extractedFields['address'], '12 Maple Avenue, Austin, TX');
  });

  test(
    'place rejects street suffixes without geometry and retains business words',
    () {
      final result = analyze([
        'West Main St NE',
        'Main Street Kitchen',
        'Restaurant',
        '12 Maple Avenue, Austin, TX',
        'Open until 8 PM',
      ], []);
      expect(result.title, 'Main Street Kitchen');
    },
  );

  for (final headline in [
    ('How Small Models Are', 'Changing AI'),
    ('Why Urban Gardens', 'Matter for Tomorrow'),
  ]) {
    test(
      'read joins adjacent headline lines top-to-bottom: ${headline.$1}',
      () {
        final lines = [
          'The Daily Ledger',
          headline.$2,
          headline.$1,
          'By Maya Rahman',
          'The Daily Ledger',
          'Apr 22, 2025 · 5 min read',
          'This article explores new ideas and practical possibilities for people in their everyday lives.',
        ];
        final regions = [
          region(lines[0], 50, 20),
          // ML Kit returns the lower headline block before the upper one.
          region(headline.$2, 250, 48, block: 1),
          region(headline.$1, 200, 36, block: 2),
          region(lines[3], 330, 18, block: 3),
        ];
        final result = analyze(lines, regions);
        expect(result.intent, ScreenshotIntent.read);
        expect(result.title, '${headline.$1} ${headline.$2}');
        expect(result.extractedFields['headline'], result.title);
        expect(result.extractedFields['author'], 'Maya Rahman');
        expect(result.extractedFields['source'], 'The Daily Ledger');
        final withoutLayout = analyze(lines, []);
        expect(result.intent, withoutLayout.intent);
        expect(result.confidence, withoutLayout.confidence);
        expect(result.matchedSignals, withoutLayout.matchedSignals);
        expect(result.rawText, withoutLayout.rawText);
      },
    );
  }

  test('read preserves existing natural order despite unequal font sizes', () {
    final lines = [
      'Zebra Habitats Are',
      'A Global Priority',
      'By Alex Reed',
      '5 min read',
      'An article with enough body text to describe the everyday challenges of protecting the natural world and its varied habitats.',
    ];
    expect(
      analyze(lines, [
        region(lines[0], 200, 36),
        region(lines[1], 250, 48),
      ]).title,
      'Zebra Habitats Are A Global Priority',
    );
    expect(analyze(lines, []).title, 'Zebra Habitats Are A Global Priority');
  });

  test(
    'read never sorts separate columns or distant lines by vertical position',
    () {
      final lines = [
        'First Headline Fragment',
        'Second Headline Fragment',
        'By Alex Reed',
        '5 min read',
        'An article with enough body text to describe the everyday challenges of protecting the natural world and its varied habitats.',
      ];
      for (final regions in [
        [region(lines[0], 250, 36, left: 400), region(lines[1], 200, 36)],
        [region(lines[0], 900, 36), region(lines[1], 200, 36)],
        [region(lines[0], 200, 36), region(lines[1], 200, 36)],
      ]) {
        expect(
          analyze(lines, regions).title,
          'First Headline Fragment Second Headline Fragment',
        );
      }
    },
  );
}
