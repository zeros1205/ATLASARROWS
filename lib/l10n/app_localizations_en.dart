// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabMap => 'Map';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabSettings => 'Settings';

  @override
  String get homeWorldTour => 'World Tour';

  @override
  String get homeWorldTourContinue => 'Continue World Tour';

  @override
  String get homeRandom => 'Random';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsHaptics => 'Vibration';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsReplayTutorial => 'Replay tutorial';

  @override
  String get settingsRestorePurchases => 'Restore purchases';

  @override
  String get removeAds => 'Remove ads';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get owned => 'Owned';

  @override
  String get shopSectionItems => 'Items';

  @override
  String get shopSectionAds => 'Ads';

  @override
  String get shopWatchAdForHint => 'Watch an ad for +1 hint';

  @override
  String get adPlaying => 'Playing…';

  @override
  String get free => 'Free';

  @override
  String hintsBundle(int count) {
    return '$count hints';
  }

  @override
  String removesBundle(int count) {
    return '$count removes';
  }

  @override
  String get inventoryHints => 'Hints';

  @override
  String get inventoryRemoves => 'Removes';

  @override
  String get toastHintGranted1 => 'You got 1 hint.';

  @override
  String get toastNoAdAvailable =>
      'No ad available right now. Please try again in a moment.';

  @override
  String get iapPurchaseStartFailed => 'Couldn\'t start the purchase.';

  @override
  String get iapRestoreUnsupported =>
      'Restoring isn\'t supported on this device.';

  @override
  String get iapRestoreChecked => 'Checked your purchases.';

  @override
  String get iapRestoreFailed => 'Restore failed.';

  @override
  String get iapPurchaseFailed => 'Couldn\'t complete the purchase.';

  @override
  String iapHintsGranted(int count) {
    return 'You got $count hints.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'You got $count removes.';
  }

  @override
  String get iapAdsRemoved => 'Ads removed.';

  @override
  String get adPlaceholderMrec => 'MREC banner ad';

  @override
  String get onboardingEscapeTitle => 'Tap an arrow';

  @override
  String get onboardingEscapeBody =>
      'A tapped arrow slides off the board in the direction its head points.';

  @override
  String get onboardingBlockedTitle => 'Blocked ahead? It bumps';

  @override
  String get onboardingBlockedBody =>
      'If an arrow is in the way it bounces back and you lose a heart. Order is everything.';

  @override
  String get onboardingClearTitle => 'Clear the board to win';

  @override
  String get onboardingClearBody =>
      'Send every arrow out to finish the stage, then follow the world map to the next country.';

  @override
  String get onboardingItemsTitle => 'Two items can help';

  @override
  String get onboardingItemHintDesc =>
      'Shows an arrow you can free right now — it blinks blue.';

  @override
  String get onboardingItemRemoveDesc =>
      'Tap it, then tap any arrow to clear it out of the way.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingStart => 'Start playing';

  @override
  String get next => 'Next';

  @override
  String get mapLoadError => 'Couldn\'t load the map.';

  @override
  String get areaUnderOne => 'Under 1 ㎢';

  @override
  String get gameRestartTitle => 'Restart?';

  @override
  String get gameRestartBody =>
      'Every arrow you\'ve cleared so far goes back to its starting position.';

  @override
  String get gameRestartConfirm => 'Restart';

  @override
  String get gameLeaveTitle => 'Leave the game?';

  @override
  String get gameLeaveBody => 'Your current board won\'t be saved.';

  @override
  String get gameLeaveConfirm => 'Leave';

  @override
  String get cancel => 'Cancel';

  @override
  String get coachTapArrow => 'Try tapping a glowing arrow';

  @override
  String get coachPinchZoom => 'Pinch with two fingers to zoom';

  @override
  String get coachHintBubble => 'We\'ll find an arrow you can free.';

  @override
  String get coachRemoveBubble => 'Tap the arrow to remove.';

  @override
  String get barFit => 'Fit';

  @override
  String get barHint => 'Hint';

  @override
  String get barRemove => 'Remove';

  @override
  String get barRestart => 'Restart';

  @override
  String get heartsOutTitle => 'Out of hearts';

  @override
  String get heartsOutFree => 'Keep playing.';

  @override
  String get heartsOutAd => 'Watch one ad to refill your hearts.';

  @override
  String refillCoupon(int count) {
    return 'Refill coupon ($count)';
  }

  @override
  String get refillViaAd => 'Watch ad to refill';

  @override
  String get itemSheetNoHints => 'No hints left';

  @override
  String get itemSheetNoRemoves => 'No removes left';

  @override
  String get itemSheetRefill => 'Top up and keep solving.';

  @override
  String get clearContinue => 'Continue';

  @override
  String roundBadge(String round) {
    return 'ROUND $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'What you\'ll learn this round — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Travel through $count cities of $country, then solve the whole country at the end.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Solve the whole territory of $country in a single board.';
  }

  @override
  String get roundStatStages => 'Stages';

  @override
  String get roundStatCities => 'Cities';

  @override
  String get roundStatCountry => 'Country';

  @override
  String get roundStart => 'Start round';
}
