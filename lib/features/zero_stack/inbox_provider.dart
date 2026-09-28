import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/screenshot_item.dart';
import '../../mock/mock_screenshots.dart';
import '../archive/archive_provider.dart';

final inboxProvider = NotifierProvider<InboxController, List<ScreenshotItem>>(
  InboxController.new,
);

class InboxController extends Notifier<List<ScreenshotItem>> {
  @override
  List<ScreenshotItem> build() => List.unmodifiable(mockScreenshots);

  void reset() => state = List.unmodifiable(mockScreenshots);

  void replaceCollection(List<ScreenshotItem> items) =>
      state = List.unmodifiable(items);

  Future<bool> process(
    int id, {
    bool saveOnly = false,
    String? status,
    ScreenshotItem? expected,
    DateTime? actionDateTime,
    int? notificationId,
  }) async {
    final selected = state
        .where(
          (item) =>
              item.id == id &&
              !item.processed &&
              (expected == null || identical(item, expected)),
        )
        .firstOrNull;
    if (selected == null) return false;
    final completed = selected.complete(
      saveOnly: saveOnly,
      status: status,
      actionDateTime: actionDateTime,
      notificationId: notificationId,
    );
    state = List.unmodifiable([
      for (final item in state)
        if (item.id == id &&
            !item.processed &&
            (expected == null || identical(item, expected)))
          completed
        else
          item,
    ]);
    // A failed disk write must never replay a completed external action.
    if (completed.importedImage == null) return true;
    return ref.read(archiveProvider.notifier).save(completed);
  }

  // Dismiss only from this session; do not archive or touch the source image.
  void skip(int id) {
    final index = state.indexWhere((item) => item.id == id && !item.processed);
    if (index < 0) return;
    final remaining = [...state]..removeAt(index);
    state = List.unmodifiable(remaining);
  }
}
