import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/domain/models/screenshot_item.dart';
import 'package:screenshot_zero/features/actions/platform_action_services.dart';

ScreenshotItem item(
  ScreenshotIntent intent, {
  Map<String, String> fields = const {},
}) => ScreenshotItem(
  id: 1,
  title: 'Example item',
  intent: intent,
  subtitle: 'Details',
  metadata: const [],
  importedImage: const ImportedImage(path: '/tmp/item.png', name: 'item.png'),
  primaryAction: intent.name,
  archiveLabel: 'Saved',
  extractedFields: fields,
);

void main() {
  test('product, read, and reference actions are internal successes', () async {
    final router = ScreenshotActionRouter();
    expect(
      (await router.execute(item(ScreenshotIntent.product))).message,
      'Saved to wishlist',
    );
    expect(
      (await router.execute(item(ScreenshotIntent.read))).message,
      'Saved for reading',
    );
    expect(
      (await router.execute(item(ScreenshotIntent.reference))).message,
      'Saved reference',
    );
  });

  test('calendar refuses incomplete dates instead of inventing one', () async {
    final result = await CalendarActionService().open(
      item(ScreenshotIntent.event),
    );
    expect(result.succeeded, isFalse);
    expect(result.message, contains('complete date and time'));
  });

  test('maps refuses missing place metadata', () async {
    final result = await MapsActionService().open(item(ScreenshotIntent.place));
    expect(result.succeeded, isFalse);
    expect(result.message, contains('Maps'));
  });
}
