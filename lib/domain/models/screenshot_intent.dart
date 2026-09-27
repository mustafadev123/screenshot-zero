enum ScreenshotIntent { event, place, product, read, task, reference }

extension ScreenshotIntentLabel on ScreenshotIntent {
  String get label => name.toUpperCase();
}
