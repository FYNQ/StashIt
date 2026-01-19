// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Platform-specific packages for Android & iOS:
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../data/drift/database.dart';

/// Handles product discovery, purchase updates & entitlement sync.
/// Singleton: PurchaseService.I available after construction.
class PurchaseService {
  static late PurchaseService I;

  final AppDatabase db;
  final InAppPurchase _iap = InAppPurchase.instance;

  // Define your subscription product IDs (must match Play/App Store).
  static const Set<String> kProductIds = {
    'premium_monthly',
    'premium_yearly',
  };

  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool get isStoreAvailable => _available;

  // Cached products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  PurchaseService(this.db) {
    PurchaseService.I = this;
  }

  Future<void> init() async {
    // 1) Check billing availability
    _available = await _iap.isAvailable();

    // 2) Query products (safe to retry later)
    await refreshProducts();

    // 3) Listen for purchases
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _sub?.cancel(),
      onError: (e) {
        // Ignore; user can retry
      },
    );

    // 4) Restore & sync entitlements on fresh start (best-practice)
    await restoreAndSyncEntitlements();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> refreshProducts() async {
    if (!_available) return;
    final response = await _iap.queryProductDetails(kProductIds);
    _products = response.productDetails;
  }

  Future<void> restoreAndSyncEntitlements() async {
    if (!_available) return;
    await _iap.restorePurchases();
    // The purchase stream will deliver restored purchases to _onPurchaseUpdated.
  }

  // Buy a subscription product (monthly/yearly)
  Future<void> buy(ProductDetails details) async {
    if (!_available) return;

    PurchaseParam param;

    if (Platform.isAndroid) {
      // Cast to Android-specific product.
      final googleDetails = details is GooglePlayProductDetails ? details : null;

      if (googleDetails != null) {
        // NOTE: We DO NOT pass offerToken here to remain compatible with in_app_purchase_android 0.4.x.
        // This works when your subscription has a single base plan or doesn't require offer selection.
        param = GooglePlayPurchaseParam(
          productDetails: googleDetails,
          changeSubscriptionParam: null,
        );
      } else {
        // Fallback if cast fails
        param = PurchaseParam(productDetails: details);
      }
    } else if (Platform.isIOS) {
      // iOS: standard param
      param = PurchaseParam(productDetails: details);
    } else {
      // Other platforms not supported
      return;
    }

    // Subscriptions are purchased via buyNonConsumable in the plugin
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> updates) async {
    if (updates.isEmpty) return;

    bool anyActive = false;

    for (final p in updates) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // NOTE: For production apps, verify receipts server-side!
          anyActive = true;

          // Cache entitlement locally for gating
          await db.setPremiumActive(true);
          await db.setPremiumProductId(p.productID);

          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.pending:
          // Optional: show spinner in UI
          break;

        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          // Do not clear active entitlement here; user may have another active sub
          if (p.pendingCompletePurchase) {
            // Best-effort cleanup
            try {
              await _iap.completePurchase(p);
            } catch (_) {}
          }
          break;
      }
    }

    // If none of these updates turned active, we leave the current entitlement as-is.
    // A restore() call at init ensures correctness on each launch.
  }

  ProductDetails? findProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
