import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/models/screenshot_item.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/screenshot_image.dart';
import '../actions/platform_action_services.dart';

class ArchiveDetail extends StatelessWidget {
  const ArchiveDetail({super.key, required this.item});
  final ScreenshotItem item;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: SizedBox(
              height: 280,
              width: 215,
              child: ScreenshotImage(item: item, radius: 8),
            ),
          ),
          const SizedBox(height: 24),
          MetaLabel(item.label),
          const SizedBox(height: 8),
          Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(item.subtitle),
          for (final line in item.metadata) Text(line),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text(item.disposition),
          if (item.actionDateTime != null)
            Text(
              '${MaterialLocalizations.of(context).formatMediumDate(item.actionDateTime!.toLocal())} · ${TimeOfDay.fromDateTime(item.actionDateTime!.toLocal()).format(context)} (${item.actionDateTime!.toLocal().timeZoneName})',
            ),
          if (item.intent.name == 'read' &&
              item.importedImage != null &&
              ArticleLinkService.validUrl(item.extractedFields['url']) != null)
            _OpenArticleLink(url: item.extractedFields['url']!),
          const SizedBox(height: 8),
          MetaLabel(
            item.importedImage == null
                ? 'Demo record · no external action was taken'
                : item.savedOnly || item.actionStatus == null
                ? 'Local analysis · saved to archive'
                : 'Action recorded · screenshot kept in this session',
          ),
          if (kDebugMode && item.importedImage != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const MetaLabel('OCR diagnostics'),
            const SizedBox(height: 8),
            Text('Category: ${item.intent.name}'),
            Text(
              'Confidence: ${(item.analysisConfidence ?? 0).toStringAsFixed(2)}',
            ),
            Text(
              'Signals: ${item.matchedSignals.isEmpty ? 'none' : item.matchedSignals.join(', ')}',
            ),
            Text(
              'Fields: ${item.extractedFields.isEmpty ? 'none' : item.extractedFields}',
            ),
            Text(
              'Raw OCR: ${item.rawOcrText?.isNotEmpty == true ? item.rawOcrText : '(empty)'}',
            ),
            if (item.ocrError != null) ...[
              const SizedBox(height: 8),
              Text('OCR error: ${item.ocrError}'),
            ],
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Back to archive',
            icon: Icons.check,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _OpenArticleLink extends StatefulWidget {
  const _OpenArticleLink({required this.url});
  final String url;
  @override
  State<_OpenArticleLink> createState() => _OpenArticleLinkState();
}

class _OpenArticleLinkState extends State<_OpenArticleLink> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            final result = await ArticleLinkService().open(widget.url);
            if (!mounted || !context.mounted) return;
            setState(() => busy = false);
            if (!result.succeeded)
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.message!)));
          },
    child: const Text('OPEN LINK'),
  );
}
