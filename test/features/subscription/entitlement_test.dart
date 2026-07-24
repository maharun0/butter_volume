import 'package:butter_volume/features/subscription/application/entitlement_state.dart';
import 'package:butter_volume/features/subscription/data/offline_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntitlementStatus (doc §6.1 / backend doc §8.2)', () {
    test('premium states', () {
      expect(EntitlementStatus.premiumMonthly.isPremium, isTrue);
      expect(EntitlementStatus.premiumLifetime.isPremium, isTrue);
      // Grace period is treated as premium (doc §6.1).
      expect(EntitlementStatus.gracePeriod.isPremium, isTrue);
    });

    test('free-behavior states', () {
      expect(EntitlementStatus.free.isPremium, isFalse);
      expect(EntitlementStatus.onHold.isPremium, isFalse);
      expect(EntitlementStatus.paused.isPremium, isFalse);
      expect(EntitlementStatus.expired.isPremium, isFalse);
    });

    test('payment-fix banner states', () {
      expect(EntitlementStatus.gracePeriod.needsPaymentFix, isTrue);
      expect(EntitlementStatus.onHold.needsPaymentFix, isTrue);
      expect(EntitlementStatus.premiumLifetime.needsPaymentFix, isFalse);
    });

    test('unknown status ids fall back to free (fail safe)', () {
      expect(EntitlementStatus.fromId('super_ultra'), EntitlementStatus.free);
    });

    test('round-trips its wire id', () {
      for (final status in EntitlementStatus.values) {
        expect(EntitlementStatus.fromId(status.id), status);
      }
    });
  });

  group('offline entitlement token (backend doc §8.4)', () {
    test('rejects malformed tokens', () async {
      expect(await verifyOfflineToken('garbage'), isNull);
      expect(await verifyOfflineToken('bv1.onlytwo'), isNull);
      expect(await verifyOfflineToken('bv2.a.b'), isNull); // wrong version
      expect(await verifyOfflineToken(''), isNull);
    });

    test('rejects forged signature', () async {
      // Well-formed structure, garbage signature — must fail verification.
      const forged = 'bv1.eyJzdGF0dXMiOiJwcmVtaXVtX2xpZmV0aW1lIiwiZXhwIjo5OTk5OTk5OTk5fQ.AAAA';
      expect(await verifyOfflineToken(forged), isNull);
    });
  });
}
