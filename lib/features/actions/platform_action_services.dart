import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/screenshot_item.dart';
import 'action_date_parser.dart';
import 'screenshot_action_service.dart';

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class CalendarActionService {
  Future<ActionResult> open(
    ScreenshotItem item, {
    DateTime? confirmedAt,
  }) async {
    final begin =
        confirmedAt ??
        parseActionDate(
          item.extractedFields['date'],
          item.extractedFields['time'],
        );
    if (begin == null) {
      return const ActionResult.failed(
        'A complete date and time are needed before opening Calendar.',
      );
    }
    if (!_android)
      return const ActionResult.failed(
        'Calendar creation is available on Android.',
      );
    try {
      await AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/events',
        arguments: {
          'title': item.title,
          'description': item.subtitle,
          if (item.extractedFields['venue'] != null)
            'eventLocation': item.extractedFields['venue']!,
          'beginTime': begin.millisecondsSinceEpoch,
        },
      ).launch();
      // An intent launch is not proof that the user saved in Calendar.
      return const ActionResult.success(message: 'Calendar opened');
    } catch (_) {
      return const ActionResult.failed(
        "Couldn't open Calendar. Please install or enable a calendar app.",
      );
    }
  }
}

class MapsActionService {
  Future<ActionResult> open(ScreenshotItem item) async {
    final name = item.extractedFields['place'];
    final address = item.extractedFields['address'];
    final query = [
      name,
      address,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    if (query.isEmpty)
      return const ActionResult.failed(
        "Couldn't open Maps without a place or address.",
      );
    final geo = Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}');
    final web = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    if (_android) {
      try {
        if (await launchUrl(geo, mode: LaunchMode.externalApplication)) {
          return const ActionResult.success(message: 'Opened in Maps');
        }
      } catch (_) {
        /* Try the browser fallback below. */
      }
    }
    try {
      if (await launchUrl(web, mode: LaunchMode.externalApplication)) {
        return const ActionResult.success(message: 'Opened in Maps');
      }
    } catch (_) {
      /* Return an actionable failure. */
    }
    return const ActionResult.failed("Couldn't open Maps. Please try again.");
  }
}

class ReminderActionService {
  ReminderActionService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  Future<ActionResult> create(
    ScreenshotItem item, {
    DateTime? confirmedAt,
  }) async {
    if (confirmedAt == null || !confirmedAt.isAfter(DateTime.now())) {
      return const ActionResult.failed(
        'Choose and confirm a future date and time for this reminder.',
      );
    }
    if (!_android)
      return const ActionResult.failed(
        'Local reminders are available on Android.',
      );
    try {
      if (!_initialized) {
        final initialized = await _notifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
          ),
        );
        if (initialized != true)
          return const ActionResult.failed("Couldn't initialize reminders.");
        tz_data.initializeTimeZones();
        _initialized = true;
      }
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      if (granted != true || await android?.areNotificationsEnabled() != true) {
        return const ActionResult.failed(
          'Notifications are disabled. Allow notifications in Android settings, then try again.',
        );
      }
      final pending = await _notifications.pendingNotificationRequests();
      final used = pending.map((n) => n.id).toSet();
      var id = DateTime.now().millisecondsSinceEpoch % 2147483647;
      while (used.contains(id)) {
        id = (id + 1) % 2147483647;
      }
      await _notifications.zonedSchedule(
        id,
        item.title,
        item.subtitle,
        // Convert the confirmed local instant to UTC explicitly. tz.local
        // defaults to UTC and must not be used as if it were the device zone.
        tz.TZDateTime.from(confirmedAt.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'screenshot_zero_reminders',
            'Screenshot Zero reminders',
            channelDescription: 'Reminders created from Screenshot Zero',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return ActionResult.success(message: 'Reminder set', notificationId: id);
    } catch (_) {
      return const ActionResult.failed(
        "Reminder wasn't created. Please try again.",
      );
    }
  }
}

class ScreenshotActionRouter implements ScreenshotActionService {
  ScreenshotActionRouter({
    CalendarActionService? calendar,
    MapsActionService? maps,
    ReminderActionService? reminders,
  }) : _calendar = calendar ?? CalendarActionService(),
       _maps = maps ?? MapsActionService(),
       _reminders = reminders ?? ReminderActionService();
  final CalendarActionService _calendar;
  final MapsActionService _maps;
  final ReminderActionService _reminders;
  @override
  Future<ActionResult> execute(ScreenshotItem item, {DateTime? confirmedAt}) =>
      switch (item.intent.name) {
        'event' => _calendar.open(item, confirmedAt: confirmedAt),
        'place' => _maps.open(item),
        'task' => _reminders.create(item, confirmedAt: confirmedAt),
        'product' => Future.value(
          const ActionResult.success(message: 'Saved to wishlist'),
        ),
        'read' => Future.value(
          const ActionResult.success(message: 'Saved for reading'),
        ),
        _ => Future.value(
          const ActionResult.success(message: 'Saved reference'),
        ),
      };
}

class ArticleLinkService {
  static Uri? validUrl(String? text) {
    final uri = text == null ? null : Uri.tryParse(text);
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  Future<ActionResult> open(String text) async {
    final uri = validUrl(text);
    if (uri == null)
      return const ActionResult.failed('No readable web link was found.');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return const ActionResult.success(message: 'Link opened');
      }
    } catch (_) {
      /* Keep the saved article. */
    }
    return const ActionResult.failed("Couldn't open this link.");
  }
}
