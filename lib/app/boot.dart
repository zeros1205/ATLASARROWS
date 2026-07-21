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
Future<void> bootServices(void Function(double) onProgress) async {
  final steps = <(String, Future<void> Function())>[
    ('settings', AppSettings.instance.load),
    ('progress', Progress.instance.load),
    ('shapes', ShapeCatalog.load),
    ('campaign', CampaignRepository.instance.load),
    // Manifest + a look at what is already cached. No network here — the
    // download itself waits for the preload half, where a slow connection
    // costs the player a progress bar rather than a launch.
    ('stamps', StampStore.instance.load),
  ];
  for (var i = 0; i < steps.length; i++) {
    try {
      await steps[i].$2();
    } catch (e) {
      debugPrint('boot: ${steps[i].$1} failed — $e');
    }
    onProgress((i + 1) / steps.length);
  }
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

/// The post-attach half of the bar (0.65 → 1). Only what the first screen
/// actually shows: the world map behind the campaign tab, the stamps for
/// wherever the player currently is, and the icons the shell and the board
/// draw immediately.
Future<void> preloadFirstFrame(
  BuildContext context, {
  required void Function(double) onProgress,
}) async {
  try {
    await WorldMap.instance.load();
  } catch (e) {
    debugPrint('preload: world map failed — $e');
  }
  onProgress(0.3);

  // One continent's stamps, not all of them. This is the only step here that
  // touches the network, so it owns the widest slice of the bar — and it is
  // allowed to come back empty: the map draws rounds without their stamp until
  // the pack lands, and StampStore retries the next time the player is here.
  await _fetchStampsForCurrentRound((p) => onProgress(0.3 + p * 0.5));
  onProgress(0.8);

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

Future<void> _fetchStampsForCurrentRound(
    void Function(double) onProgress) async {
  final store = StampStore.instance;
  final repo = CampaignRepository.instance;
  if (!store.isLoaded || !repo.isLoaded) return;
  // Rounds run 1..216 in bank order, so the round index is the rank.
  final rank = repo.locate(Progress.instance.unlocked.value).$1 + 1;
  if (store.hasPackFor(rank)) return;
  await store.ensurePackFor(rank, onProgress: onProgress);
}
