import 'dart:async';

import 'package:screenshot_zero/features/import_preview/data/image_import_service.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/features/analysis/screenshot_text_extractor.dart';
import 'package:screenshot_zero/features/subscription/analysis_quota.dart';
import 'package:screenshot_zero/features/subscription/subscription_service.dart';

class FakeImageImportService implements ImageImportService {
  ImageImportResult result = const ImageImportResult();
  ImageImportResult recovery = const ImageImportResult();
  Future<ImageImportResult>? pending;
  int pickCount = 0;
  int recoverCount = 0;

  @override
  Future<ImageImportResult> pickImages() async {
    pickCount++;
    return pending ?? Future.value(result);
  }

  @override
  Future<ImageImportResult> recoverLostImages() async {
    recoverCount++;
    return recovery;
  }
}

class EmptyScreenshotTextExtractor implements ScreenshotTextExtractor {
  @override
  Future<ExtractedTextResult> extract(ImportedImage image) async =>
      const ExtractedTextResult(text: '');
}

class MemoryAnalysisQuotaStore implements AnalysisQuotaStore {
  int count = 0;

  @override
  Future<int> read() async => count;

  @override
  Future<void> write(int value) async => count = value;

  @override
  Future<void> reset() async => count = 0;
}

class FakeRevenueCatService implements RevenueCatService {
  FakeRevenueCatService({this.pro = true});
  bool pro;
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> get entitlementChanges => _changes.stream;

  @override
  Future<SubscriptionSnapshot> initialize() async =>
      SubscriptionSnapshot(isPro: pro);

  @override
  Future<SubscriptionOperationResult> purchase(String packageIdentifier) async {
    pro = true;
    _changes.add(true);
    return const SubscriptionOperationResult.success(message: 'Pro is active.');
  }

  @override
  Future<SubscriptionOperationResult> restore() async => pro
      ? const SubscriptionOperationResult.success(message: 'Pro restored.')
      : const SubscriptionOperationResult.failed(
          'No active Pro purchase found.',
        );
}
