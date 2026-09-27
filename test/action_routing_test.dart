import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/screenshot_item.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/actions/platform_action_services.dart';
import 'package:screenshot_zero/features/actions/screenshot_action_service.dart';

import 'screenshot_action_service_test.dart' show item;

class CalendarSpy extends CalendarActionService {
  int calls = 0;
  DateTime? received;
  @override
  Future<ActionResult> open(
    ScreenshotItem item, {
    DateTime? confirmedAt,
  }) async {
    calls++;
    received = confirmedAt;
    return const ActionResult.success(message: 'Calendar opened');
  }
}

class MapsSpy extends MapsActionService {
  int calls = 0;
  @override
  Future<ActionResult> open(ScreenshotItem item) async {
    calls++;
    return const ActionResult.success(message: 'Opened in Maps');
  }
}

class ReminderSpy extends ReminderActionService {
  int calls = 0;
  DateTime? received;
  @override
  Future<ActionResult> create(
    ScreenshotItem item, {
    DateTime? confirmedAt,
  }) async {
    calls++;
    received = confirmedAt;
    return const ActionResult.success(
      message: 'Reminder set',
      notificationId: 99,
    );
  }
}

void main() {
  test(
    'six categories route once to the right service or internal save',
    () async {
      final calendar = CalendarSpy();
      final maps = MapsSpy();
      final reminders = ReminderSpy();
      final router = ScreenshotActionRouter(
        calendar: calendar,
        maps: maps,
        reminders: reminders,
      );
      final time = DateTime(2030, 9, 30, 23, 59);
      final expected = {
        ScreenshotIntent.event: 'Calendar opened',
        ScreenshotIntent.place: 'Opened in Maps',
        ScreenshotIntent.task: 'Reminder set',
        ScreenshotIntent.product: 'Saved to wishlist',
        ScreenshotIntent.read: 'Saved for reading',
        ScreenshotIntent.reference: 'Saved reference',
      };
      for (final entry in expected.entries) {
        final result = await router.execute(item(entry.key), confirmedAt: time);
        expect(result.succeeded, isTrue);
        expect(result.message, entry.value);
      }
      expect(calendar.calls, 1);
      expect(maps.calls, 1);
      expect(reminders.calls, 1);
      expect(calendar.received, time);
      expect(reminders.received, time);
    },
  );
  test('only real web URLs can expose Open Link', () {
    for (final bad in [
      null,
      '',
      'invented-site',
      'javascript:alert(1)',
      'file:///tmp/private',
      'https:///',
    ]) {
      expect(ArticleLinkService.validUrl(bad), isNull);
    }
    expect(
      ArticleLinkService.validUrl('https://example.org/story')?.host,
      'example.org',
    );
  });
}
