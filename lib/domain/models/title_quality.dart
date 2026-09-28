/// Evidence-based text cleanup only; this never infers an object from a brand.
abstract final class TitleQuality {
  static const referenceCopy = 'No clear action detected.';
  static const referenceFallback = 'Saved reference';

  static bool weak(String title) {
    final text = title.trim();
    if (text.length < 3 || text.length > 90) return true;
    if (RegExp(
      r'^(?:\d+[\d,.]*\s*(?:members?|followers?|transactions?|notifications?|items?)|\d{1,2}:\d{2}(?:\s*[AP]M)?|\d+%|today|yesterday|back|next|done|save|share|home|menu|settings|search|view all|unsorted screenshot|saved screenshot|saved reference|wi-?fi|[345]g|lte)$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    final digits = RegExp(r'\d').allMatches(text).length;
    return digits > text.replaceAll(RegExp(r'\s'), '').length * .5;
  }

  static String reference(
    String candidate, {
    String text = '',
    String? visual,
  }) {
    if (visual != null && !weak(visual)) return visual.trim();
    final evidence = '$candidate\n$text';
    // Require multiple related signals before summarizing a notification.
    if (RegExp(
          r'\b(?:kcal|calories)\b',
          caseSensitive: false,
        ).hasMatch(evidence) &&
        RegExp(
          r'\b(?:protein|carbs?|fat|nutrition)\b',
          caseSensitive: false,
        ).hasMatch(evidence)) {
      return 'Nutrition summary';
    }
    final counted = RegExp(
      r'^\d+[\d,.]*\s+(transactions?|notifications?)$',
      caseSensitive: false,
    ).firstMatch(candidate.trim());
    if (counted != null) {
      final noun = counted.group(1)!.toLowerCase();
      return '${noun[0].toUpperCase()}${noun.substring(1)}';
    }
    if (RegExp(
          r'\b(?:members?|participants?)\b',
          caseSensitive: false,
        ).hasMatch(evidence) &&
        RegExp(r'\b(?:group|chat)\b', caseSensitive: false).hasMatch(evidence)) {
      return 'Group details';
    }
    if (RegExp(r'\bcontact\b', caseSensitive: false).hasMatch(evidence) &&
        RegExp(
          r'\b(?:phone|message|call)\b',
          caseSensitive: false,
        ).hasMatch(evidence)) {
      return 'Contact details';
    }
    bool meaningful(String value) =>
        !weak(value) &&
        (value.trim().split(RegExp(r'\s+')).length >= 2 ||
            RegExp(
              r'^(?:receipt|invoice|recipe|diagram|schedule|transactions|notifications)$',
              caseSensitive: false,
            ).hasMatch(value.trim()));
    if (meaningful(candidate)) return candidate.trim();
    for (final line in text.split('\n')) {
      if (meaningful(line)) return line.trim();
    }
    return referenceFallback;
  }
}
