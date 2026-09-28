import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/screenshot_item.dart';
import 'data/archive_repository.dart';
import 'data/archive_repository_factory.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>(
  (ref) => createArchiveRepository(),
);
final archiveProvider = NotifierProvider<ArchiveController, ArchiveState>(
  ArchiveController.new,
);

class ArchiveState {
  const ArchiveState({this.items = const [], this.loading = true, this.error});
  final List<ScreenshotItem> items;
  final bool loading;
  final String? error;
}

class ArchiveController extends Notifier<ArchiveState> {
  late Future<void> _ready;
  Future<void> _writes = Future.value();
  Completer<void>? _clearing;
  final Map<String, ScreenshotItem> _pending = {};
  @override
  ArchiveState build() {
    _ready = Future.microtask(_load);
    return const ArchiveState();
  }

  Future<void> ensureReady() => _ready;
  Future<void> _load() async {
    try {
      final loaded = await ref.read(archiveRepositoryProvider).load();
      if (ref.mounted) {
        state = ArchiveState(items: List.unmodifiable(loaded), loading: false);
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Archive storage could not be opened; no data removed.');
      }
      if (ref.mounted) {
        state = const ArchiveState(
          loading: false,
          error: 'Couldn’t open your archive. Try again.',
        );
      }
    }
  }

  Future<bool> save(ScreenshotItem item) async {
    if (item.importedImage == null) return true;
    final random = Random.secure();
    final id =
        item.archiveId ??
        List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await _ready;
    final clearing = _clearing;
    if (clearing != null) await clearing.future;
    if (!ref.mounted) return false;
    final pending = item.withStorage(
      archiveId: id,
      image: item.importedImage!,
      archiveNumber:
          item.archiveNumber ??
          state.items.fold<int>(
                0,
                (number, item) => max(number, item.archiveNumber ?? item.id),
              ) +
              1,
    );
    _pending[id] = pending;
    state = ArchiveState(
      items: [...state.items.where((i) => i.archiveId != id), pending],
      loading: false,
      error: state.error,
    );
    var success = false;
    _writes = _writes.then((_) async {
      try {
        final stored = await ref.read(archiveRepositoryProvider).save(pending);
        if (!ref.mounted) return;
        _pending.remove(id);
        state = ArchiveState(
          items: List.unmodifiable([
            for (final i in state.items)
              if (i.archiveId == id) stored else i,
          ]),
          loading: false,
          error: _pending.isEmpty ? null : state.error,
        );
        success = true;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('Archive write failed; item retained for retry.');
        }
        if (ref.mounted) {
          state = ArchiveState(
            items: state.items,
            loading: false,
            error: 'Couldn’t save permanently. Please retry before closing the app.',
          );
        }
      }
    });
    await _writes;
    return success;
  }

  Future<void> retry() async {
    if (_pending.isEmpty) {
      _ready = _load();
      await _ready;
    } else {
      for (final item in _pending.values.toList()) {
        await save(item);
      }
    }
  }

  Future<bool> clearDevelopment() async {
    if (!kDebugMode || _clearing != null) return false;
    _clearing = Completer<void>();
    try {
      await _ready;
      await _writes;
      if (_pending.isNotEmpty || !ref.mounted) return false;
      await ref.read(archiveRepositoryProvider).clearDevelopment();
      if (ref.mounted) state = const ArchiveState(loading: false);
      return true;
    } catch (_) {
      return false;
    } finally {
      _clearing!.complete();
      _clearing = null;
    }
  }
}
