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

  /// Lockup line 1. Also the loading bar fill.
  static const Color wordmarkAccent = Color(0xFF00A19B);

  /// Lockup line 2. Becomes the CTA background wherever the brand run needs one.
  static const Color wordmarkSlate = Color(0xFF3A4A55);

  static const String wordmark = 'assets/images/brand/atlas_arrows_wordmark.png';
}

/// The cold-start loading plate. Everything except the wordmark and the caption
/// is LOGAN LAND's, and stays at the kit defaults on purpose.
final kBootConfig = LoganLandBootConfig(
  wordmarkAsset: AppBrand.wordmark,
  // The kit draws this before any localisation exists, so it reads the
  // platform locale directly instead of the app's l10n.
  captionBuilder: (percent) {
    final lang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return switch (lang) {
      'ko' => '화살표를 불러오는 중 $percent%',
      'ja' => '矢印を読み込み中 $percent%',
      _ => 'Loading arrows $percent%',
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
/// actually shows: the world map behind the campaign tab, and the icons the
/// shell and the board draw immediately.
Future<void> preloadFirstFrame(
  BuildContext context, {
  required void Function(double) onProgress,
}) async {
  try {
    await WorldMap.instance.load();
  } catch (e) {
    debugPrint('preload: world map failed — $e');
  }
  onProgress(0.5);
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
