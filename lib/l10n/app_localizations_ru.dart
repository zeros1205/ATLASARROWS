// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get tabHome => 'Главная';

  @override
  String get tabMap => 'Карта';

  @override
  String get tabShop => 'Магазин';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get homeWorldTour => 'Кругосветка';

  @override
  String get homeWorldTourContinue => 'Продолжить кругосветку';

  @override
  String get homeRandom => 'Случайный';

  @override
  String get settingsDarkMode => 'Тёмная тема';

  @override
  String get settingsSound => 'Звук';

  @override
  String get settingsHaptics => 'Вибрация';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsReplayTutorial => 'Пройти обучение заново';

  @override
  String get settingsRestorePurchases => 'Восстановить покупки';

  @override
  String get removeAds => 'Убрать рекламу';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get owned => 'Куплено';

  @override
  String get shopSectionItems => 'Предметы';

  @override
  String get shopSectionAds => 'Реклама';

  @override
  String get shopWatchAdForHint => 'Смотреть рекламу за +1 подсказку';

  @override
  String get adPlaying => 'Идёт показ…';

  @override
  String get free => 'Бесплатно';

  @override
  String hintsBundle(int count) {
    return '$count подсказок';
  }

  @override
  String removesBundle(int count) {
    return '$count удалений';
  }

  @override
  String get inventoryHints => 'Подсказки';

  @override
  String get inventoryRemoves => 'Удаления';

  @override
  String get toastHintGranted1 => 'Вы получили 1 подсказку.';

  @override
  String get toastNoAdAvailable =>
      'Сейчас нет доступной рекламы. Попробуйте чуть позже.';

  @override
  String get iapPurchaseStartFailed => 'Не удалось начать покупку.';

  @override
  String get iapRestoreUnsupported =>
      'Восстановление не поддерживается на этом устройстве.';

  @override
  String get iapRestoreChecked => 'Ваши покупки проверены.';

  @override
  String get iapRestoreFailed => 'Не удалось восстановить покупки.';

  @override
  String get iapPurchaseFailed => 'Не удалось завершить покупку.';

  @override
  String iapHintsGranted(int count) {
    return 'Вы получили $count подсказок.';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'Вы получили $count удалений.';
  }

  @override
  String get iapAdsRemoved => 'Реклама отключена.';

  @override
  String get adPlaceholderMrec => 'Баннер MREC';

  @override
  String get onboardingEscapeTitle => 'Нажмите на стрелку';

  @override
  String get onboardingEscapeBody =>
      'Нажатая стрелка соскальзывает с поля в ту сторону, куда указывает её остриё.';

  @override
  String get onboardingBlockedTitle => 'Путь занят? Стрелка упрётся';

  @override
  String get onboardingBlockedBody =>
      'Если на пути стоит другая стрелка, она отскочит, и вы потеряете сердце. Порядок решает всё.';

  @override
  String get onboardingClearTitle => 'Очистите поле, чтобы победить';

  @override
  String get onboardingClearBody =>
      'Уберите с поля все стрелки, чтобы пройти этап, а затем двигайтесь по карте мира к следующей стране.';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingStart => 'Начать игру';

  @override
  String get next => 'Далее';

  @override
  String get mapLoadError => 'Не удалось загрузить карту.';

  @override
  String get areaUnderOne => 'Менее 1 ㎢';

  @override
  String get gameRestartTitle => 'Начать заново?';

  @override
  String get gameRestartBody =>
      'Все убранные стрелки вернутся на свои стартовые места.';

  @override
  String get gameRestartConfirm => 'Заново';

  @override
  String get gameLeaveTitle => 'Выйти из игры?';

  @override
  String get gameLeaveBody => 'Текущее поле не будет сохранено.';

  @override
  String get gameLeaveConfirm => 'Выйти';

  @override
  String get cancel => 'Отмена';

  @override
  String get coachTapArrow => 'Нажмите на светящуюся стрелку';

  @override
  String get coachPinchZoom => 'Сведите два пальца, чтобы масштабировать';

  @override
  String get barFit => 'По размеру';

  @override
  String get barHint => 'Подсказка';

  @override
  String get barRemove => 'Удалить';

  @override
  String get barRestart => 'Заново';

  @override
  String get heartsOutTitle => 'Сердца закончились';

  @override
  String get heartsOutFree => 'Продолжайте игру.';

  @override
  String get heartsOutAd => 'Посмотрите одну рекламу, чтобы восполнить сердца.';

  @override
  String refillCoupon(int count) {
    return 'Купон на восполнение ($count)';
  }

  @override
  String get refillViaAd => 'Смотреть рекламу для восполнения';

  @override
  String get itemSheetNoHints => 'Подсказки закончились';

  @override
  String get itemSheetNoRemoves => 'Удаления закончились';

  @override
  String get itemSheetRefill => 'Пополните запас и продолжайте решать.';

  @override
  String get clearContinue => 'Продолжить';

  @override
  String roundBadge(String round) {
    return 'РАУНД $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'Чему вы научитесь в этом раунде — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return 'Пройдите через $count городов страны $country, а в конце соберите всю страну целиком.';
  }

  @override
  String roundSingleIntro(String country) {
    return 'Соберите всю территорию страны $country на одном поле.';
  }

  @override
  String get roundStatStages => 'Этапы';

  @override
  String get roundStatCities => 'Города';

  @override
  String get roundStatCountry => 'Страна';

  @override
  String get roundStart => 'Начать раунд';
}
