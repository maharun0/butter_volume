import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_client.dart';
import '../data/offline_token.dart';
import 'billing_controller.dart';
import 'entitlement_state.dart';

/// Entitlement state machine (doc §11.2, backend doc §8.2).
///
/// Trust order: backend response > cached signed offline token > free.
/// The pref cache is advisory only (it feeds the Kotlin BootReceiver).
class EntitlementController extends Notifier<EntitlementStatus> {
  @override
  EntitlementStatus build() {
    if (Env.debugPremium) return EntitlementStatus.premiumLifetime;
    final settings = ref.watch(settingsRepositoryProvider);
    unawaited(Future<void>.microtask(bootstrap));
    return EntitlementStatus.fromId(settings.entitlementStatusCached);
  }

  /// App-open flow: honor the offline token immediately, then refresh from
  /// the server opportunistically (backend doc §8.4).
  Future<void> bootstrap() async {
    if (Env.debugPremium) return;

    final stored =
        await ref.read(secureTokenStoreProvider).offlineEntitlementToken;
    if (stored != null) {
      final claim = await verifyOfflineToken(stored);
      if (claim != null && claim.isValid(DateTime.now())) {
        await apply(claim.status);
      } else if (claim != null) {
        // Token expired and server unreachable long enough ⇒ fail safe.
        await apply(EntitlementStatus.expired);
      }
    }
    await refreshFromServer();
  }

  Future<void> refreshFromServer() async {
    final data = await ref.read(apiClientProvider).entitlementsMe();
    if (data == null) return; // offline — cached state stands
    await _applyServerPayload(data);
  }

  /// Server-side purchase verification (doc §11.2 purchase flow).
  Future<bool> verifyWithBackend(String productId, String purchaseToken) async {
    final data = await ref
        .read(apiClientProvider)
        .verifyPurchase(productId, purchaseToken);
    if (data == null) return false;
    await _applyServerPayload(data);
    return state.isPremium;
  }

  /// Restore purchases: Play replays them via the purchase stream (billing
  /// controller verifies each), plus a direct server refresh.
  Future<void> restore() async {
    await ref.read(billingProvider.notifier).restore();
    await refreshFromServer();
  }

  Future<void> _applyServerPayload(Map<String, dynamic> data) async {
    final entitlement = data['entitlement'] as Map<String, dynamic>?;
    final status =
        EntitlementStatus.fromId(entitlement?['status'] as String? ?? 'free');
    final offlineToken = data['offline_token'] as String?;
    if (offlineToken != null) {
      await ref
          .read(secureTokenStoreProvider)
          .setOfflineEntitlementToken(offlineToken);
    }
    await apply(status);
  }

  Future<void> apply(EntitlementStatus status) async {
    state = status;
    await ref.read(settingsRepositoryProvider).cacheEntitlement(
          isPremium: status.isPremium,
          status: status.id,
        );
  }
}

final entitlementProvider =
    NotifierProvider<EntitlementController, EntitlementStatus>(
        EntitlementController.new);

final isPremiumProvider =
    Provider<bool>((ref) => ref.watch(entitlementProvider).isPremium);
