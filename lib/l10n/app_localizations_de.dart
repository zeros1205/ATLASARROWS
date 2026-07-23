// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tabHome => 'Start';

  @override
  String get tabMap => 'Karte';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabSettings => 'Einstellungen';

  @override
  String get homeWorldTour => 'Weltreise';

  @override
  String get homeWorldTourContinue => 'Weltreise fortsetzen';

  @override
  String get homeRandom => 'Zufall';

  @override
  String get settingsDarkMode => 'Dunkelmodus';

  @override
  String get settingsSound => 'Ton';

  @override
  String get settingsHaptics => 'Vibration';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsReplayTutorial => 'Tutorial erneut ansehen';

  @override
  String get settingsRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get removeAds => 'Werbung entfernen';

  @override
  String get comingSoon => 'Demnächst';

  @override
  String get owned => 'Im Besitz';

  @override
  String get shopSectionItems => 'Gegenstände';

  @override
  String get shopSectionAds => 'Werbung';

  @override
  String get shopWatchAdForHint => 'Werbung ansehen für +1 Tipp';

  @override
  String get adPlaying => 'Wird abgespielt …';

  @override
  String get free => 'Gratis';

  @override
  String hintsBundle(int count) {
    return '$count Tipps';
  }

  @override
  String removesBundle(int count) {
    return '$count Entferner';
  }

  @override
  String get inventoryHints => 'Tipps';

  @override
  String get inventoryRemoves => 'Entferner';

  @override
  String get toastHintGranted1 => 'Du hast 1 Tipp erhalten.';

  @override
  String get toastNoAdAvailable =>
      'Gerade ist keine Werbung verfügbar. Bitte versuch es gleich noch einmal.';

  @override
  String get iapPurchaseStartFailed => 'Kauf konnte nicht gestartet werden.';

  @override
  String get iapRestoreUnsupported =>
      'Wiederherstellen wird auf diesem Gerät nicht unterstützt.';

  @override
  String get iapRestoreChecked => 'Deine Käufe wurden geprüft.';

  @override
  String get iapRestoreFailed => 'Wiederherstellen fehlgeschlagen.';

  @override
  String get iapPurchaseFailed => 'Kauf konnte nicht abgeschlossen werden.';

  @override
  String iapHintsGranted(int count) {
    return 'Du hast $count Tipps erhalten.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Du hast $count Entferner erhalten.';
  }

  @override
  String get iapAdsRemoved => 'Werbung entfernt.';

  @override
  String get adPlaceholderMrec => 'MREC-Bannerwerbung';

  @override
  String get onboardingEscapeTitle => 'Tippe auf einen Pfeil';

  @override
  String get onboardingEscapeBody =>
      'Ein angetippter Pfeil rutscht in die Richtung vom Brett, in die seine Spitze zeigt.';

  @override
  String get onboardingBlockedTitle => 'Blockiert? Er prallt ab';

  @override
  String get onboardingBlockedBody =>
      'Steht ein Pfeil im Weg, prallt er zurück und du verlierst ein Herz. Die Reihenfolge ist alles.';

  @override
  String get onboardingClearTitle => 'Räum das Brett zum Sieg';

  @override
  String get onboardingClearBody =>
      'Schick jeden Pfeil hinaus, um die Ebene zu schaffen, und folge dann der Weltkarte zum nächsten Land.';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingStart => 'Losspielen';

  @override
  String get next => 'Weiter';

  @override
  String get mapLoadError => 'Karte konnte nicht geladen werden.';

  @override
  String get areaUnderOne => 'Unter 1 ㎢';

  @override
  String get gameRestartTitle => 'Neu starten?';

  @override
  String get gameRestartBody =>
      'Jeder bisher entfernte Pfeil kehrt an seine Startposition zurück.';

  @override
  String get gameRestartConfirm => 'Neu starten';

  @override
  String get gameLeaveTitle => 'Spiel verlassen?';

  @override
  String get gameLeaveBody => 'Dein aktuelles Brett wird nicht gespeichert.';

  @override
  String get gameLeaveConfirm => 'Verlassen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get coachTapArrow => 'Tippe auf einen leuchtenden Pfeil';

  @override
  String get coachPinchZoom => 'Zieh mit zwei Fingern auf, um zu zoomen';

  @override
  String get barFit => 'Anpassen';

  @override
  String get barHint => 'Tipp';

  @override
  String get barRemove => 'Entfernen';

  @override
  String get barRestart => 'Neustart';

  @override
  String get heartsOutTitle => 'Keine Herzen mehr';

  @override
  String get heartsOutFree => 'Spiel weiter.';

  @override
  String get heartsOutAd =>
      'Sieh dir eine Werbung an, um deine Herzen aufzufüllen.';

  @override
  String refillCoupon(int count) {
    return 'Auffüll-Gutschein ($count)';
  }

  @override
  String get refillViaAd => 'Werbung ansehen zum Auffüllen';

  @override
  String get itemSheetNoHints => 'Keine Tipps mehr';

  @override
  String get itemSheetNoRemoves => 'Keine Entferner mehr';

  @override
  String get itemSheetRefill => 'Fülle auf und lös weiter.';

  @override
  String get clearContinue => 'Weiter';

  @override
  String roundBadge(String round) {
    return 'RUNDE $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'Das lernst du in dieser Runde – $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Reise durch $count Städte von $country und lös am Ende das ganze Land.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Lös das gesamte Gebiet von $country auf einem einzigen Brett.';
  }

  @override
  String get roundStatStages => 'Ebenen';

  @override
  String get roundStatCities => 'Städte';

  @override
  String get roundStatCountry => 'Land';

  @override
  String get roundStart => 'Runde starten';
}
