import '../../domain/models/screenshot_item.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_action_services.dart';

enum ActionOutcome { success, cancelled, failed }

class ActionResult {
  const ActionResult(this.outcome, {this.message, this.notificationId});

  const ActionResult.success({String? message, int? notificationId})
    : this(
        ActionOutcome.success,
        message: message,
        notificationId: notificationId,
      );
  const ActionResult.cancelled({String? message})
    : this(ActionOutcome.cancelled, message: message);
  const ActionResult.failed(String message)
    : this(ActionOutcome.failed, message: message);

  final ActionOutcome outcome;
  final String? message;
  final int? notificationId;

  bool get succeeded => outcome == ActionOutcome.success;
}

abstract class ScreenshotActionService {
  Future<ActionResult> execute(ScreenshotItem item, {DateTime? confirmedAt});
}

final screenshotActionServiceProvider = Provider<ScreenshotActionService>(
  (ref) => ScreenshotActionRouter(),
);

// Also protects against duplicate launches after leaving/reopening Zero Stack.
final actionExecutionLockProvider = Provider((ref) => ActionExecutionLock());

class ActionExecutionLock {
  bool _busy = false;
  bool acquire() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void release() => _busy = false;
}
