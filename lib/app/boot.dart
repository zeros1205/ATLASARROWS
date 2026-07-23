import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:loganland_boot/loganland_boot.dart';

import '../models/campaign_repository.dart';
import '../models/shape_catalog.dart';
import '../models/world_map.dart';
import '../services/ads/ads.dart';
import '../services/firebase.dart';
import '../services/game_services.dart';
import '../services/iap.dart';
import '../services/progress.dart';
import '../services/stamp_store.dart';
import 'app_settings.dart';

/// Lockup colours, sampled from `assets/images/brand/atlas_arrows_wordmark.png`
/// rather than typed in from a design file — the asset is the source of truth,
/// and reading them off it means the bar can never drift from the logo above it.
/// Re-measure after regenerating the lockup:
///
///     python tools/atlas/build_wordmark.py
///     # then the sampling snippet in the kit's APP_WORDMARK_AND_LOADING.md §2.3
///
/// These are the kit's published values, held until Atlas Arrows is given its
/// own palette.
class AppBrand {
  const AppBrand._();

  /// Lockup line 1. Also the loading bar fill. 여기어때 YDS Cyan 800.
  static const Color wordmarkAccent = Color(0xFF1D8BFF);

  /// Lockup line 2. Becomes the CTA background wherever the brand run needs one.
  static const Color wordmarkSlate = Color(0xFF3A4A55);

  static const String wordmark = 'assets/images/brand/atlas_arrows_wordmark.png';
}

/// The cold-start loading plate. Everything except the wordmark and the caption
/// is LOGAN LAND's, and stays at the kit defaults on purpose.
final kBootConfig = LoganLandBootConfig(
  wordmarkAsset: AppBrand.wordmark,
  // Match the home screen's white page ground (AppColors.light.bg) instead of
  // the kit's cream plate — the app wanted the loading screen to hand off to
  // home on the same colour rather than a cream→white step.
  plateColor: const Color(0xFFFFFFFF),
  // The kit's warm-grey track (#6E6961) separates from a teal fill by hue
  // rather than lightness — 1.70:1, which the kit itself flags. Its remedy is
  // to lighten the track, but that is aimed at apps whose accent is near
  // greyscale; against this mint it lands at 1.15:1, worse. Going the other
  // way and using the lockup's own second colour reaches 2.87:1 and leaves
  // the bar made of nothing but the two colours in the logo above it.
  barTrack: AppBrand.wordmarkSlate,
  // Bar fill = lockup line 1 (the accent). Passed explicitly so it tracks
  // AppBrand.wordmarkAccent instead of the kit's default mint.
  barFill: AppBrand.wordmarkAccent,
  // The kit draws this before any localisation exists, so it reads the
  // platform locale directly instead of the app's l10n.
  captionBuilder: (percent) {
    final lang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return switch (lang) {
      'ko' => '지도를 불러오는 중 $percent%',
      'ja' => '地図を読み込み中 $percent%',
      _ => 'Loading the map $percent%',
    };
  },
);

/// Everything the first frame needs, run behind the brand screens.
///
/// Each step swallows its own failure: a throw here leaves the player staring
/// at the loading plate forever, and every one of these degrades to an empty
/// default that later screens re-read when it arrives.
///
/// The world map and stamp packs live here — this phase owns 0→65% of the
/// bar, the larger half, so the slow network step fills most of what the
/// player watches instead of the bar racing to 65% on instant local reads
/// and then crawling through the smaller remaining slice. Neither needs a
/// BuildContext, so nothing here is stuck waiting for one; only the icon
/// precache in preloadFirstFrame does.
Future<void> bootServices(void Function(double) onProgress) async {
  final quickSteps = <(String, Future<void> Function())>[
    ('settings', AppSettings.instance.load),
    ('progress', Progress.instance.load),
    ('shapes', ShapeCatalog.load),
    ('campaign', CampaignRepository.instance.load),
    // Manifest + a look at what is already cached. No network in this one —
    // the download itself is the next step below.
    ('stamps manifest', StampStore.instance.load),
  ];
  for (var i = 0; i < quickSteps.length; i++) {
    try {
      await quickSteps[i].$2();
    } catch (e) {
      debugPrint('boot: ${quickSteps[i].$1} failed — $e');
    }
    onProgress((i + 1) / quickSteps.length * 0.1);
  }

  try {
    await WorldMap.instance.load();
  } catch (e) {
    debugPrint('boot: world map failed — $e');
  }
  onProgress(0.25);

  // Every continent's stamps, downloaded here rather than shipped in the APK.
  // Random play can jump to any continent, so fetching only the current one no
  // longer covers it. This is the slowest step, so it owns the widest slice of
  // the bar — and it is allowed to come back partial: a failed pack retries
  // next launch and the app draws rounds without their stamp meanwhile.
  if (StampStore.instance.isLoaded) {
    await StampStore.instance
        .ensureAllPacks(onProgress: (p) => onProgress(0.25 + p * 0.75));
  }
  onProgress(1);
}

/// The store, ads, Firebase and the games sign-in. Started once the app is up
/// and deliberately never awaited: the ad SDK handshake alone can run for
/// several seconds, and holding the launch on it means the player watches a
/// bar instead of touching a board. Each no-ops when unavailable.
Future<void> initDeferredServices() async {
  unawaited(Ads.init());
  unawaited(IapService.instance.init());
  unawaited(FirebaseService.init().then((_) => GameServices.init()));
}

/// The post-attach half of the bar (0.65 → 1). The world map and stamp packs
/// have already loaded in [bootServices] by this point — all that is left
/// needs a BuildContext, which only exists once the app tree is attached.
Future<void> preloadFirstFrame(
  BuildContext context, {
  required void Function(double) onProgress,
}) async {
  if (!context.mounted) return;
  const icons = [
    'assets/images/icons/heart.png',
    'assets/images/icons/hint.png',
    'assets/images/icons/remove.png',
  ];
  for (final path in icons) {
    try {
      await precacheImage(AssetImage(path), context);
    } catch (_) {/* a missing icon is not worth stalling the launch */}
    if (!context.mounted) return;
  }
  onProgress(1);
}
