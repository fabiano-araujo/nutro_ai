import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/premium_access.dart';

void main() {
  final now = DateTime(2026, 8, 11, 20);

  test('free snapshot stays locked', () {
    expect(
      resolvePremiumAccess(
        purchasePlanType: 'free',
        userPlanType: 'free',
        now: now,
      ),
      isFalse,
    );
  });

  test('paid plan snapshot unlocks while boolean status is restoring', () {
    expect(
      resolvePremiumAccess(
        purchaseIsPremium: false,
        userIsPremium: false,
        userPlanType: 'annual',
        now: now,
      ),
      isTrue,
    );
  });

  test('future expiration unlocks a temporarily stale snapshot', () {
    expect(
      resolvePremiumAccess(
        purchaseIsPremium: false,
        userIsPremium: false,
        userPlanType: 'free',
        userExpirationDate: now.add(const Duration(days: 3)),
        now: now,
      ),
      isTrue,
    );
  });

  test('expired snapshot without a paid plan stays locked', () {
    expect(
      resolvePremiumAccess(
        purchaseIsPremium: false,
        userIsPremium: false,
        userPlanType: 'free',
        userExpirationDate: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      isFalse,
    );
  });
}
