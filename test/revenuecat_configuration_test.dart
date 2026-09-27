import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/features/subscription/subscription_service.dart';

void main() {
  test('RevenueCat build contract stays stable', () {
    expect(revenueCatApiKeyVariable, 'REVENUECAT_API_KEY');
    expect(proEntitlementId, 'screenshot_zero_pro');
  });
}
