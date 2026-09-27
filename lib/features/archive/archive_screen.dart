import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../domain/models/screenshot_intent.dart';
import '../../domain/models/screenshot_item.dart';
import '../../shared/widgets/page_frame.dart';
import '../../shared/widgets/screenshot_image.dart';
import '../zero_stack/inbox_provider.dart';
import 'archive_detail.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});
  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  ScreenshotIntent? _filter;
  static const _filters = <String, ScreenshotIntent?>{
    'ALL': null,
    'EVENTS': ScreenshotIntent.event,
    'PLACES': ScreenshotIntent.place,
    'PRODUCTS': ScreenshotIntent.product,
    'TASKS': ScreenshotIntent.task,
    'READS': ScreenshotIntent.read,
    'REFERENCES': ScreenshotIntent.reference,
  };

  @override
  Widget build(BuildContext context) {
    final archived =
        ref.watch(inboxProvider).where((item) => item.processed).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final visible = archived
        .where((item) => _filter == null || item.intent == _filter)
        .toList();
    return PageFrame(
      label: 'Archive',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: MetaLabel('${archived.length.toString().padLeft(2, '0')} kept'),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              24,
              AppSpacing.page,
              28,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Things you\ndecided to keep.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  const Text('Small decisions. A little more space.'),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  for (final entry in _filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.key),
                        showCheckmark: false,
                        labelStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: _filter == entry.value
                                  ? AppColors.paper
                                  : AppColors.ink,
                            ),
                        selected: _filter == entry.value,
                        onSelected: (_) =>
                            setState(() => _filter = entry.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: AppColors.graphite,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      archived.isEmpty
                          ? 'A place for your decisions.'
                          : 'Nothing here just yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      archived.isEmpty
                          ? 'Process or save a screenshot to start your archive.'
                          : 'Try another filter to see what you’ve kept.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: archived.isEmpty
                          ? () => context.go('/home/stack')
                          : () => setState(() => _filter = null),
                      child: Text(
                        archived.isEmpty ? 'Start clearing' : 'Show all',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) =>
                  _ArchiveRow(item: visible[index]),
            ),
          ),
          if (visible.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: MetaLabel(
                  'Filed, not forgotten.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.item});
  final ScreenshotItem item;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(),
      InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => ArchiveDetail(item: item),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 94,
                child: ScreenshotImage(item: item),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetaLabel(item.label),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.disposition,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.north_east, size: 16, color: AppColors.graphite),
            ],
          ),
        ),
      ),
    ],
  );
}
