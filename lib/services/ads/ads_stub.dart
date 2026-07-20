import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../progress.dart';

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

/// 300x250 medium rectangle shown above the result sheet.
class AdsMrec extends StatelessWidget {
  const AdsMrec({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: Progress.instance.adsRemoved,
      builder: (context, removed, _) => removed
          ? const SizedBox(height: 12)
          : Container(
              height: 250,
              width: 300,
              color: c.dot,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('중간 배너 광고',
                      style: AppText.label
                          .copyWith(color: c.inkFaint, letterSpacing: 3)),
                  Text('300 × 250',
                      style: AppText.caption.copyWith(color: c.inkFaint)),
                ],
              ),
            ),
    );
  }
}

/// Reserved height of the bottom banner slot. Sized for a Toss banner (taller
/// than AdMob's 50pt). Keep in sync with the io implementation.
const double _bannerSlot = 100;

class AdsBanner extends StatelessWidget {
  const AdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Owners of remove-ads get the slot back, not an empty grey bar.
    return ValueListenableBuilder<bool>(
      valueListenable: Progress.instance.adsRemoved,
      builder: (context, removed, _) => removed
          ? const SizedBox.shrink()
          : Container(
              height: _bannerSlot,
              width: double.infinity,
              color: c.dot,
              alignment: Alignment.center,
              child: Text('AD',
                  style: AppText.label.copyWith(
                      color: c.inkFaint,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4)),
            ),
    );
  }
}
