import '../../domain/models/imported_image.dart';
import '../../domain/models/screenshot_intent.dart';
import '../../domain/models/screenshot_item.dart';
import 'screenshot_text_extractor.dart';
import 'ocr_document.dart';
import 'structured_extraction.dart';

class ScreenshotAnalysisResult {
  const ScreenshotAnalysisResult({
    required this.intent,
    required this.title,
    required this.subtitle,
    required this.metadata,
    required this.primaryAction,
    required this.archiveLabel,
    required this.confidence,
    required this.matchedSignals,
    required this.extractedFields,
    required this.rawText,
    this.ocrError,
  });

  final ScreenshotIntent intent;
  final String title;
  final String subtitle;
  final List<String> metadata;
  final String primaryAction;
  final String archiveLabel;
  final double confidence;
  final List<String> matchedSignals;
  final Map<String, String> extractedFields;
  final String rawText;
  final String? ocrError;

  ScreenshotItem toItem({required int id, required ImportedImage image}) =>
      ScreenshotItem(
        id: id,
        title: title,
        intent: intent,
        subtitle: subtitle,
        metadata: metadata,
        importedImage: image,
        createdAt: DateTime.now(),
        primaryAction: primaryAction,
        archiveLabel: archiveLabel,
        rawOcrText: rawText,
        analysisConfidence: confidence,
        matchedSignals: matchedSignals,
        extractedFields: extractedFields,
        ocrError: ocrError,
      );
}

abstract class ScreenshotAnalyzer {
  ScreenshotAnalysisResult analyze({
    required ImportedImage image,
    required ExtractedTextResult text,
  });
}

class HeuristicScreenshotAnalyzer implements ScreenshotAnalyzer {
  const HeuristicScreenshotAnalyzer();
  @override
  ScreenshotAnalysisResult analyze({
    required ImportedImage image,
    required ExtractedTextResult text,
  }) {
    final doc = OcrDocument(text);
    final ranked =
        <({ScreenshotIntent intent, double score, List<String> signals})>[];
    void add(
      ScreenshotIntent intent,
      bool eligible,
      double score,
      List<String> signals,
    ) {
      if (eligible) {
        ranked.add((intent: intent, score: score, signals: signals));
      }
    }

    final date = OcrDocument.date.hasMatch(doc.raw);
    final time = OcrDocument.time.hasMatch(doc.raw);
    final due = doc.has(r'\b(?:due|deadline)\b');
    final submit = doc.has(r'\bsubmit(?:ted|ting)?\b');
    final academic = OcrDocument.taskWords.hasMatch(doc.raw);
    final course = doc.course != null;
    add(
      ScreenshotIntent.task,
      academic && (due || submit) || course && due,
      .66 + (due ? .12 : 0) + (submit ? .08 : 0) + (course ? .08 : 0),
      [
        if (due) 'contains_due',
        if (submit) 'contains_submit',
        if (academic) 'academic_task',
        if (course) 'contains_course_code',
      ],
    );
    final event = OcrDocument.eventWords.hasMatch(doc.raw);
    final ticket = doc.has(r'\b(?:tickets?|rsvp|admission|doors)\b');
    add(
      ScreenshotIntent.event,
      (event || ticket) && (date || time),
      .66 + (date ? .10 : 0) + (time ? .08 : 0) + (ticket ? .08 : 0),
      [
        if (event) 'event_context',
        if (ticket) 'attendance_signal',
        if (date) 'contains_date',
        if (time) 'contains_time',
      ],
    );
    final price = OcrDocument.price.hasMatch(doc.raw);
    final purchase = doc.has(r'\b(?:add to cart|buy now|order now|checkout)\b');
    final variation = doc.has(
      r'\b(?:size|colou?r|in stock|out of stock|quantity|shipping|specifications|RAM|SSD)\b',
    );
    final promo = doc.has(r'\b(?:off|discount|coupon)\b');
    add(
      ScreenshotIntent.product,
      price && (purchase || variation) || purchase && promo,
      .68 + (purchase ? .12 : 0) + (variation ? .10 : 0) + (promo ? .06 : 0),
      [
        if (price) 'contains_price',
        if (purchase) 'purchase_action',
        if (variation) 'product_details',
        if (promo) 'promotion',
        if (doc.has(r'\border now\b')) 'contains_order_now',
        if (doc.has(r'\bcode\b')) 'contains_code',
      ],
    );
    final address = OcrDocument.address.hasMatch(doc.raw);
    final business = doc.has(
      r'\b(?:restaurant|cafe|coffee|hotel|bakery|museum|park)\b',
    );
    final hours = doc.has(
      r'\b(?:open until|opens at|closes at|open 24 hours)\b',
    );
    final navigation = doc.has(r'\b(?:directions|reviews|maps)\b');
    add(
      ScreenshotIntent.place,
      address && (business || hours || navigation) || business && hours,
      .68 + (address ? .10 : 0) + (hours ? .10 : 0) + (business ? .06 : 0),
      [
        if (address) 'contains_address',
        if (business) 'place_context',
        if (hours) 'opening_hours',
        if (navigation) 'place_navigation',
      ],
    );
    final byline = doc.lines.any(OcrDocument.byline.hasMatch);
    final readingTime = doc.has(r'\b\d+\s*min(?:ute)?s?\s+read\b');
    final body = doc.raw.split(RegExp(r'\s+')).length >= 22;
    add(
      ScreenshotIntent.read,
      body && (byline || readingTime),
      .68 + (byline ? .10 : 0) + (readingTime ? .10 : 0),
      [
        if (byline) 'author_byline',
        if (readingTime) 'reading_time',
        if (body) 'article_body',
      ],
    );
    ranked.sort((a, b) => b.score.compareTo(a.score));
    final failed = text.error != null || !doc.usable;
    final conflict =
        ranked.length > 1 && ranked.first.score - ranked[1].score < .15;
    final intent = failed || ranked.isEmpty || conflict
        ? ScreenshotIntent.reference
        : ranked.first.intent;
    final signals = failed
        ? [text.error != null ? 'ocr_error' : 'ocr_empty_or_unusable']
        : conflict
        ? ['conflicting_categories', for (final c in ranked) ...c.signals]
        : ranked.isEmpty
        ? ['insufficient_signals']
        : ranked.first.signals;
    final extracted = StructuredExtraction.from(
      failed ? OcrDocument(const ExtractedTextResult(text: '')) : doc,
      intent,
    );
    return ScreenshotAnalysisResult(
      intent: intent,
      title: extracted.title,
      subtitle: extracted.subtitle,
      metadata: extracted.metadata,
      primaryAction: switch (intent) {
        ScreenshotIntent.event => 'Add to Calendar',
        ScreenshotIntent.place => 'Open in Maps',
        ScreenshotIntent.product => 'Add to Wishlist',
        ScreenshotIntent.read => 'Read Later',
        ScreenshotIntent.task => 'Create Reminder',
        ScreenshotIntent.reference => 'Save Reference',
      },
      archiveLabel: 'Saved ${intent.name}',
      confidence: intent == ScreenshotIntent.reference ? 0 : ranked.first.score,
      matchedSignals: List.unmodifiable(signals),
      extractedFields: extracted.fields,
      rawText: text.text,
      ocrError: text.error,
    );
  }
}
