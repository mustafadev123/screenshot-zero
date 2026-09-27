import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const freeAnalysisLimit = 10;

abstract class AnalysisQuotaStore {
  Future<int> read();
  Future<void> write(int count);
  Future<void> reset();
}

class SharedPreferencesAnalysisQuotaStore implements AnalysisQuotaStore {
  static const _key = 'real_analysis_count';

  @override
  Future<int> read() async {
    try {
      return (await SharedPreferences.getInstance()).getInt(_key) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> write(int count) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(_key, count);
    } catch (_) {}
  }

  @override
  Future<void> reset() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

final analysisQuotaStoreProvider = Provider<AnalysisQuotaStore>(
  (ref) => SharedPreferencesAnalysisQuotaStore(),
);

class AnalysisQuotaController extends Notifier<int> {
  Future<void>? _initialization;

  @override
  int build() {
    _initialization = _load();
    return 0;
  }

  Future<void> ensureReady() => _initialization ?? Future<void>.value();

  Future<void> _load() async {
    final value = await ref.read(analysisQuotaStoreProvider).read();
    if (ref.mounted) state = value;
  }

  Future<void> add(int count) async {
    final next = state + count;
    state = next;
    await ref.read(analysisQuotaStoreProvider).write(next);
  }

  Future<void> reset() async {
    state = 0;
    await ref.read(analysisQuotaStoreProvider).reset();
  }
}

final analysisQuotaProvider = NotifierProvider<AnalysisQuotaController, int>(
  AnalysisQuotaController.new,
);
