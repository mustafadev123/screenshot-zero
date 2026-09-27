import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/features/actions/action_date_parser.dart';

void main() {
  test('explicit example dates, midnight and noon', () {
    expect(
      parseActionDate('Sep 30, 2026', '11:59 PM'),
      DateTime(2026, 9, 30, 23, 59),
    );
    expect(
      parseActionDate('October 18, 2026', '7:30 PM'),
      DateTime(2026, 10, 18, 19, 30),
    );
    expect(parseActionDate('Feb 29, 2028', '12 AM'), DateTime(2028, 2, 29));
    expect(parseActionDate('Sep 30, 2026', '12 PM'), DateTime(2026, 9, 30, 12));
  });
  test('rejects missing years, numeric ambiguity, impossible dates/times and zones', () {
    for (final pair in [
      ('Sep 30', '11:59 PM'),
      ('09/10/2026', '7 PM'),
      ('Feb 29, 2026', '7 PM'),
      ('Sep 31, 2026', '7 PM'),
      ('Sep 30, 2026', '13 PM'),
      ('Sep 30, 2026', '0 AM'),
      ('Sep 30, 2026', '7:60 PM'),
      ('Sep 30, 2026', '7 PM EST'),
      ('Sep 30, 2026', ''),
      ('', '7 PM'),
    ]) {
      expect(
        parseActionDate(pair.$1, pair.$2),
        isNull,
        reason: pair.toString(),
      );
    }
    expect(parseActionDate(null, null), isNull);
  });
}
