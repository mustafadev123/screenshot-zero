import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const proEntitlementId = 'screenshot_zero_pro';
const revenueCatApiKeyVariable = 'REVENUECAT_API_KEY';
const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY');

class SubscriptionPackage {
  const SubscriptionPackage({
    required this.identifier,
    required this.price,
    required this.period,
  });

  final String identifier;
  final String price;
  final String period;
}

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.isPro,
    this.packages = const [],
    this.error,
  });

  final bool isPro;
  final List<SubscriptionPackage> packages;
  final String? error;
}

enum SubscriptionResult { success, cancelled, failed }

class SubscriptionOperationResult {
  const SubscriptionOperationResult(this.result, {this.message});

  const SubscriptionOperationResult.success({String? message})
    : this(SubscriptionResult.success, message: message);
  const SubscriptionOperationResult.cancelled({String? message})
    : this(SubscriptionResult.cancelled, message: message);
  const SubscriptionOperationResult.failed(String message)
    : this(SubscriptionResult.failed, message: message);

  final SubscriptionResult result;
  final String? message;

  bool get succeeded => result == SubscriptionResult.success;
}

abstract class RevenueCatService {
  Stream<bool> get entitlementChanges;
  Future<SubscriptionSnapshot> initialize();
  Future<SubscriptionOperationResult> purchase(String packageIdentifier);
  Future<SubscriptionOperationResult> restore();
}

class PurchasesRevenueCatService implements RevenueCatService {
  PurchasesRevenueCatService({String? apiKey})
    : _apiKey = apiKey ?? revenueCatApiKey;

  final String _apiKey;
  final _changes = StreamController<bool>.broadcast();
  Offering? _offering;
  bool _configured = false;
  late final CustomerInfoUpdateListener _listener = _onCustomerInfoChanged;

  void _onCustomerInfoChanged(CustomerInfo info) {
    _changes.add(info.entitlements.active.containsKey(proEntitlementId));
  }

  @override
  Stream<bool> get entitlementChanges => _changes.stream;

  @override
  Future<SubscriptionSnapshot> initialize() async {
    if (_apiKey.trim().isEmpty) {
      return const SubscriptionSnapshot(
        isPro: false,
        error: 'RevenueCat is not configured for this build.',
      );
    }
    try {
      if (!_configured) {
        await Purchases.configure(PurchasesConfiguration(_apiKey));
        Purchases.addCustomerInfoUpdateListener(_listener);
        _configured = true;
      }
      final info = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      _offering = offerings.current;
      return _snapshot(info);
    } catch (error) {
      return SubscriptionSnapshot(isPro: false, error: error.toString());
    }
  }

  @override
  Future<SubscriptionOperationResult> purchase(String packageIdentifier) async {
    final offering = _offering;
    if (!_configured || offering == null) {
      return const SubscriptionOperationResult.failed(
        'Pro offerings are unavailable right now.',
      );
    }
    final package = offering.availablePackages
        .where((candidate) => candidate.identifier == packageIdentifier)
        .firstOrNull;
    if (package == null) {
      return const SubscriptionOperationResult.failed(
        'That Pro package is unavailable right now.',
      );
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isPro = result.customerInfo.entitlements.active.containsKey(
        proEntitlementId,
      );
      return isPro
          ? const SubscriptionOperationResult.success(message: 'Pro is active.')
          : const SubscriptionOperationResult.failed(
              'Purchase completed, but Pro is not active yet.',
            );
    } catch (error) {
      if (error is PlatformException &&
          PurchasesErrorHelper.getErrorCode(error) ==
              PurchasesErrorCode.purchaseCancelledError) {
        return const SubscriptionOperationResult.cancelled();
      }
      return SubscriptionOperationResult.failed('Purchase failed: $error');
    }
  }

  @override
  Future<SubscriptionOperationResult> restore() async {
    if (!_configured) {
      return const SubscriptionOperationResult.failed(
        'RevenueCat is not configured for this build.',
      );
    }
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active.containsKey(proEntitlementId);
      _changes.add(isPro);
      return isPro
          ? const SubscriptionOperationResult.success(message: 'Pro restored.')
          : const SubscriptionOperationResult.failed(
              'No active Pro purchase found.',
            );
    } catch (error) {
      return SubscriptionOperationResult.failed('Restore failed: $error');
    }
  }

  SubscriptionSnapshot _snapshot(CustomerInfo info) => SubscriptionSnapshot(
    isPro: info.entitlements.active.containsKey(proEntitlementId),
    packages: [
      for (final package in _offering?.availablePackages ?? const [])
        SubscriptionPackage(
          identifier: package.identifier,
          price: package.storeProduct.priceString,
          period: package.storeProduct.subscriptionPeriod ?? '',
        ),
    ],
  );

  Future<void> dispose() async {
    if (_configured) Purchases.removeCustomerInfoUpdateListener(_listener);
    await _changes.close();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
