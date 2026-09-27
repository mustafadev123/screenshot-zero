import 'screenshot_intent.dart';
import 'imported_image.dart';

enum ScreenshotArtwork {
  concert,
  restaurant,
  shoes,
  article,
  assignment,
  reference,
  exhibition,
  lamp,
}

class ScreenshotItem {
  const ScreenshotItem({
    required this.id,
    required this.title,
    required this.intent,
    required this.subtitle,
    required this.metadata,
    this.artwork,
    this.importedImage,
    required this.primaryAction,
    required this.archiveLabel,
    this.processed = false,
    this.savedOnly = false,
    this.rawOcrText,
    this.analysisConfidence,
    this.matchedSignals = const [],
    this.extractedFields = const {},
    this.ocrError,
    this.actionStatus,
    this.actionDateTime,
    this.notificationId,
  }) : assert((artwork == null) != (importedImage == null));
  final int id;
  final String title;
  final ScreenshotIntent intent;
  final String subtitle;
  final List<String> metadata;
  final ScreenshotArtwork? artwork;
  final ImportedImage? importedImage;
  final String primaryAction;
  final String archiveLabel;
  final bool processed;
  final bool savedOnly;
  final String? rawOcrText;
  final double? analysisConfidence;
  final List<String> matchedSignals;
  final Map<String, String> extractedFields;
  final String? ocrError;
  final String? actionStatus;
  final DateTime? actionDateTime;
  final int? notificationId;

  String get sequence => '#${id.toString().padLeft(4, '0')}';
  String get label => '${intent.label} · $sequence';
  String get disposition =>
      savedOnly ? 'Saved to archive' : actionStatus ?? archiveLabel;

  ScreenshotItem complete({
    bool saveOnly = false,
    String? status,
    DateTime? actionDateTime,
    int? notificationId,
  }) => ScreenshotItem(
    id: id,
    title: title,
    intent: intent,
    subtitle: subtitle,
    metadata: metadata,
    artwork: artwork,
    importedImage: importedImage,
    primaryAction: primaryAction,
    archiveLabel: archiveLabel,
    processed: true,
    savedOnly: saveOnly,
    rawOcrText: rawOcrText,
    analysisConfidence: analysisConfidence,
    matchedSignals: matchedSignals,
    extractedFields: extractedFields,
    ocrError: ocrError,
    actionStatus: status ?? actionStatus,
    actionDateTime: actionDateTime ?? this.actionDateTime,
    notificationId: notificationId ?? this.notificationId,
  );
}
