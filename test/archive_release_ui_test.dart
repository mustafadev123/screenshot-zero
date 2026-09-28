import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/features/archive/archive_detail.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';

import 'archive_persistence_test.dart' show sample;

void main() {
  testWidgets(
    'release-equivalent archive hides diagnostics and session labels',
    (tester) async {
      final item = sample(
        '/missing.png',
        ScreenshotIntent.product,
        'Saved to wishlist',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveDetail(item: item, showDiagnostics: false),
          ),
        ),
      );
      expect(find.textContaining('PRIVATE OCR'), findsNothing);
      expect(find.textContaining('Confidence:'), findsNothing);
      expect(find.textContaining('Signals:'), findsNothing);
      expect(
        find.textContaining('screenshot kept in this session'),
        findsNothing,
      );
      expect(find.text('Saved to wishlist'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ArchiveDetail(item: item)),
        ),
      );
      expect(find.textContaining('Raw OCR: PRIVATE OCR'), findsOneWidget);
    },
  );
}
