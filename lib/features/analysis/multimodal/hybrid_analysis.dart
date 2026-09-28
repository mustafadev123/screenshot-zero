import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/imported_image.dart';
import '../../../domain/models/screenshot_intent.dart';
import '../../../domain/models/title_quality.dart';
import '../screenshot_analyzer.dart';
import 'multimodal_service.dart';
import 'visual_consent.dart';
import 'backend_multimodal_service.dart';

class FallbackPolicy {
  const FallbackPolicy({
    this.strongLocal = .8,
    this.strongVisual = .8,
    this.minimumTextCharacters = 24,
    this.timeout = const Duration(seconds: 25),
  });
  final double strongLocal;
  final double strongVisual;
  final int minimumTextCharacters;
  final Duration timeout;

  String? trigger(ScreenshotAnalysisResult local) {
    if (local.confidence >= strongLocal) return null;
    if (local.matchedSignals.contains('conflicting_categories')) {
      return 'competing_categories';
    }
    if (local.rawText.trim().length < minimumTextCharacters) {
      return 'sparse_text';
    }
    if (local.intent == ScreenshotIntent.reference) return 'weak_reference';
    return 'low_confidence';
  }
}

final multimodalServiceProvider = Provider<MultimodalAnalysisService>(
  (ref) => BackendMultimodalService(
    baseUrl: const String.fromEnvironment('MULTIMODAL_API_BASE_URL'),
  ),
);
final visualConsentStoreProvider = Provider<VisualConsentStore>(
  (ref) => SharedPreferencesVisualConsentStore(),
);
final fallbackPolicyProvider = Provider<FallbackPolicy>(
  (ref) => const FallbackPolicy(),
);
final hybridAnalysisProvider = Provider<HybridAnalysis>(
  (ref) => HybridAnalysis(
    service: ref.watch(multimodalServiceProvider),
    consent: ref.watch(visualConsentStoreProvider),
    policy: ref.watch(fallbackPolicyProvider),
  ),
);

class HybridAnalysis {
  HybridAnalysis({
    required this.service,
    required this.consent,
    this.policy = const FallbackPolicy(),
  });
  final MultimodalAnalysisService service;
  final VisualConsentStore consent;
  final FallbackPolicy policy;

  Future<ScreenshotAnalysisResult> refine({
    required ImportedImage image,
    required ScreenshotAnalysisResult local,
    required bool isPro,
    Future<bool> Function()? requestConsent,
    bool Function()? stillActive,
  }) async {
    final trigger = policy.trigger(local);
    void log(
      String decision, [
      MultimodalResult? visual,
      ScreenshotAnalysisResult? result,
    ]) {
      if (kDebugMode) {
        debugPrint(
          'visual fallback=${trigger ?? "none"} local=${local.intent.name}/${local.confidence} visual=${visual?.category.name}/${visual?.confidence} final=${(result ?? local).intent.name} decision=$decision',
        );
      }
    }

    if (trigger == null || !isPro || !service.available) {
      log(
        trigger == null
            ? 'strong_local'
            : !isPro
            ? 'pro_required'
            : 'unavailable',
      );
      return local;
    }
    try {
      var allowed = await consent.read().timeout(policy.timeout);
      if (stillActive?.call() == false) return local;
      if (allowed == null) {
        if (requestConsent == null) return local;
        allowed = await requestConsent();
        await consent.write(allowed).timeout(policy.timeout);
      }
      if (!allowed || stillActive?.call() == false) {
        log('declined_or_cancelled');
        return local;
      }
      final visual = await service
          .analyze(MultimodalRequest(image: image, local: local))
          .timeout(policy.timeout);
      if (stillActive?.call() == false) return local;
      final result = resolve(local, visual);
      log(
        identical(result, local) ? 'keep_local' : 'resolved_visual',
        visual,
        result,
      );
      return result;
    } catch (_) {
      log('failure_keep_local');
      return local;
    }
  }

  ScreenshotAnalysisResult resolve(
    ScreenshotAnalysisResult local,
    MultimodalResult visual,
  ) {
    if (local.confidence >= policy.strongLocal) {
      if (visual.confidence >= policy.strongVisual &&
          local.intent != visual.category) {
        return _result(
          local,
          ScreenshotIntent.reference,
          'Saved screenshot',
          0,
          const {},
        );
      }
      return local;
    }
    if (visual.confidence < policy.strongVisual) {
      return local.intent == ScreenshotIntent.reference
          ? local
          : _result(
              local,
              ScreenshotIntent.reference,
              local.title,
              0,
              const {},
            );
    }
    if (TitleQuality.weak(visual.title)) return local;
    final conflict = local.matchedSignals.contains('conflicting_categories');
    final category = conflict || !visual.hasActionEvidence
        ? ScreenshotIntent.reference
        : visual.category;
    final fields = <String, String>{};
    final allowedFields = switch (category) {
      ScreenshotIntent.event => {'date', 'time', 'venue', 'address', 'url'},
      ScreenshotIntent.place => {'address', 'url'},
      ScreenshotIntent.product => {'price', 'variant', 'size', 'url'},
      ScreenshotIntent.read => {'author', 'publication', 'url'},
      ScreenshotIntent.task => {'dueDate', 'dueTime'},
      ScreenshotIntent.reference => <String>{},
    };
    for (final entry in visual.fields.entries) {
      if (allowedFields.contains(entry.key)) {
        fields[switch (entry.key) {
              'dueDate' => 'due_date',
              'dueTime' => 'due_time',
              'variant' => 'color',
              _ => entry.key,
            }] =
            entry.value;
      }
    }
    final title = category == ScreenshotIntent.reference
        ? TitleQuality.reference(
            local.title,
            text: local.rawText,
            visual: visual.title,
          )
        : visual.title;
    return _result(local, category, title, visual.confidence, fields);
  }

  ScreenshotAnalysisResult _result(
    ScreenshotAnalysisResult local,
    ScreenshotIntent intent,
    String title,
    double confidence,
    Map<String, String> fields,
  ) => ScreenshotAnalysisResult(
    intent: intent,
    title: title,
    subtitle: intent == ScreenshotIntent.reference
        ? TitleQuality.referenceCopy
        : fields.values.firstOrNull ?? 'Saved screenshot',
    metadata: fields.values.skip(1).toList(),
    primaryAction: switch (intent) {
      ScreenshotIntent.event => 'Add to Calendar',
      ScreenshotIntent.place => 'Open in Maps',
      ScreenshotIntent.product => 'Add to Wishlist',
      ScreenshotIntent.read => 'Read Later',
      ScreenshotIntent.task => 'Create Reminder',
      ScreenshotIntent.reference => 'Save Reference',
    },
    archiveLabel: 'Saved ${intent.name}',
    confidence: confidence,
    matchedSignals: const ['visual_resolution'],
    extractedFields: Map.unmodifiable(fields),
    rawText: local.rawText,
    ocrError: local.ocrError,
  );
}
