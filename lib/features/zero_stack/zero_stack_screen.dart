import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../domain/models/screenshot_item.dart';
import '../../shared/widgets/page_frame.dart';
import '../analysis/analysis_diagnostics.dart';
import '../actions/action_confirmation.dart';
import '../actions/screenshot_action_service.dart';
import 'screenshot_deck.dart';
import 'inbox_provider.dart';
import 'inbox_zero_screen.dart';

class ZeroStackScreen extends ConsumerStatefulWidget {
  const ZeroStackScreen({super.key});
  @override
  ConsumerState<ZeroStackScreen> createState() => _ZeroStackScreenState();
}

class _ZeroStackScreenState extends ConsumerState<ZeroStackScreen> {
  bool _transitioning = false;
  bool _skipped = false;

  Future<void> _decide(
    ScreenshotItem item, {
    bool saveOnly = false,
    bool skip = false,
  }) async {
    if (_transitioning) return;
    final lock = ref.read(actionExecutionLockProvider);
    if (!lock.acquire()) return;
    final duration = motionDuration(context);
    setState(() {
      _transitioning = true;
      _skipped = skip;
    });
    try {
      final inbox = ref.read(inboxProvider.notifier);
      if (skip) {
        inbox.skip(item.id);
      } else if (saveOnly || item.importedImage == null) {
        inbox.process(item.id, saveOnly: saveOnly);
      } else {
        DateTime? confirmedAt;
        if (item.intent.name == 'event' || item.intent.name == 'task') {
          confirmedAt = await confirmActionTime(context, item);
          if (!mounted || confirmedAt == null) return;
        }
        if (!ref.read(inboxProvider).any((current) => identical(current, item)))
          return;
        final result = await ref
            .read(screenshotActionServiceProvider)
            .execute(item, confirmedAt: confirmedAt);
        if (!mounted) return;
        if (!result.succeeded) {
          if (result.outcome == ActionOutcome.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.message ?? "Couldn't complete this action.",
                ),
              ),
            );
          }
          return;
        }
        if (!ref.read(inboxProvider).any((current) => identical(current, item)))
          return;
        if (item.intent.name == 'event') {
          if (!await confirmCalendarSaved(context) || !mounted) return;
        }
        inbox.process(
          item.id,
          expected: item,
          status: item.intent.name == 'event'
              ? 'Added to calendar'
              : result.message,
          actionDateTime: confirmedAt,
          notificationId: result.notificationId,
        );
      }
      if (ref.read(inboxProvider).every((item) => item.processed)) {
        context.go('/home/zero');
        return;
      }
      await Future<void>.delayed(duration);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't complete this action. Please try again."),
          ),
        );
    } finally {
      lock.release();
      if (mounted) setState(() => _transitioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inboxProvider);
    final waiting = items.where((item) => !item.processed).toList();
    if (waiting.isEmpty) return const InboxZeroScreen();
    final item = waiting.first;
    final completed = items.length - waiting.length;
    return PageFrame(
      label: 'Zero Stack',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: MetaLabel(
          '${(completed + 1).toString().padLeft(2, '0')} / ${items.length.toString().padLeft(2, '0')}',
          color: AppColors.ink,
        ),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: item.primaryAction.toUpperCase(),
            onPressed: _transitioning ? null : () => _decide(item),
            icon: Icons.check,
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _transitioning
                      ? null
                      : () => _decide(item, skip: true),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(height: 14, child: VerticalDivider()),
              Expanded(
                child: TextButton(
                  onPressed: _transitioning
                      ? null
                      : () => _decide(item, saveOnly: true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: MetaLabel(
              _skipped
                  ? 'Kept for later · still in your inbox'
                  : item.importedImage != null
                  ? 'You choose what happens next'
                  : 'Demo mode · actions stay in this app',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: completed / items.length,
                      minHeight: 2,
                      backgroundColor: AppColors.border,
                      color: AppColors.signal,
                      semanticsLabel: '$completed of ${items.length} processed',
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedSwitcher(
                    duration: motionDuration(context),
                    child: MetaLabel(
                      '${waiting.length} remaining',
                      key: ValueKey(waiting.length),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: (constraints.maxHeight * .64).clamp(260.0, 430.0),
                child: ScreenshotDeck(waiting: waiting),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onLongPress: kDebugMode && item.importedImage != null
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AnalysisDiagnostics(item: item),
                      )
                    : null,
                child: MetaLabel(item.label, color: AppColors.graphite),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              for (final line in item.metadata) Text(line),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
