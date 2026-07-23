// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabMap => 'Carte';

  @override
  String get tabShop => 'Boutique';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get homeWorldTour => 'Tour du monde';

  @override
  String get homeWorldTourContinue => 'Continuer le tour du monde';

  @override
  String get homeRandom => 'Aléatoire';

  @override
  String get settingsDarkMode => 'Mode sombre';

  @override
  String get settingsSound => 'Son';

  @override
  String get settingsHaptics => 'Vibration';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsReplayTutorial => 'Revoir le tutoriel';

  @override
  String get settingsRestorePurchases => 'Restaurer les achats';

  @override
  String get removeAds => 'Supprimer les pubs';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get owned => 'Acquis';

  @override
  String get shopSectionItems => 'Objets';

  @override
  String get shopSectionAds => 'Publicités';

  @override
  String get shopWatchAdForHint => 'Regarder une pub pour +1 indice';

  @override
  String get adPlaying => 'Lecture…';

  @override
  String get free => 'Gratuit';

  @override
  String hintsBundle(int count) {
    return '$count indices';
  }

  @override
  String removesBundle(int count) {
    return '$count retraits';
  }

  @override
  String get inventoryHints => 'Indices';

  @override
  String get inventoryRemoves => 'Retraits';

  @override
  String get toastHintGranted1 => 'Vous avez reçu 1 indice.';

  @override
  String get toastNoAdAvailable =>
      'Aucune pub disponible pour le moment. Réessayez dans un instant.';

  @override
  String get iapPurchaseStartFailed => 'Impossible de démarrer l\'achat.';

  @override
  String get iapRestoreUnsupported =>
      'La restauration n\'est pas prise en charge sur cet appareil.';

  @override
  String get iapRestoreChecked => 'Vos achats ont été vérifiés.';

  @override
  String get iapRestoreFailed => 'Échec de la restauration.';

  @override
  String get iapPurchaseFailed => 'Impossible de finaliser l\'achat.';

  @override
  String iapHintsGranted(int count) {
    return 'Vous avez reçu $count indices.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Vous avez reçu $count retraits.';
  }

  @override
  String get iapAdsRemoved => 'Publicités supprimées.';

  @override
  String get adPlaceholderMrec => 'Bannière publicitaire MREC';

  @override
  String get onboardingEscapeTitle => 'Touchez une flèche';

  @override
  String get onboardingEscapeBody =>
      'Une flèche touchée glisse hors du plateau dans la direction qu\'elle pointe.';

  @override
  String get onboardingBlockedTitle => 'Bloquée ? Elle rebondit';

  @override
  String get onboardingBlockedBody =>
      'Si une flèche gêne le passage, elle rebondit et vous perdez un cœur. L\'ordre est essentiel.';

  @override
  String get onboardingClearTitle => 'Videz le plateau pour gagner';

  @override
  String get onboardingClearBody =>
      'Faites sortir toutes les flèches pour terminer le niveau, puis suivez la carte du monde jusqu\'au pays suivant.';

  @override
  String get onboardingItemsTitle => 'Deux objets pour vous aider';

  @override
  String get onboardingItemHintDesc =>
      'Indique une flèche que vous pouvez libérer tout de suite — elle clignote en bleu.';

  @override
  String get onboardingItemRemoveDesc =>
      'Touchez-le, puis touchez une flèche pour la retirer.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingStart => 'Commencer à jouer';

  @override
  String get next => 'Suivant';

  @override
  String get mapLoadError => 'Impossible de charger la carte.';

  @override
  String get areaUnderOne => 'Moins de 1 ㎢';

  @override
  String get gameRestartTitle => 'Recommencer ?';

  @override
  String get gameRestartBody =>
      'Toutes les flèches déjà retirées reviennent à leur position de départ.';

  @override
  String get gameRestartConfirm => 'Recommencer';

  @override
  String get gameLeaveTitle => 'Quitter la partie ?';

  @override
  String get gameLeaveBody => 'Votre plateau actuel ne sera pas sauvegardé.';

  @override
  String get gameLeaveConfirm => 'Quitter';

  @override
  String get cancel => 'Annuler';

  @override
  String get coachTapArrow => 'Essayez de toucher une flèche qui brille';

  @override
  String get coachPinchZoom => 'Pincez avec deux doigts pour zoomer';

  @override
  String get coachHintBubble => 'On vous trouve une flèche à libérer.';

  @override
  String get coachRemoveBubble => 'Touchez la flèche à retirer.';

  @override
  String get barFit => 'Ajuster';

  @override
  String get barHint => 'Indice';

  @override
  String get barRemove => 'Retirer';

  @override
  String get barRestart => 'Recommencer';

  @override
  String get heartsOutTitle => 'Plus de cœurs';

  @override
  String get heartsOutFree => 'Continuez à jouer.';

  @override
  String get heartsOutAd => 'Regardez une pub pour refaire le plein de cœurs.';

  @override
  String refillCoupon(int count) {
    return 'Coupon de recharge ($count)';
  }

  @override
  String get refillViaAd => 'Regarder une pub pour recharger';

  @override
  String get itemSheetNoHints => 'Plus d\'indices';

  @override
  String get itemSheetNoRemoves => 'Plus de retraits';

  @override
  String get itemSheetRefill => 'Rechargez et continuez à résoudre.';

  @override
  String get clearContinue => 'Continuer';

  @override
  String roundBadge(String round) {
    return 'MANCHE $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'Ce que vous allez apprendre cette manche — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Parcourez $count villes de $country, puis résolvez tout le pays à la fin.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Résolvez tout le territoire de $country sur un seul plateau.';
  }

  @override
  String get roundStatStages => 'Niveaux';

  @override
  String get roundStatCities => 'Villes';

  @override
  String get roundStatCountry => 'Pays';

  @override
  String get roundStart => 'Commencer la manche';
}
