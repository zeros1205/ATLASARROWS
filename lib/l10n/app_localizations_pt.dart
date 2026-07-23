// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabHome => 'Início';

  @override
  String get tabMap => 'Mapa';

  @override
  String get tabShop => 'Loja';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get homeWorldTour => 'Volta ao Mundo';

  @override
  String get homeWorldTourContinue => 'Continuar Volta ao Mundo';

  @override
  String get homeRandom => 'Aleatório';

  @override
  String get settingsDarkMode => 'Modo escuro';

  @override
  String get settingsSound => 'Som';

  @override
  String get settingsHaptics => 'Vibração';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsReplayTutorial => 'Rever tutorial';

  @override
  String get settingsRestorePurchases => 'Restaurar compras';

  @override
  String get removeAds => 'Remover anúncios';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get owned => 'Adquirido';

  @override
  String get shopSectionItems => 'Itens';

  @override
  String get shopSectionAds => 'Anúncios';

  @override
  String get shopWatchAdForHint => 'Assista a um anúncio para +1 dica';

  @override
  String get adPlaying => 'Reproduzindo…';

  @override
  String get free => 'Grátis';

  @override
  String hintsBundle(int count) {
    return '$count dicas';
  }

  @override
  String removesBundle(int count) {
    return '$count remoções';
  }

  @override
  String get inventoryHints => 'Dicas';

  @override
  String get inventoryRemoves => 'Remoções';

  @override
  String get toastHintGranted1 => 'Você ganhou 1 dica.';

  @override
  String get toastNoAdAvailable =>
      'Nenhum anúncio disponível agora. Tente novamente em instantes.';

  @override
  String get iapPurchaseStartFailed => 'Não foi possível iniciar a compra.';

  @override
  String get iapRestoreUnsupported =>
      'A restauração não é compatível com este dispositivo.';

  @override
  String get iapRestoreChecked => 'Suas compras foram verificadas.';

  @override
  String get iapRestoreFailed => 'Falha ao restaurar.';

  @override
  String get iapPurchaseFailed => 'Não foi possível concluir a compra.';

  @override
  String iapHintsGranted(int count) {
    return 'Você ganhou $count dicas.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Você ganhou $count remoções.';
  }

  @override
  String get iapAdsRemoved => 'Anúncios removidos.';

  @override
  String get adPlaceholderMrec => 'Anúncio banner MREC';

  @override
  String get onboardingEscapeTitle => 'Toque em uma seta';

  @override
  String get onboardingEscapeBody =>
      'Ao tocar, a seta desliza para fora do tabuleiro na direção para onde aponta.';

  @override
  String get onboardingBlockedTitle => 'Bloqueada à frente? Ela colide';

  @override
  String get onboardingBlockedBody =>
      'Se houver uma seta no caminho, ela volta e você perde um coração. A ordem é tudo.';

  @override
  String get onboardingClearTitle => 'Limpe o tabuleiro para vencer';

  @override
  String get onboardingClearBody =>
      'Mande todas as setas para fora para concluir a fase e siga o mapa-múndi até o próximo país.';

  @override
  String get onboardingItemsTitle => 'Dois itens para ajudar';

  @override
  String get onboardingItemHintDesc =>
      'Mostra uma seta que você pode liberar agora — ela pisca em azul.';

  @override
  String get onboardingItemRemoveDesc =>
      'Toque nele e depois em uma seta para removê-la.';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingStart => 'Começar a jogar';

  @override
  String get next => 'Avançar';

  @override
  String get mapLoadError => 'Não foi possível carregar o mapa.';

  @override
  String get areaUnderOne => 'Menos de 1 ㎢';

  @override
  String get gameRestartTitle => 'Reiniciar?';

  @override
  String get gameRestartBody =>
      'Todas as setas que você já limpou voltam para a posição inicial.';

  @override
  String get gameRestartConfirm => 'Reiniciar';

  @override
  String get gameLeaveTitle => 'Sair do jogo?';

  @override
  String get gameLeaveBody => 'O tabuleiro atual não será salvo.';

  @override
  String get gameLeaveConfirm => 'Sair';

  @override
  String get cancel => 'Cancelar';

  @override
  String get coachTapArrow => 'Tente tocar em uma seta brilhante';

  @override
  String get coachPinchZoom => 'Use dois dedos para dar zoom';

  @override
  String get coachHintBubble => 'Encontramos uma seta que dá para liberar.';

  @override
  String get coachRemoveBubble => 'Toque na seta para remover.';

  @override
  String get barFit => 'Ajustar';

  @override
  String get barHint => 'Dica';

  @override
  String get barRemove => 'Remover';

  @override
  String get barRestart => 'Reiniciar';

  @override
  String get heartsOutTitle => 'Sem corações';

  @override
  String get heartsOutFree => 'Continue jogando.';

  @override
  String get heartsOutAd =>
      'Assista a um anúncio para recarregar seus corações.';

  @override
  String refillCoupon(int count) {
    return 'Cupom de recarga ($count)';
  }

  @override
  String get refillViaAd => 'Assistir anúncio para recarregar';

  @override
  String get itemSheetNoHints => 'Nenhuma dica restante';

  @override
  String get itemSheetNoRemoves => 'Nenhuma remoção restante';

  @override
  String get itemSheetRefill => 'Recarregue e continue resolvendo.';

  @override
  String get clearContinue => 'Continuar';

  @override
  String roundBadge(String round) {
    return 'RODADA $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'O que você vai aprender nesta rodada — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Viaje por $count cidades de $country e resolva o país inteiro no final.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Resolva todo o território de $country em um único tabuleiro.';
  }

  @override
  String get roundStatStages => 'Fases';

  @override
  String get roundStatCities => 'Cidades';

  @override
  String get roundStatCountry => 'País';

  @override
  String get roundStart => 'Iniciar rodada';
}
