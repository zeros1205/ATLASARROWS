import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../shared/meta_header.dart';

/// Shop tab: item bundles (hint / remove) via KRW IAP + rewarded ad, and
/// remove-ads. No gem economy. Skeleton with placeholder tiles.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('상점'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
              children: const [
                _Tile(icon: 'assets/images/icons/hint.png',
                    label: '힌트 10개', price: '₩1,200'),
                _Tile(icon: 'assets/images/icons/remove.png',
                    label: '제거 5개', price: '₩1,900'),
                _Tile(icon: 'assets/images/icons/hint.png',
                    label: '광고 보고 힌트 +1', price: '무료'),
                _Tile(label: '광고 제거', price: '₩9,900', danger: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {this.icon, required this.label, required this.price, this.danger = false});
  final String? icon;
  final String label, price;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = danger ? c.danger : c.accent;
    return Container(
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
              style: AppText.label
                  .copyWith(color: tint, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
