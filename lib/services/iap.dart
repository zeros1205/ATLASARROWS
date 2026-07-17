import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress.dart';

/// Hint-bundle in-app purchases (consumables). Product ids must be
/// registered in Play Console / App Store Connect with the same ids;
/// until then [products] stays empty and the shop shows the items as
/// "preparing".
class IapService {
  IapService._();

  static final IapService instance = IapService._();

  /// productId -> hints granted on purchase.
  static const Map<String, int> hintProducts = {
    'zarrows_hints_10': 10,
    'zarrows_hints_50': 50,
  };

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final ValueNotifier<List<ProductDetails>> products = ValueNotifier(const []);
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> init() async {
    if (!supported) return;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;
      _subscription = iap.purchaseStream.listen(_onPurchases);
      final response =
          await iap.queryProductDetails(hintProducts.keys.toSet());
      final list = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      products.value = list;
    } catch (_) {}
  }

  Future<void> buy(ProductDetails product) async {
    try {
      await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {}
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final granted = hintProducts[purchase.productID];
      if (granted != null &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        Progress.instance.grantHints(granted);
      }
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void dispose() => _subscription?.cancel();
}
