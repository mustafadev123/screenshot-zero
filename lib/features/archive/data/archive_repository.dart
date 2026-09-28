import '../../../domain/models/screenshot_item.dart';

import 'package:flutter/foundation.dart';

abstract class ArchiveRepository {
  Future<List<ScreenshotItem>> load();
  Future<ScreenshotItem> save(ScreenshotItem item);
  Future<void> clearDevelopment() async =>
      throw UnsupportedError('Development reset unavailable');
}

/// Browser preview and test double; production mobile uses the file repository.
class MemoryArchiveRepository implements ArchiveRepository {
  final Map<String, ScreenshotItem> records = {};
  @override
  Future<void> clearDevelopment() async {
    if (!kDebugMode) throw StateError('Development only');
    records.clear();
  }

  @override
  Future<List<ScreenshotItem>> load() async => records.values.toList();
  @override
  Future<ScreenshotItem> save(ScreenshotItem item) async {
    records[item.archiveId!] = item;
    return item;
  }
}
