import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress.dart';

/// In-app purchases: hint / remove bundles (consumable) and remove-ads
/// (non-consumable). Product ids must be registered in Play Console / App
/// Store Connect with the same ids; until then [products] stays empty and the
/// shop shows those rows as "준비중".
class IapService {
  IapService._();

  static final IapService instance = IapService._();

  // ⚠️ Store product ids are PERMANENT — once registered they can never be
  // renamed. All four use the short `atlsars_` prefix, settled before the
  // first store submission while nothing was registered yet. Do not
  // reintroduce the pre-rename `zarrows_` prefix for anything new.

  /// productId -> hints granted on purchase.
  static const Map<String, int> hintProducts = {
    'atlsars_hints_10': 10,
    'atlsars_hints_50': 50,
  };

  /// productId -> removes granted on purchase.
  static const Map<String, int> removeProducts = {
    'atlsars_removes_5': 5,
  };

  /// Non-consumable: kills the banner and interstitials for good.
  static const String removeAdsProduct = 'atlsars_remove_ads';

  static Set<String> get _allIds => {
        ...hintProducts.keys,
        ...removeProducts.keys,
        removeAdsProduct,
      };

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final ValueNotifier<List<ProductDetails>> products = ValueNotifier(const []);

  /// True while a purchase is in flight — the shop disables its rows so the
  /// player can't fire a second one on top.
  final ValueNotifier<bool> busy = ValueNotifier(false);

  /// Last user-facing purchase outcome, for a snackbar. Cleared after reading.
  final ValueNotifier<String?> message = ValueNotifier(null);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> init() async {
    if (!supported) return;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;
      _subscription = iap.purchaseStream.listen(_onPurchases);
      final response = await iap.queryProductDetails(_allIds);
      final list = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      products.value = list;
    } catch (_) {}
  }

  /// The store's localized details for [id], or null when it isn't registered
  /// yet (the shop renders those as 준비중 rather than a dead price).
  ProductDetails? productFor(String id) {
    for (final p in products.value) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(ProductDetails product) async {
    if (busy.value) return;
    busy.value = true;
    try {
      final param = PurchaseParam(productDetails: product);
      if (product.id == removeAdsProduct) {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      }
    } catch (_) {
      busy.value = false;
      message.value = '구매를 시작하지 못했어요.';
    }
  }

  /// Restores non-consumables (remove-ads). Consumables are not restorable by
  /// design — they've already been granted and spent.
  Future<void> restore() async {
    if (!supported) {
      message.value = '이 기기에서는 복원을 지원하지 않아요.';
      return;
    }
    busy.value = true;
    try {
      await InAppPurchase.instance.restorePurchases();
      message.value = '구매 내역을 확인했어요.';
    } catch (_) {
      message.value = '복원에 실패했어요.';
    }
    busy.value = false;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          busy.value = true;
          continue;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          busy.value = false;
          if (purchase.status == PurchaseStatus.error) {
            message.value = '구매를 완료하지 못했어요.';
          }
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          busy.value = false;
          _grant(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _grant(PurchaseDetails purchase) {
    final hints = hintProducts[purchase.productID];
    if (hints != null) {
      Progress.instance.grantHints(hints);
      message.value = '힌트 $hints개를 받았어요.';
      return;
    }
    final removes = removeProducts[purchase.productID];
    if (removes != null) {
      Progress.instance.grantRemoves(removes);
      message.value = '제거 $removes개를 받았어요.';
      return;
    }
    if (purchase.productID == removeAdsProduct) {
      Progress.instance.setAdsRemoved(true);
      message.value = '광고가 제거되었어요.';
    }
  }

  void dispose() => _subscription?.cancel();
}
