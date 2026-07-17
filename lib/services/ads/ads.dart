/// Ad layer with a platform split: real AdMob on Android/iOS (currently
/// Google's official TEST ad units — swap in production ids at launch),
/// styled placeholder on web/desktop. Both files expose the same API:
///
///   Ads.init()
///   Ads.maybeShowInterstitial(totalClears: ..., levelIndex: ...)
///   AdsBanner()  — 60px-tall banner widget for the bottom of every screen
library;

export 'ads_stub.dart' if (dart.library.io) 'ads_io.dart';
