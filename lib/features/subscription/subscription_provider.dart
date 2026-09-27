import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_service.dart';

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.loading = true,
    this.packages = const [],
    this.error,
  });

  final bool isPro;
  final bool loading;
  final List<SubscriptionPackage> packages;
  final String? error;
}

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  final service = PurchasesRevenueCatService();
  ref.onDispose(service.dispose);
  return service;
});

final subscriptionProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );

class SubscriptionController extends Notifier<SubscriptionState> {
  StreamSubscription<bool>? _listener;
  Future<void>? _initialization;

  @override
  SubscriptionState build() {
    final service = ref.read(revenueCatServiceProvider);
    _listener = service.entitlementChanges.listen((isPro) {
      if (ref.mounted) {
        state = SubscriptionState(
          isPro: isPro,
          loading: false,
          packages: state.packages,
          error: state.error,
        );
      }
    });
    ref.onDispose(() => _listener?.cancel());
    _initialization = _initialize(service);
    unawaited(_initialization!);
    return const SubscriptionState();
  }

  Future<void> ensureReady() => _initialization ?? Future<void>.value();

  Future<void> _initialize(RevenueCatService service) async {
    final snapshot = await service.initialize();
    if (!ref.mounted) return;
    state = SubscriptionState(
      isPro: snapshot.isPro,
      loading: false,
      packages: snapshot.packages,
      error: snapshot.error,
    );
  }

  Future<SubscriptionOperationResult> purchase(String packageIdentifier) async {
    state = SubscriptionState(
      isPro: state.isPro,
      loading: true,
      packages: state.packages,
      error: state.error,
    );
    final result = await ref
        .read(revenueCatServiceProvider)
        .purchase(packageIdentifier);
    if (ref.mounted) {
      state = SubscriptionState(
        isPro: result.succeeded || state.isPro,
        loading: false,
        packages: state.packages,
        error: result.succeeded ? null : result.message,
      );
    }
    return result;
  }

  Future<SubscriptionOperationResult> restore() async {
    state = SubscriptionState(
      isPro: state.isPro,
      loading: true,
      packages: state.packages,
      error: state.error,
    );
    final result = await ref.read(revenueCatServiceProvider).restore();
    if (ref.mounted) {
      state = SubscriptionState(
        isPro: result.succeeded || state.isPro,
        loading: false,
        packages: state.packages,
        error: result.succeeded ? null : result.message,
      );
    }
    return result;
  }
}
