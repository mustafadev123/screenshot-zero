import '../domain/models/imported_image.dart';
import '../domain/models/screenshot_intent.dart';
import '../domain/models/screenshot_item.dart';

class MockScreenshotAnalyzer {
  const MockScreenshotAnalyzer();

  List<ScreenshotItem> analyze(List<ImportedImage> images) =>
      List.unmodifiable([
        for (var index = 0; index < images.length; index++)
          ScreenshotItem(
            id: index + 1,
            title: 'Ready to organize',
            intent: ScreenshotIntent.reference,
            subtitle: 'Imported screenshot',
            metadata: const ['Temporary demo details · no image analysis yet.'],
            importedImage: images[index],
            primaryAction: 'Save Reference',
            archiveLabel: 'Saved reference · demo details',
          ),
      ]);
}
