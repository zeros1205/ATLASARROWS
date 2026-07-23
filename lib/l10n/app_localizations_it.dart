// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabMap => 'Mappa';

  @override
  String get tabShop => 'Negozio';

  @override
  String get tabSettings => 'Impostazioni';

  @override
  String get homeWorldTour => 'Giro del mondo';

  @override
  String get homeWorldTourContinue => 'Continua il giro del mondo';

  @override
  String get homeRandom => 'Casuale';

  @override
  String get settingsDarkMode => 'Modalità scura';

  @override
  String get settingsSound => 'Audio';

  @override
  String get settingsHaptics => 'Vibrazione';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsReplayTutorial => 'Rivedi il tutorial';

  @override
  String get settingsRestorePurchases => 'Ripristina acquisti';

  @override
  String get removeAds => 'Rimuovi la pubblicità';

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get owned => 'Posseduto';

  @override
  String get shopSectionItems => 'Oggetti';

  @override
  String get shopSectionAds => 'Pubblicità';

  @override
  String get shopWatchAdForHint => 'Guarda una pubblicità per +1 suggerimento';

  @override
  String get adPlaying => 'In riproduzione…';

  @override
  String get free => 'Gratis';

  @override
  String hintsBundle(int count) {
    return '$count suggerimenti';
  }

  @override
  String removesBundle(int count) {
    return '$count rimozioni';
  }

  @override
  String get inventoryHints => 'Suggerimenti';

  @override
  String get inventoryRemoves => 'Rimozioni';

  @override
  String get toastHintGranted1 => 'Hai ottenuto 1 suggerimento.';

  @override
  String get toastNoAdAvailable =>
      'Nessuna pubblicità disponibile al momento. Riprova tra poco.';

  @override
  String get iapPurchaseStartFailed => 'Impossibile avviare l\'acquisto.';

  @override
  String get iapRestoreUnsupported =>
      'Il ripristino non è supportato su questo dispositivo.';

  @override
  String get iapRestoreChecked => 'Acquisti verificati.';

  @override
  String get iapRestoreFailed => 'Ripristino non riuscito.';

  @override
  String get iapPurchaseFailed => 'Impossibile completare l\'acquisto.';

  @override
  String iapHintsGranted(int count) {
    return 'Hai ottenuto $count suggerimenti.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Hai ottenuto $count rimozioni.';
  }

  @override
  String get iapAdsRemoved => 'Pubblicità rimossa.';

  @override
  String get adPlaceholderMrec => 'Banner pubblicitario MREC';

  @override
  String get onboardingEscapeTitle => 'Tocca una freccia';

  @override
  String get onboardingEscapeBody =>
      'La freccia toccata esce dal tabellone nella direzione indicata dalla sua punta.';

  @override
  String get onboardingBlockedTitle => 'Bloccata davanti? Rimbalza';

  @override
  String get onboardingBlockedBody =>
      'Se un\'altra freccia è di ostacolo, rimbalza indietro e perdi un cuore. L\'ordine è tutto.';

  @override
  String get onboardingClearTitle => 'Svuota il tabellone per vincere';

  @override
  String get onboardingClearBody =>
      'Fai uscire tutte le frecce per completare il livello, poi segui la mappa del mondo verso il paese successivo.';

  @override
  String get onboardingSkip => 'Salta';

  @override
  String get onboardingStart => 'Inizia a giocare';

  @override
  String get next => 'Avanti';

  @override
  String get mapLoadError => 'Impossibile caricare la mappa.';

  @override
  String get areaUnderOne => 'Meno di 1 ㎢';

  @override
  String get gameRestartTitle => 'Ricominciare?';

  @override
  String get gameRestartBody =>
      'Tutte le frecce eliminate finora tornano alla posizione di partenza.';

  @override
  String get gameRestartConfirm => 'Ricomincia';

  @override
  String get gameLeaveTitle => 'Uscire dalla partita?';

  @override
  String get gameLeaveBody => 'Il tabellone attuale non verrà salvato.';

  @override
  String get gameLeaveConfirm => 'Esci';

  @override
  String get cancel => 'Annulla';

  @override
  String get coachTapArrow => 'Prova a toccare una freccia luminosa';

  @override
  String get coachPinchZoom => 'Avvicina due dita per ingrandire';

  @override
  String get barFit => 'Adatta vista';

  @override
  String get barHint => 'Suggerimento';

  @override
  String get barRemove => 'Rimuovi';

  @override
  String get barRestart => 'Ricomincia';

  @override
  String get heartsOutTitle => 'Cuori esauriti';

  @override
  String get heartsOutFree => 'Continua a giocare.';

  @override
  String get heartsOutAd => 'Guarda una pubblicità per ricaricare i cuori.';

  @override
  String refillCoupon(int count) {
    return 'Buono ricarica ($count)';
  }

  @override
  String get refillViaAd => 'Guarda la pubblicità per ricaricare';

  @override
  String get itemSheetNoHints => 'Nessun suggerimento rimasto';

  @override
  String get itemSheetNoRemoves => 'Nessuna rimozione rimasta';

  @override
  String get itemSheetRefill => 'Ricarica e continua a risolvere.';

  @override
  String get clearContinue => 'Continua';

  @override
  String roundBadge(String round) {
    return 'ROUND $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'Cosa imparerai in questo round — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Viaggia attraverso $count città di $country, poi risolvi l\'intero paese alla fine.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Risolvi l\'intero territorio di $country in un unico tabellone.';
  }

  @override
  String get roundStatStages => 'Livelli';

  @override
  String get roundStatCities => 'Città';

  @override
  String get roundStatCountry => 'Paese';

  @override
  String get roundStart => 'Inizia il round';
}
