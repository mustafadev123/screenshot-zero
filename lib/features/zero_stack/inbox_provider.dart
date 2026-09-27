import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/screenshot_item.dart';
import '../../mock/mock_screenshots.dart';

final inboxProvider = NotifierProvider<InboxController, List<ScreenshotItem>>(
  InboxController.new,
);

class InboxController extends Notifier<List<ScreenshotItem>> {
  @override
  List<ScreenshotItem> build() => List.unmodifiable(mockScreenshots);

  void reset() => state = List.unmodifiable(mockScreenshots);

  void replaceCollection(List<ScreenshotItem> items) =>
      state = List.unmodifiable(items);

  void process(
    int id, {
    bool saveOnly = false,
    String? status,
    ScreenshotItem? expected,
    DateTime? actionDateTime,
    int? notificationId,
  }) {
    state = List.unmodifiable([
      for (final item in state)
        if (item.id == id &&
            !item.processed &&
            (expected == null || identical(item, expected)))
          item.complete(
            saveOnly: saveOnly,
            status: status,
            actionDateTime: actionDateTime,
            notificationId: notificationId,
          )
        else
          item,
    ]);
  }

  // Skipped cards stay in the inbox and return after the other waiting cards.
  void skip(int id) {
    final index = state.indexWhere((item) => item.id == id && !item.processed);
    if (index < 0) return;
    final reordered = [...state];
    final item = reordered.removeAt(index);
    reordered.add(item);
    state = List.unmodifiable(reordered);
  }
}
