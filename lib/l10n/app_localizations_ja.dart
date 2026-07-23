// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get tabHome => 'ホーム';

  @override
  String get tabMap => 'マップ';

  @override
  String get tabShop => 'ショップ';

  @override
  String get tabSettings => '設定';

  @override
  String get homeWorldTour => 'ワールドツアー';

  @override
  String get homeWorldTourContinue => 'ワールドツアーを続ける';

  @override
  String get homeRandom => 'ランダム';

  @override
  String get settingsDarkMode => 'ダークモード';

  @override
  String get settingsSound => 'サウンド';

  @override
  String get settingsHaptics => 'バイブレーション';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsReplayTutorial => 'チュートリアルをもう一度見る';

  @override
  String get settingsRestorePurchases => '購入を復元';

  @override
  String get removeAds => '広告を非表示';

  @override
  String get comingSoon => '近日公開';

  @override
  String get owned => '所持済み';

  @override
  String get shopSectionItems => 'アイテム';

  @override
  String get shopSectionAds => '広告';

  @override
  String get shopWatchAdForHint => '広告を見てヒント+1';

  @override
  String get adPlaying => '再生中…';

  @override
  String get free => '無料';

  @override
  String hintsBundle(int count) {
    return 'ヒント$count個';
  }

  @override
  String removesBundle(int count) {
    return 'リムーブ$count個';
  }

  @override
  String get inventoryHints => 'ヒント';

  @override
  String get inventoryRemoves => 'リムーブ';

  @override
  String get toastHintGranted1 => 'ヒントを1個手に入れました。';

  @override
  String get toastNoAdAvailable => '現在ご利用できる広告がありません。しばらくしてからもう一度お試しください。';

  @override
  String get iapPurchaseStartFailed => '購入を開始できませんでした。';

  @override
  String get iapRestoreUnsupported => 'このデバイスでは復元がサポートされていません。';

  @override
  String get iapRestoreChecked => '購入内容を確認しました。';

  @override
  String get iapRestoreFailed => '復元に失敗しました。';

  @override
  String get iapPurchaseFailed => '購入を完了できませんでした。';

  @override
  String iapHintsGranted(int count) {
    return 'ヒント$count個を手に入れました。';
  }

  @override
  String iapRemovesGranted(int count) {
    return 'リムーブ$count個を手に入れました。';
  }

  @override
  String get iapAdsRemoved => '広告を非表示にしました。';

  @override
  String get adPlaceholderMrec => 'MRECバナー広告';

  @override
  String get onboardingEscapeTitle => '矢印をタップ';

  @override
  String get onboardingEscapeBody => 'タップした矢印は、向いている方向へボードの外へすべり出ます。';

  @override
  String get onboardingBlockedTitle => '前が詰まると跳ね返る';

  @override
  String get onboardingBlockedBody => '進む先に矢印があると跳ね返され、ハートを1つ失います。順番がすべてです。';

  @override
  String get onboardingClearTitle => 'ボードを空にしてクリア';

  @override
  String get onboardingClearBody =>
      'すべての矢印を送り出してステージをクリアし、ワールドマップをたどって次の国へ進みましょう。';

  @override
  String get onboardingItemsTitle => '2つのアイテムが助けてくれる';

  @override
  String get onboardingItemHintDesc => '今すぐ出せる矢印を青く点滅させて教えます。';

  @override
  String get onboardingItemRemoveDesc => 'タップしてから矢印をタップすると、その矢印を消せます。';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingStart => 'プレイ開始';

  @override
  String get next => '次へ';

  @override
  String get mapLoadError => 'マップを読み込めませんでした。';

  @override
  String get areaUnderOne => '1 ㎢未満';

  @override
  String get gameRestartTitle => 'やり直しますか？';

  @override
  String get gameRestartBody => 'これまでに送り出した矢印がすべて元の位置に戻ります。';

  @override
  String get gameRestartConfirm => 'やり直す';

  @override
  String get gameLeaveTitle => 'ゲームを終了しますか？';

  @override
  String get gameLeaveBody => '現在のボードは保存されません。';

  @override
  String get gameLeaveConfirm => '終了';

  @override
  String get cancel => 'キャンセル';

  @override
  String get coachTapArrow => '光っている矢印をタップしてみよう';

  @override
  String get coachPinchZoom => '2本指でつまんでズーム';

  @override
  String get barFit => '全体表示';

  @override
  String get barHint => 'ヒント';

  @override
  String get barRemove => 'リムーブ';

  @override
  String get barRestart => 'やり直す';

  @override
  String get heartsOutTitle => 'ハートがなくなりました';

  @override
  String get heartsOutFree => 'プレイを続けましょう。';

  @override
  String get heartsOutAd => '広告を1本見てハートを回復しましょう。';

  @override
  String refillCoupon(int count) {
    return '回復クーポン（$count）';
  }

  @override
  String get refillViaAd => '広告を見て回復';

  @override
  String get itemSheetNoHints => 'ヒントがありません';

  @override
  String get itemSheetNoRemoves => 'リムーブがありません';

  @override
  String get itemSheetRefill => '補充して解き続けましょう。';

  @override
  String get clearContinue => '続ける';

  @override
  String roundBadge(String round) {
    return 'ラウンド $round';
  }

  @override
  String roundTeaches(String topic) {
    return 'このラウンドで学べること — $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return '$countryの$count都市を巡り、最後に国全体を解きましょう。';
  }

  @override
  String roundSingleIntro(String country) {
    return '$countryの全領土を1つのボードで解きましょう。';
  }

  @override
  String get roundStatStages => 'ステージ';

  @override
  String get roundStatCities => '都市';

  @override
  String get roundStatCountry => '国';

  @override
  String get roundStart => 'ラウンド開始';
}
