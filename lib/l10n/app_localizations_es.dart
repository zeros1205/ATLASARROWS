// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabMap => 'Mapa';

  @override
  String get tabShop => 'Tienda';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get homeWorldTour => 'Vuelta al mundo';

  @override
  String get homeWorldTourContinue => 'Continuar vuelta al mundo';

  @override
  String get homeRandom => 'Aleatorio';

  @override
  String get settingsDarkMode => 'Modo oscuro';

  @override
  String get settingsSound => 'Sonido';

  @override
  String get settingsHaptics => 'Vibración';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsReplayTutorial => 'Repetir tutorial';

  @override
  String get settingsRestorePurchases => 'Restaurar compras';

  @override
  String get removeAds => 'Quitar anuncios';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get owned => 'Adquirido';

  @override
  String get shopSectionItems => 'Objetos';

  @override
  String get shopSectionAds => 'Anuncios';

  @override
  String get shopWatchAdForHint => 'Mira un anuncio por +1 pista';

  @override
  String get adPlaying => 'Reproduciendo…';

  @override
  String get free => 'Gratis';

  @override
  String hintsBundle(int count) {
    return '$count pistas';
  }

  @override
  String removesBundle(int count) {
    return '$count eliminaciones';
  }

  @override
  String get inventoryHints => 'Pistas';

  @override
  String get inventoryRemoves => 'Eliminaciones';

  @override
  String get toastHintGranted1 => 'Conseguiste 1 pista.';

  @override
  String get toastNoAdAvailable =>
      'No hay anuncios disponibles ahora mismo. Inténtalo de nuevo en un momento.';

  @override
  String get iapPurchaseStartFailed => 'No se pudo iniciar la compra.';

  @override
  String get iapRestoreUnsupported =>
      'La restauración no es compatible con este dispositivo.';

  @override
  String get iapRestoreChecked => 'Comprobamos tus compras.';

  @override
  String get iapRestoreFailed => 'No se pudo restaurar.';

  @override
  String get iapPurchaseFailed => 'No se pudo completar la compra.';

  @override
  String iapHintsGranted(int count) {
    return 'Conseguiste $count pistas.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Conseguiste $count eliminaciones.';
  }

  @override
  String get iapAdsRemoved => 'Anuncios eliminados.';

  @override
  String get adPlaceholderMrec => 'Anuncio banner MREC';

  @override
  String get onboardingEscapeTitle => 'Toca una flecha';

  @override
  String get onboardingEscapeBody =>
      'La flecha que tocas se desliza fuera del tablero en la dirección a la que apunta su punta.';

  @override
  String get onboardingBlockedTitle => '¿Bloqueada delante? Rebota';

  @override
  String get onboardingBlockedBody =>
      'Si otra flecha se interpone, rebota y pierdes un corazón. El orden lo es todo.';

  @override
  String get onboardingClearTitle => 'Despeja el tablero para ganar';

  @override
  String get onboardingClearBody =>
      'Saca todas las flechas para completar la fase y luego sigue el mapa del mundo hasta el próximo país.';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingStart => 'Empezar a jugar';

  @override
  String get next => 'Siguiente';

  @override
  String get mapLoadError => 'No se pudo cargar el mapa.';

  @override
  String get areaUnderOne => 'Menos de 1 ㎢';

  @override
  String get gameRestartTitle => '¿Reiniciar?';

  @override
  String get gameRestartBody =>
      'Todas las flechas que has sacado hasta ahora vuelven a su posición inicial.';

  @override
  String get gameRestartConfirm => 'Reiniciar';

  @override
  String get gameLeaveTitle => '¿Salir del juego?';

  @override
  String get gameLeaveBody => 'Tu tablero actual no se guardará.';

  @override
  String get gameLeaveConfirm => 'Salir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get coachTapArrow => 'Prueba a tocar una flecha brillante';

  @override
  String get coachPinchZoom => 'Pellizca con dos dedos para ampliar';

  @override
  String get barFit => 'Ajustar';

  @override
  String get barHint => 'Pista';

  @override
  String get barRemove => 'Eliminar';

  @override
  String get barRestart => 'Reiniciar';

  @override
  String get heartsOutTitle => 'Sin corazones';

  @override
  String get heartsOutFree => 'Sigue jugando.';

  @override
  String get heartsOutAd => 'Mira un anuncio para recargar tus corazones.';

  @override
  String refillCoupon(int count) {
    return 'Cupón de recarga ($count)';
  }

  @override
  String get refillViaAd => 'Mira un anuncio para recargar';

  @override
  String get itemSheetNoHints => 'No te quedan pistas';

  @override
  String get itemSheetNoRemoves => 'No te quedan eliminaciones';

  @override
  String get itemSheetRefill => 'Recarga y sigue resolviendo.';

  @override
  String get clearContinue => 'Continuar';

  @override
  String roundBadge(String round) {
    return 'RONDA $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'Lo que aprenderás en esta ronda: $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Recorre $count ciudades de $country y al final resuelve todo el país.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Resuelve todo el territorio de $country en un solo tablero.';
  }

  @override
  String get roundStatStages => 'Fases';

  @override
  String get roundStatCities => 'Ciudades';

  @override
  String get roundStatCountry => 'País';

  @override
  String get roundStart => 'Empezar ronda';
}
