/// Ad layer with a platform split: real AdMob on Android/iOS, styled
/// placeholder on web/desktop.
///
/// The Android/iOS side runs Google's official TEST ad units, which is the
/// correct and only possible state before release — production ids are issued
/// only after the app is published and registered in AdMob. Not a blocker.
///
/// Both files expose the same API:
///
///   Ads.init()
///   Ads.maybeShowInterstitial(totalClears: ..., levelIndex: ...)
///   Ads.showRewarded(onReward: ..., onUnavailable: ...)
///   AdsBanner()  — bottom banner widget (slot sized for a Toss banner)
///   AdsMrec()    — 300x250 medium rectangle for the result sheet
library;

export 'ads_stub.dart' if (dart.library.io) 'ads_io.dart';
