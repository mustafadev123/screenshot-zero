/// Parses only explicit English dates with a year and a 12-hour clock.
/// The confirmation UI explicitly presents the device-local timezone.
DateTime? parseActionDate(String? date, String? time) {
  if (date == null || time == null) return null;
  final d = RegExp(r'^(\w+)\.?\s+(\d{1,2}),?\s+(\d{4})$')
      .firstMatch(date.trim());
  final t = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(time.trim());
  if (d == null || t == null) return null;
  const months = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  final month = months[d.group(1)!.toLowerCase()];
  final day = int.parse(d.group(2)!);
  final year = int.parse(d.group(3)!);
  final hour = int.parse(t.group(1)!);
  final minute = int.parse(t.group(2) ?? '0');
  if (month == null || hour < 1 || hour > 12 || minute > 59 || year < 1900)
    return null;
  final h = hour % 12 + (t.group(3)!.toUpperCase() == 'PM' ? 12 : 0);
  final value = DateTime(year, month, day, h, minute);
  return value.year == year &&
          value.month == month &&
          value.day == day &&
          value.hour == h &&
          value.minute == minute
      ? value
      : null;
}
