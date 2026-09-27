import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/imported_image_view.dart';
import 'import_button.dart';
import 'import_provider.dart';

class ImportPreviewScreen extends ConsumerWidget {
  const ImportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(importProvider);
    final count = selection.images.length;
    final noun = count == 1 ? 'screenshot' : 'screenshots';
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && ref.read(importProvider).busy) {
          ref.read(importProvider.notifier).clear();
        }
      },
      child: PageFrame(
        onBack: () {
          if (ref.read(importProvider).busy) {
            ref.read(importProvider.notifier).clear();
          }
          context.go('/home');
        },
        label: 'Contact sheet',
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  selection.progress ??
                      'Only the screenshots you choose are added.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: MetaLabel(
                'New collection · replaces this session',
                textAlign: TextAlign.center,
              ),
            ),
            PrimaryButton(
              label: 'Process $count $noun',
              onPressed: count == 0 || selection.busy
                  ? null
                  : () {
                      ref
                          .read(importProvider.notifier)
                          .processWithResult()
                          .then((result) {
                            if (!context.mounted) return;
                            if (result.outcome ==
                                ImportProcessOutcome.requiresPro) {
                              context.push('/home/pro');
                            } else if (result.outcome ==
                                ImportProcessOutcome.processed) {
                              context.go('/home/stack');
                            }
                          });
                    },
            ),
          ],
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                20,
                AppSpacing.page,
                28,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MetaLabel('01 — A fresh roll'),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '$count selected',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Ready to turn these into actions.'),
                    if (selection.notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(selection.notice!),
                      ),
                  ],
                ),
              ),
            ),
            if (count == 0)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 32,
                        color: AppColors.graphite,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Choose a few things to come back to.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      ImportButton(label: 'Choose screenshots'),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: .66,
                ),
                itemCount: count,
                itemBuilder: (context, index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImportedImageView(image: selection.images[index]),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: 'Remove screenshot ${index + 1}',
                              onPressed: selection.busy
                                  ? null
                                  : () => ref
                                        .read(importProvider.notifier)
                                        .removeAt(index),
                              icon: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    MetaLabel('#${(index + 1).toString().padLeft(4, '0')}'),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
