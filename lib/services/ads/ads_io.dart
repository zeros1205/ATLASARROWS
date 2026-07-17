import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../theme.dart';

/// Google's official TEST ad units. Replace with production ids at launch.
String get _bannerId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/6300978111'
    : 'ca-app-pub-3940256099942544/2934735716';

String get _interstitialId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/1033173712'
    : 'ca-app-pub-3940256099942544/4411468910';

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
    _preloadInterstitial();
  }

  static void _preloadInterstitial() {
    if (!_supported || _loading || _interstitial != null) return;
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
}

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
    if (_supported) {
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
    return Container(
      height: 60,
      width: double.infinity,
      color: ZTheme.dot,
      alignment: Alignment.center,
      child: _loaded && _banner != null
          ? SizedBox(
              width: _banner!.size.width.toDouble(),
              height: _banner!.size.height.toDouble(),
              child: AdWidget(ad: _banner!),
            )
          : const Text(
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
