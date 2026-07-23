import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
  ];

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get tabShop;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @homeWorldTour.
  ///
  /// In en, this message translates to:
  /// **'World Tour'**
  String get homeWorldTour;

  /// No description provided for @homeWorldTourContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue World Tour'**
  String get homeWorldTourContinue;

  /// No description provided for @homeRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get homeRandom;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get settingsHaptics;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsReplayTutorial.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorial'**
  String get settingsReplayTutorial;

  /// No description provided for @settingsRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestorePurchases;

  /// No description provided for @removeAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get removeAds;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @shopSectionItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get shopSectionItems;

  /// No description provided for @shopSectionAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get shopSectionAds;

  /// No description provided for @shopWatchAdForHint.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad for +1 hint'**
  String get shopWatchAdForHint;

  /// No description provided for @adPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing…'**
  String get adPlaying;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @hintsBundle.
  ///
  /// In en, this message translates to:
  /// **'{count} hints'**
  String hintsBundle(int count);

  /// No description provided for @removesBundle.
  ///
  /// In en, this message translates to:
  /// **'{count} removes'**
  String removesBundle(int count);

  /// No description provided for @inventoryHints.
  ///
  /// In en, this message translates to:
  /// **'Hints'**
  String get inventoryHints;

  /// No description provided for @inventoryRemoves.
  ///
  /// In en, this message translates to:
  /// **'Removes'**
  String get inventoryRemoves;

  /// No description provided for @toastHintGranted1.
  ///
  /// In en, this message translates to:
  /// **'You got 1 hint.'**
  String get toastHintGranted1;

  /// No description provided for @toastNoAdAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now. Please try again in a moment.'**
  String get toastNoAdAvailable;

  /// No description provided for @iapPurchaseStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase.'**
  String get iapPurchaseStartFailed;

  /// No description provided for @iapRestoreUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Restoring isn\'t supported on this device.'**
  String get iapRestoreUnsupported;

  /// No description provided for @iapRestoreChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked your purchases.'**
  String get iapRestoreChecked;

  /// No description provided for @iapRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed.'**
  String get iapRestoreFailed;

  /// No description provided for @iapPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the purchase.'**
  String get iapPurchaseFailed;

  /// No description provided for @iapHintsGranted.
  ///
  /// In en, this message translates to:
  /// **'You got {count} hints.'**
  String iapHintsGranted(int count);

  /// No description provided for @iapRemovesGranted.
  ///
  /// In en, this message translates to:
  /// **'You got {count} removes.'**
  String iapRemovesGranted(int count);

  /// No description provided for @iapAdsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Ads removed.'**
  String get iapAdsRemoved;

  /// No description provided for @adPlaceholderMrec.
  ///
  /// In en, this message translates to:
  /// **'MREC banner ad'**
  String get adPlaceholderMrec;

  /// No description provided for @onboardingEscapeTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap an arrow'**
  String get onboardingEscapeTitle;

  /// No description provided for @onboardingEscapeBody.
  ///
  /// In en, this message translates to:
  /// **'A tapped arrow slides off the board in the direction its head points.'**
  String get onboardingEscapeBody;

  /// No description provided for @onboardingBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked ahead? It bumps'**
  String get onboardingBlockedTitle;

  /// No description provided for @onboardingBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'If an arrow is in the way it bounces back and you lose a heart. Order is everything.'**
  String get onboardingBlockedBody;

  /// No description provided for @onboardingClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the board to win'**
  String get onboardingClearTitle;

  /// No description provided for @onboardingClearBody.
  ///
  /// In en, this message translates to:
  /// **'Send every arrow out to finish the stage, then follow the world map to the next country.'**
  String get onboardingClearBody;

  /// No description provided for @onboardingItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Two items can help'**
  String get onboardingItemsTitle;

  /// No description provided for @onboardingItemHintDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows an arrow you can free right now — it blinks blue.'**
  String get onboardingItemHintDesc;

  /// No description provided for @onboardingItemRemoveDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap it, then tap any arrow to clear it out of the way.'**
  String get onboardingItemRemoveDesc;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start playing'**
  String get onboardingStart;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @mapLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the map.'**
  String get mapLoadError;

  /// No description provided for @areaUnderOne.
  ///
  /// In en, this message translates to:
  /// **'Under 1 ㎢'**
  String get areaUnderOne;

  /// No description provided for @gameRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart?'**
  String get gameRestartTitle;

  /// No description provided for @gameRestartBody.
  ///
  /// In en, this message translates to:
  /// **'Every arrow you\'ve cleared so far goes back to its starting position.'**
  String get gameRestartBody;

  /// No description provided for @gameRestartConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get gameRestartConfirm;

  /// No description provided for @gameLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the game?'**
  String get gameLeaveTitle;

  /// No description provided for @gameLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your current board won\'t be saved.'**
  String get gameLeaveBody;

  /// No description provided for @gameLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get gameLeaveConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @coachTapArrow.
  ///
  /// In en, this message translates to:
  /// **'Try tapping a glowing arrow'**
  String get coachTapArrow;

  /// No description provided for @coachPinchZoom.
  ///
  /// In en, this message translates to:
  /// **'Pinch with two fingers to zoom'**
  String get coachPinchZoom;

  /// No description provided for @coachHintBubble.
  ///
  /// In en, this message translates to:
  /// **'We\'ll find an arrow you can free.'**
  String get coachHintBubble;

  /// No description provided for @coachRemoveBubble.
  ///
  /// In en, this message translates to:
  /// **'Tap the arrow to remove.'**
  String get coachRemoveBubble;

  /// No description provided for @barFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get barFit;

  /// No description provided for @barHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get barHint;

  /// No description provided for @barRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get barRemove;

  /// No description provided for @barRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get barRestart;

  /// No description provided for @heartsOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of hearts'**
  String get heartsOutTitle;

  /// No description provided for @heartsOutFree.
  ///
  /// In en, this message translates to:
  /// **'Keep playing.'**
  String get heartsOutFree;

  /// No description provided for @heartsOutAd.
  ///
  /// In en, this message translates to:
  /// **'Watch one ad to refill your hearts.'**
  String get heartsOutAd;

  /// No description provided for @refillCoupon.
  ///
  /// In en, this message translates to:
  /// **'Refill coupon ({count})'**
  String refillCoupon(int count);

  /// No description provided for @refillViaAd.
  ///
  /// In en, this message translates to:
  /// **'Watch ad to refill'**
  String get refillViaAd;

  /// No description provided for @itemSheetNoHints.
  ///
  /// In en, this message translates to:
  /// **'No hints left'**
  String get itemSheetNoHints;

  /// No description provided for @itemSheetNoRemoves.
  ///
  /// In en, this message translates to:
  /// **'No removes left'**
  String get itemSheetNoRemoves;

  /// No description provided for @itemSheetRefill.
  ///
  /// In en, this message translates to:
  /// **'Top up and keep solving.'**
  String get itemSheetRefill;

  /// No description provided for @clearContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get clearContinue;

  /// No description provided for @roundBadge.
  ///
  /// In en, this message translates to:
  /// **'ROUND {round}'**
  String roundBadge(String round);

  /// No description provided for @roundTeaches.
  ///
  /// In en, this message translates to:
  /// **'What you\'ll learn this round — {topic}'**
  String roundTeaches(String topic);

  /// No description provided for @roundCitiesIntro.
  ///
  /// In en, this message translates to:
  /// **'Travel through {count} cities of {country}, then solve the whole country at the end.'**
  String roundCitiesIntro(String country, int count);

  /// No description provided for @roundSingleIntro.
  ///
  /// In en, this message translates to:
  /// **'Solve the whole territory of {country} in a single board.'**
  String roundSingleIntro(String country);

  /// No description provided for @roundStatStages.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get roundStatStages;

  /// No description provided for @roundStatCities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get roundStatCities;

  /// No description provided for @roundStatCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get roundStatCountry;

  /// No description provided for @roundStart.
  ///
  /// In en, this message translates to:
  /// **'Start round'**
  String get roundStart;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
