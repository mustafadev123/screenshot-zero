import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/screenshot_item.dart';

class AnalysisDiagnostics extends StatelessWidget {
  const AnalysisDiagnostics({super.key, required this.item});
  final ScreenshotItem item;
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            'OCR diagnostics\n\nCategory: ${item.intent.name}\n'
            'Confidence: ${item.analysisConfidence}\n'
            'Signals: ${item.matchedSignals.join(', ')}\n'
            'Fields: ${item.extractedFields}\n'
            'Error: ${item.ocrError ?? 'none'}\n\n'
            'Raw OCR:\n${item.rawOcrText ?? '(empty)'}',
          ),
        ),
      ),
    );
  }
}
