import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/imported_image.dart';
import '../../domain/models/screenshot_item.dart';
import '../../features/analysis/mlkit_screenshot_text_extractor.dart';
import '../../features/analysis/screenshot_analyzer.dart';
import '../../features/analysis/screenshot_text_extractor.dart';
import '../zero_stack/inbox_provider.dart';
import 'data/image_import_service.dart';
import '../subscription/analysis_quota.dart';
import '../subscription/subscription_provider.dart';

enum ImportProcessOutcome { processed, requiresPro, failed }

class ImportProcessResult {
  const ImportProcessResult(this.outcome);
  const ImportProcessResult.processed() : this(ImportProcessOutcome.processed);
  const ImportProcessResult.requiresPro()
    : this(ImportProcessOutcome.requiresPro);
  const ImportProcessResult.failed() : this(ImportProcessOutcome.failed);

  final ImportProcessOutcome outcome;
}

final imageImportServiceProvider = Provider<ImageImportService>(
  (ref) => PickerImageImportService(),
);
final screenshotTextExtractorProvider = Provider<ScreenshotTextExtractor>((
  ref,
) {
  final extractor = MlKitScreenshotTextExtractor();
  ref.onDispose(extractor.close);
  return extractor;
});
final screenshotAnalyzerProvider = Provider<ScreenshotAnalyzer>(
  (ref) => const HeuristicScreenshotAnalyzer(),
);
final importProvider = NotifierProvider<ImportController, ImportSelection>(
  ImportController.new,
);

class ImportSelection {
  const ImportSelection({
    this.images = const [],
    this.busy = false,
    this.notice,
    this.progress,
  });
  final List<ImportedImage> images;
  final bool busy;
  final String? notice;
  final String? progress;
}

class ImportController extends Notifier<ImportSelection> {
  @override
  ImportSelection build() => const ImportSelection();

  bool _recovered = false;
  int _generation = 0;
  bool _processing = false;

  Future<bool> pick() => _select(recover: false);

  Future<bool> recover() async {
    if (_recovered) return false;
    _recovered = true;
    return _select(recover: true);
  }

  Future<bool> _select({required bool recover}) async {
    if (state.busy || _processing) return false;
    final generation = _generation;
    final previous = state.images;
    state = ImportSelection(images: previous, busy: true);
    ImageImportResult result;
    try {
      final service = ref.read(imageImportServiceProvider);
      result = await (recover
          ? service.recoverLostImages()
          : service.pickImages());
    } catch (_) {
      result = const ImageImportResult(
        notice: 'Couldn’t open those images. Please try again.',
      );
    }
    if (!ref.mounted || generation != _generation) return false;
    final selected = result.images.isNotEmpty;
    state = ImportSelection(
      images: selected ? List.unmodifiable(result.images) : previous,
      notice: result.notice,
    );
    return selected;
  }

  void removeAt(int index) {
    if (state.busy || index < 0 || index >= state.images.length) return;
    final images = [...state.images]..removeAt(index);
    state = ImportSelection(images: List.unmodifiable(images));
  }

  Future<bool> process() async =>
      (await processWithResult()).outcome == ImportProcessOutcome.processed;

  Future<ImportProcessResult> processWithResult() async {
    if (state.busy || _processing || state.images.isEmpty) {
      return const ImportProcessResult.failed();
    }
    final generation = _generation;
    final images = state.images;
    _processing = true;
    state = ImportSelection(
      images: images,
      busy: true,
      progress: 'Reading 1 of ${images.length}',
    );
    final extractor = ref.read(screenshotTextExtractorProvider);
    final analyzer = ref.read(screenshotAnalyzerProvider);
    final firstText = extractor.extract(images.first);
    final readiness = Future.wait([
      ref.read(subscriptionProvider.notifier).ensureReady(),
      ref.read(analysisQuotaProvider.notifier).ensureReady(),
    ]);
    await readiness;
    if (!ref.mounted || generation != _generation) {
      _processing = false;
      return const ImportProcessResult.failed();
    }
    final isPro = ref.read(subscriptionProvider).isPro;
    final used = ref.read(analysisQuotaProvider);
    if (!isPro && used + images.length > freeAnalysisLimit) {
      _processing = false;
      state = ImportSelection(images: images);
      return const ImportProcessResult.requiresPro();
    }
    final items = <ScreenshotItem>[];
    try {
      state = ImportSelection(
        images: images,
        busy: true,
        progress: 'Organizing screenshots',
      );
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        if (!ref.mounted || generation != _generation) {
          return const ImportProcessResult.failed();
        }
        state = ImportSelection(
          images: images,
          busy: true,
          progress: 'Reading ${index + 1} of ${images.length}',
        );
        ScreenshotAnalysisResult result;
        try {
          final text = await (index == 0
              ? firstText
              : extractor.extract(image));
          if (!ref.mounted || generation != _generation) {
            return const ImportProcessResult.failed();
          }
          result = analyzer.analyze(image: image, text: text);
        } catch (_) {
          result = const HeuristicScreenshotAnalyzer().analyze(
            image: ImportedImage(path: '', name: ''),
            text: ExtractedTextResult(text: '', error: 'OCR pipeline failed'),
          );
        }
        items.add(result.toItem(id: index + 1, image: image));
      }
      if (!ref.mounted || generation != _generation) {
        return const ImportProcessResult.failed();
      }
      ref.read(inboxProvider.notifier).replaceCollection(items);
      await ref.read(analysisQuotaProvider.notifier).add(items.length);
      clear();
      return const ImportProcessResult.processed();
    } finally {
      _processing = false;
    }
  }

  void clear() {
    _generation++;
    state = const ImportSelection();
  }
}
