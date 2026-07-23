// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get tabHome => '홈';

  @override
  String get tabMap => '맵';

  @override
  String get tabShop => '상점';

  @override
  String get tabSettings => '설정';

  @override
  String get homeWorldTour => '월드 투어';

  @override
  String get homeWorldTourContinue => '월드 투어 계속하기';

  @override
  String get homeRandom => '랜덤 플레이';

  @override
  String get settingsDarkMode => '다크 모드';

  @override
  String get settingsSound => '소리';

  @override
  String get settingsHaptics => '진동';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsReplayTutorial => '튜토리얼 다시 보기';

  @override
  String get settingsRestorePurchases => '구매 복원';

  @override
  String get removeAds => '광고 제거';

  @override
  String get comingSoon => '준비중';

  @override
  String get owned => '보유 중';

  @override
  String get shopSectionItems => '아이템';

  @override
  String get shopSectionAds => '광고';

  @override
  String get shopWatchAdForHint => '광고 보고 힌트 +1';

  @override
  String get adPlaying => '재생 중…';

  @override
  String get free => '무료';

  @override
  String hintsBundle(int count) {
    return '힌트 $count개';
  }

  @override
  String removesBundle(int count) {
    return '제거 $count개';
  }

  @override
  String get inventoryHints => '힌트';

  @override
  String get inventoryRemoves => '제거';

  @override
  String get toastHintGranted1 => '힌트 1개를 받았어요.';

  @override
  String get toastNoAdAvailable => '지금은 볼 수 있는 광고가 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get iapPurchaseStartFailed => '구매를 시작하지 못했어요.';

  @override
  String get iapRestoreUnsupported => '이 기기에서는 복원을 지원하지 않아요.';

  @override
  String get iapRestoreChecked => '구매 내역을 확인했어요.';

  @override
  String get iapRestoreFailed => '복원에 실패했어요.';

  @override
  String get iapPurchaseFailed => '구매를 완료하지 못했어요.';

  @override
  String iapHintsGranted(int count) {
    return '힌트 $count개를 받았어요.';
  }

  @override
  String iapRemovesGranted(int count) {
    return '제거 $count개를 받았어요.';
  }

  @override
  String get iapAdsRemoved => '광고가 제거되었어요.';

  @override
  String get adPlaceholderMrec => '중간 배너 광고';

  @override
  String get onboardingEscapeTitle => '화살표를 탭하세요';

  @override
  String get onboardingEscapeBody => '탭한 화살표는 머리가 향한 방향으로 미끄러져 보드를 빠져나갑니다.';

  @override
  String get onboardingBlockedTitle => '앞이 막히면 부딪힙니다';

  @override
  String get onboardingBlockedBody =>
      '길을 막는 화살표가 있으면 튕겨 나오고 하트를 하나 잃어요. 순서가 곧 실력입니다.';

  @override
  String get onboardingClearTitle => '보드를 비우면 클리어';

  @override
  String get onboardingClearBody =>
      '모든 화살표를 내보내면 스테이지 완료. 세계지도를 따라 다음 나라로 나아가세요.';

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingStart => '플레이 시작';

  @override
  String get next => '다음';

  @override
  String get mapLoadError => '지도를 불러올 수 없습니다.';

  @override
  String get areaUnderOne => '1㎢ 미만';

  @override
  String get gameRestartTitle => '다시 시작할까요?';

  @override
  String get gameRestartBody => '지금까지 뺀 화살표가 모두 처음 상태로 돌아갑니다.';

  @override
  String get gameRestartConfirm => '다시 시작';

  @override
  String get gameLeaveTitle => '게임을 나갈까요?';

  @override
  String get gameLeaveBody => '지금 풀던 판은 저장되지 않아요.';

  @override
  String get gameLeaveConfirm => '나가기';

  @override
  String get cancel => '취소';

  @override
  String get coachTapArrow => '빛나는 화살표를 탭해 보세요';

  @override
  String get coachPinchZoom => '두 손가락으로 확대해 보세요';

  @override
  String get barFit => '화면맞춤';

  @override
  String get barHint => '힌트';

  @override
  String get barRemove => '제거';

  @override
  String get barRestart => '재시작';

  @override
  String get heartsOutTitle => '하트 소진';

  @override
  String get heartsOutFree => '계속 플레이 하세요.';

  @override
  String get heartsOutAd => '광고 한 편 보면 하트가 가득 차요.';

  @override
  String refillCoupon(int count) {
    return '리필쿠폰($count)';
  }

  @override
  String get refillViaAd => '광고 보고 충전';

  @override
  String get itemSheetNoHints => '힌트가 없어요';

  @override
  String get itemSheetNoRemoves => '제거가 없어요';

  @override
  String get itemSheetRefill => '채우고 이어서 풀 수 있어요.';

  @override
  String get clearContinue => '계속하기';

  @override
  String roundBadge(String round) {
    return 'ROUND $round';
  }

  @override
  String roundTeaches(String topic) {
    return '이번 라운드에서 배울 것 — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return '$country의 도시 $count곳을 지나 마지막에 나라 전체를 풀어냅니다.';
  }

  @override
  String roundSingleIntro(String country) {
    return '$country의 영토를 한 판으로 풀어냅니다.';
  }

  @override
  String get roundStatStages => '스테이지';

  @override
  String get roundStatCities => '도시';

  @override
  String get roundStatCountry => '국가';

  @override
  String get roundStart => '라운드 시작';
}
