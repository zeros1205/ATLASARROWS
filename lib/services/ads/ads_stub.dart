import 'package:flutter/material.dart';

import '../../theme.dart';

/// Web/desktop stub: no ad SDK, just the reserved layout slot.
abstract final class Ads {
  static Future<void> init() async {}

  static void maybeShowInterstitial({
    required int totalClears,
    required int levelIndex,
  }) {}

  /// No ad SDK here — succeed immediately so the reward flow is testable
  /// during web/desktop development.
  static void showRewarded({
    required VoidCallback onReward,
    VoidCallback? onUnavailable,
  }) {
    onReward();
  }
}

class AdsBanner extends StatelessWidget {
  const AdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      color: ZTheme.dot,
      alignment: Alignment.center,
      child: const Text(
        'AD',
        style: TextStyle(
          color: ZTheme.inkSoft,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    );
  }
}
