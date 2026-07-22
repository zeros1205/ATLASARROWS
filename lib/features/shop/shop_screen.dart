import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../services/ads/ads.dart';
import '../../services/iap.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import '../../shared/pressable.dart';

/// Shop tab: hint / remove bundles via IAP, a free rewarded-ad hint, and
/// remove-ads. No gem economy — the player buys the item, not a currency.
///
/// Rows whose product isn't registered in the store yet render as 준비중 and
/// stay untappable, so an unfinished Play Console never shows a dead price.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _iap = IapService.instance;

  /// Guards the rewarded-ad row against a double tap while the ad opens.
  bool _watchingAd = false;

  // Purchase-result snackbars are handled once, up in AppShell.

  void _watchAdForHint() {
    if (_watchingAd) return;
    setState(() => _watchingAd = true);
    Ads.showRewarded(
      onReward: () {
        Progress.instance.grantHints(1);
        if (mounted) setState(() => _watchingAd = false);
        _toast('힌트 1개를 받았어요.');
      },
      onUnavailable: () {
        if (mounted) setState(() => _watchingAd = false);
        _toast('지금은 볼 수 있는 광고가 없어요. 잠시 후 다시 시도해 주세요.');
      },
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('상점'),
          const _Inventory(),
          Expanded(
            child: ValueListenableBuilder<List<ProductDetails>>(
              valueListenable: _iap.products,
              builder: (context, _, _) => ValueListenableBuilder<bool>(
                valueListenable: _iap.busy,
                builder: (context, busy, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
                  children: [
                    _sectionLabel(context, '아이템'),
                    // Free first — a player with no money still has a way out.
                    _Tile(
                      icon: 'assets/images/icons/hint.png',
                      label: '광고 보고 힌트 +1',
                      price: _watchingAd ? '재생 중…' : '무료',
                      accent: true,
                      enabled: !_watchingAd,
                      onTap: _watchAdForHint,
                    ),
                    for (final id in IapService.hintProducts.keys)
                      _productTile(
                        id: id,
                        icon: 'assets/images/icons/hint.png',
                        fallback: '힌트 ${IapService.hintProducts[id]}개',
                        busy: busy,
                      ),
                    for (final id in IapService.removeProducts.keys)
                      _productTile(
                        id: id,
                        icon: 'assets/images/icons/remove.png',
                        fallback: '제거 ${IapService.removeProducts[id]}개',
                        busy: busy,
                      ),
                    const SizedBox(height: AppGap.lg),
                    _sectionLabel(context, '광고'),
                    ValueListenableBuilder<bool>(
                      valueListenable: Progress.instance.adsRemoved,
                      builder: (context, removed, _) => removed
                          ? const _Tile(
                              label: '광고 제거',
                              price: '보유 중',
                              enabled: false,
                            )
                          : _productTile(
                              id: IapService.removeAdsProduct,
                              fallback: '광고 제거',
                              busy: busy,
                              danger: true,
                            ),
                    ),
                    _Tile(
                      label: '구매 복원',
                      price: '›',
                      enabled: !busy,
                      onTap: _iap.restore,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(text,
          style: AppText.caption
              .copyWith(color: c.inkFaint, letterSpacing: 2)),
    );
  }

  Widget _productTile({
    required String id,
    required String fallback,
    required bool busy,
    String? icon,
    bool danger = false,
  }) {
    final product = _iap.productFor(id);
    final ready = product != null;
    return _Tile(
      icon: icon,
      // Our own label, not the store's — store titles carry an app-name suffix.
      label: fallback,
      // The store's localized price string, so currency follows the account.
      price: ready ? product.price : '준비중',
      danger: danger,
      enabled: ready && !busy,
      onTap: ready ? () => _iap.buy(product) : null,
    );
  }
}

/// What the player already owns, so the shop answers "do I even need this?"
/// before it asks for money.
class _Inventory extends StatelessWidget {
  const _Inventory();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget count(String icon, ValueNotifier<int> source, String label) =>
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: source,
            builder: (context, n, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(icon, width: 20, height: 20),
                const SizedBox(width: 7),
                Text('$n',
                    style: AppText.headline.copyWith(
                        color: c.ink, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text(label,
                    style: AppText.caption.copyWith(color: c.inkFaint)),
              ],
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          count('assets/images/icons/hint.png', Progress.instance.hints, '힌트'),
          Container(width: 1, height: 20, color: c.line),
          count('assets/images/icons/remove.png', Progress.instance.removes,
              '제거'),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    this.icon,
    required this.label,
    required this.price,
    this.danger = false,
    this.accent = false,
    this.enabled = true,
    this.onTap,
  });

  final String? icon;
  final String label, price;
  final bool danger, accent, enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = danger
        ? c.danger
        : accent
            ? c.success
            : c.accent;
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: c.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Image.asset(icon!, width: 24, height: 24),
            const SizedBox(width: 12),
          ],
          Expanded(
              child: Text(label,
                  style: AppText.label
                      .copyWith(color: c.ink, fontWeight: FontWeight.w800))),
          Text(price,
              style: AppText.label.copyWith(
                  color: enabled ? tint : c.inkFaint,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.55, child: tile);
    }
    return Pressable(onTap: onTap!, child: tile);
  }
}
