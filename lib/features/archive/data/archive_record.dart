import '../../../domain/models/imported_image.dart';
import '../../../domain/models/screenshot_intent.dart';
import '../../../domain/models/screenshot_item.dart';

/// Versioned user-facing record. No raw OCR, confidence, signals or errors.
class ArchiveRecord {
  static Map<String, Object?> encode(ScreenshotItem item, String imageFile) => {
    'version': 1,
    'archiveId': item.archiveId,
    'id': item.id,
    'archiveNumber': item.archiveNumber,
    'category': item.intent.name,
    'title': item.title,
    'subtitle': item.subtitle,
    'metadata': item.metadata,
    'imageFile': imageFile,
    'sourceName': item.importedImage!.name,
    'primaryAction': item.primaryAction,
    'archiveLabel': item.archiveLabel,
    'savedOnly': item.savedOnly,
    'status': item.actionStatus,
    'fields': {
      for (final entry in item.extractedFields.entries)
        if (_fields.contains(entry.key)) entry.key: entry.value,
    },
    'actionDateTime': item.actionDateTime?.toIso8601String(),
    'notificationId': item.notificationId,
    'createdAt': item.createdAt?.toIso8601String(),
    'processedAt': item.processedAt?.toIso8601String(),
  };
  static const _fields = {
    'title',
    'headline',
    'place',
    'address',
    'hours',
    'venue',
    'date',
    'time',
    'due_date',
    'due_time',
    'course',
    'price',
    'size',
    'color',
    'availability',
    'specifications',
    'author',
    'source',
    'url',
  };

  static ScreenshotItem decode(Map<String, dynamic> data, String imagePath) {
    if ((data['version'] ?? 1) != 1) {
      throw const FormatException('Unsupported archive version');
    }
    final category = ScreenshotIntent.values.byName(data['category'] as String);
    DateTime? date(String key) => DateTime.tryParse(data[key] as String? ?? '');
    final fields = data['fields'] is Map ? data['fields'] as Map : const {};
    return ScreenshotItem(
      id: data['id'] as int,
      archiveNumber: data['archiveNumber'] as int?,
      archiveId: data['archiveId'] as String,
      title: data['title'] as String,
      intent: category,
      subtitle: data['subtitle'] as String? ?? '',
      metadata: data['metadata'] is List
          ? List<String>.unmodifiable(
              (data['metadata'] as List).whereType<String>(),
            )
          : const [],
      importedImage: ImportedImage(
        path: imagePath,
        name: data['sourceName'] as String? ?? 'Screenshot',
      ),
      primaryAction: data['primaryAction'] as String? ?? 'Save Reference',
      archiveLabel: data['archiveLabel'] as String? ?? 'Saved to archive',
      processed: true,
      savedOnly: data['savedOnly'] == true,
      actionStatus: data['status'] as String?,
      extractedFields: Map.unmodifiable({
        for (final entry in fields.entries)
          if (_fields.contains(entry.key) && entry.value is String)
            entry.key as String: entry.value as String,
      }),
      actionDateTime: date('actionDateTime'),
      notificationId: data['notificationId'] as int?,
      createdAt: date('createdAt'),
      processedAt: date('processedAt'),
    );
  }
}
