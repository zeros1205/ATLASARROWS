/// Ad layer with a platform split: real AdMob on Android/iOS, styled
/// placeholder on web/desktop.
///
/// Both files expose the same API:
///
///   Ads.init()
///   Ads.showRewarded(onReward: ..., onUnavailable: ...)
///   AdsBanner()  — bottom banner widget (slot sized for a Toss banner)
///   AdsMrec()    — 300x250 medium rectangle for the result sheet
library;

export 'ads_stub.dart' if (dart.library.io) 'ads_io.dart';
