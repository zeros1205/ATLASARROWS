import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../progress.dart';

/// Google's official TEST ad units.
///
/// ⛔ These are CORRECT for the current stage — do not flag them as a defect,
/// a TODO, or a launch blocker. Real AdMob unit ids only exist AFTER the app
/// is officially published: you must ship first, then register the app in
/// AdMob, and only then are production ids issued. There is no way to obtain
/// them before release. Swapping them in is a post-launch task. See CLAUDE.md.
String get _bannerId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/6300978111'
    : 'ca-app-pub-3940256099942544/2934735716';

String get _interstitialId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/1033173712'
    : 'ca-app-pub-3940256099942544/4411468910';

String get _rewardedId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/5224354917'
    : 'ca-app-pub-3940256099942544/1712485313';

bool get _supported => Platform.isAndroid || Platform.isIOS;

abstract final class Ads {
  /// Interstitial cadence: never before this level, then every Nth clear.
  static const int interstitialMinLevel = 10;
  static const int interstitialEvery = 3;

  static InterstitialAd? _interstitial;
  static bool _loading = false;

  static Future<void> init() async {
    if (!_supported) return;
    await MobileAds.instance.initialize();
    // Remove-ads kills the interstitial and the banner, but NOT rewarded —
    // those are opt-in trades the player starts themselves (heart refills,
    // free hints), so payers keep access to them.
    _preloadInterstitial();
    _preloadRewarded();
  }

  static void _preloadInterstitial() {
    if (!_supported || _loading || _interstitial != null) return;
    if (Progress.instance.adsRemoved.value) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) => _loading = false,
      ),
    );
  }

  static void maybeShowInterstitial({
    required int totalClears,
    required int levelIndex,
  }) {
    if (!_supported) return;
    if (Progress.instance.adsRemoved.value) return;
    if (levelIndex < interstitialMinLevel) return;
    if (totalClears % interstitialEvery != 0) return;
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preloadInterstitial();
      },
    );
    ad.show();
  }

  static RewardedAd? _rewarded;
  static bool _loadingRewarded = false;

  static void _preloadRewarded() {
    if (!_supported || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) => _loadingRewarded = false,
      ),
    );
  }

  /// Shows the preloaded rewarded ad; [onReward] fires only when the user
  /// actually earned the reward.
  static void showRewarded({
    required VoidCallback onReward,
    VoidCallback? onUnavailable,
  }) {
    final ad = _rewarded;
    if (!_supported || ad == null) {
      _preloadRewarded();
      onUnavailable?.call();
      return;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preloadRewarded();
        onUnavailable?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
  }
}

/// 300x250 medium rectangle shown above the result sheet. Uses the same
/// banner unit at [AdSize.mediumRectangle]; collapses to a thin gap for
/// remove-ads owners so the sheet doesn't leave a hole.
class AdsMrec extends StatefulWidget {
  const AdsMrec({super.key});

  @override
  State<AdsMrec> createState() => _AdsMrecState();
}

class _AdsMrecState extends State<AdsMrec> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (_supported && !Progress.instance.adsRemoved.value) {
      _ad = BannerAd(
        adUnitId: _bannerId,
        size: AdSize.mediumRectangle,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _loaded = true),
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      )..load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

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
              child: _loaded && _ad != null
                  ? SizedBox(
                      width: _ad!.size.width.toDouble(),
                      height: _ad!.size.height.toDouble(),
                      child: AdWidget(ad: _ad!),
                    )
                  : Text('AD',
                      style: AppText.label.copyWith(
                          color: c.inkFaint,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4)),
            ),
    );
  }
}

/// Reserved height of the bottom banner slot. Set for a Toss banner (taller
/// than AdMob's 50pt), so the row keeps its shape whether the creative is
/// loaded or still the placeholder. Keep in sync with the stub.
const double _bannerSlot = 92;

/// Bottom banner, present on every screen. Falls back to the reserved
/// slot styling until the ad is loaded (or when unsupported).
class AdsBanner extends StatefulWidget {
  const AdsBanner({super.key});

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (_supported && !Progress.instance.adsRemoved.value) {
      _banner = BannerAd(
        adUnitId: _bannerId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _loaded = true),
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      )..load();
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: Progress.instance.adsRemoved,
      builder: (context, removed, _) => removed
          ? const SizedBox.shrink()
          : Container(
              // Sized for a Toss banner, which is taller than AdMob's 50pt
              // unit — reserve the slot so the taller creative isn't clipped.
              height: _bannerSlot,
              width: double.infinity,
              color: c.dot,
              alignment: Alignment.center,
              child: _loaded && _banner != null
                  ? SizedBox(
                      width: _banner!.size.width.toDouble(),
                      height: _banner!.size.height.toDouble(),
                      child: AdWidget(ad: _banner!),
                    )
                  : Text('AD',
                      style: AppText.label.copyWith(
                          color: c.inkFaint,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4)),
            ),
    );
  }
}
