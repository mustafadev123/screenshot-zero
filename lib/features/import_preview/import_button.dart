import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'import_provider.dart';

class ImportButton extends ConsumerWidget {
  const ImportButton({super.key, this.label = 'Import screenshots'});
  final String label;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final selected = await ref.read(importProvider.notifier).pick();
    if (!context.mounted) return;
    if (selected) {
      context.go('/home/import');
    } else {
      final notice = ref.read(importProvider).notice;
      if (notice != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(notice)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      importProvider.select((selection) => selection.busy),
    );
    return TextButton.icon(
      onPressed: busy ? null : () => _pick(context, ref),
      icon: const Icon(Icons.add, size: 18),
      label: Text(busy ? 'Opening photos…' : label),
    );
  }
}
