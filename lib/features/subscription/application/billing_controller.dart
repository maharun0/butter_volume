import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/constants.dart';
import '../../../core/error/log.dart';
import 'entitlement_controller.dart';

@immutable
class BillingState {
  const BillingState({
    this.storeAvailable = false,
    this.purchasing = false,
    this.justUnlocked = false,
    this.error,
    this.monthlyPrice = r'$0.67',
    this.lifetimePrice = r'$7',
  });

  final bool storeAvailable;
  final bool purchasing;

  /// One-shot flag driving the premium unlock animation (doc §8.10).
  final bool justUnlocked;
  final String? error;
  final String monthlyPrice;
  final String lifetimePrice;

  BillingState copyWith({
    bool? storeAvailable,
    bool? purchasing,
    bool? justUnlocked,
    String? error,
    String? monthlyPrice,
    String? lifetimePrice,
  }) =>
      BillingState(
        storeAvailable: storeAvailable ?? this.storeAvailable,
        purchasing: purchasing ?? this.purchasing,
        justUnlocked: justUnlocked ?? this.justUnlocked,
        error: error,
        monthlyPrice: monthlyPrice ?? this.monthlyPrice,
        lifetimePrice: lifetimePrice ?? this.lifetimePrice,
      );
}

/// Play Billing via `in_app_purchase` (doc §11.2). The client never
/// self-grants premium — every purchase goes through backend verification;
/// this controller only orchestrates.
class BillingController extends Notifier<BillingState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  BillingState build() {
    _sub?.cancel();
    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchases);
    ref.onDispose(() => _sub?.cancel());
    unawaited(_init());
    return const BillingState();
  }

  Future<void> _init() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return;
      final response = await InAppPurchase.instance.queryProductDetails({
        AppConstants.monthlyProductId,
        AppConstants.lifetimeProductId,
      });
      String? monthly;
      String? lifetime;
      for (final p in response.productDetails) {
        if (p.id == AppConstants.monthlyProductId) monthly = p.price;
        if (p.id == AppConstants.lifetimeProductId) lifetime = p.price;
      }
      state = state.copyWith(
        storeAvailable: true,
        monthlyPrice: monthly,
        lifetimePrice: lifetime,
      );
    } catch (e) {
      Log.d('billing unavailable: $e');
    }
  }

  Future<void> purchase(String productId) async {
    ref.read(analyticsProvider).track('purchase_initiated',
        {'product_id': productId});
    if (!state.storeAvailable) {
      state = state.copyWith(
          error: 'The Play Store is not available on this device right now.');
      return;
    }
    state = state.copyWith(purchasing: true);
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails({productId});
      final details = response.productDetails.firstOrNull;
      if (details == null) {
        state = state.copyWith(
            purchasing: false, error: 'Product not found — try again later.');
        return;
      }
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
      // Outcome arrives via purchaseStream.
    } catch (e) {
      Log.w('purchase failed to start', error: e);
      state = state.copyWith(purchasing: false, error: 'Purchase failed.');
      ref.read(analyticsProvider).track('purchase_failed',
          {'product_id': productId, 'error_code': 'launch_failed'});
    }
  }

  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      Log.d('restore unavailable: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await ref
              .read(entitlementProvider.notifier)
              .verifyWithBackend(
                purchase.productID,
                purchase.verificationData.serverVerificationData,
              );
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          if (verified) {
            state = state.copyWith(purchasing: false, justUnlocked: true);
            ref.read(analyticsProvider).track(
              purchase.status == PurchaseStatus.restored
                  ? 'purchase_restored'
                  : 'purchase_completed',
              {'product_id': purchase.productID},
            );
          } else {
            state = state.copyWith(
              purchasing: false,
              error:
                  'Purchase received — verification pending. Premium unlocks '
                  'as soon as we can reach the server.',
            );
          }
        case PurchaseStatus.error:
          state = state.copyWith(
              purchasing: false, error: 'Purchase failed or was cancelled.');
          ref.read(analyticsProvider).track('purchase_failed', {
            'product_id': purchase.productID,
            'error_code': purchase.error?.code ?? 'unknown',
          });
        case PurchaseStatus.canceled:
          state = state.copyWith(purchasing: false);
        case PurchaseStatus.pending:
          state = state.copyWith(purchasing: true);
      }
    }
  }

  void consumeUnlockFlag() {
    if (state.justUnlocked) state = state.copyWith(justUnlocked: false);
  }
}

final billingProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);
