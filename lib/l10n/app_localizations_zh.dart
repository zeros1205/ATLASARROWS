// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tabHome => '首页';

  @override
  String get tabMap => '地图';

  @override
  String get tabShop => '商店';

  @override
  String get tabSettings => '设置';

  @override
  String get homeWorldTour => '环球之旅';

  @override
  String get homeWorldTourContinue => '继续环球之旅';

  @override
  String get homeRandom => '随机模式';

  @override
  String get settingsDarkMode => '深色模式';

  @override
  String get settingsSound => '音效';

  @override
  String get settingsHaptics => '震动';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsReplayTutorial => '重看教程';

  @override
  String get settingsRestorePurchases => '恢复购买';

  @override
  String get removeAds => '去除广告';

  @override
  String get comingSoon => '敬请期待';

  @override
  String get owned => '已拥有';

  @override
  String get shopSectionItems => '道具';

  @override
  String get shopSectionAds => '广告';

  @override
  String get shopWatchAdForHint => '看广告 +1 提示';

  @override
  String get adPlaying => '播放中…';

  @override
  String get free => '免费';

  @override
  String hintsBundle(int count) {
    return '$count 个提示';
  }

  @override
  String removesBundle(int count) {
    return '$count 个移除';
  }

  @override
  String get inventoryHints => '提示';

  @override
  String get inventoryRemoves => '移除';

  @override
  String get toastHintGranted1 => '获得 1 个提示。';

  @override
  String get toastNoAdAvailable => '暂时没有可看的广告，请稍后再试。';

  @override
  String get iapPurchaseStartFailed => '无法开始购买。';

  @override
  String get iapRestoreUnsupported => '此设备不支持恢复购买。';

  @override
  String get iapRestoreChecked => '已检查你的购买记录。';

  @override
  String get iapRestoreFailed => '恢复失败。';

  @override
  String get iapPurchaseFailed => '购买未能完成。';

  @override
  String iapHintsGranted(int count) {
    return '获得 $count 个提示。';
  }

  @override
  String iapRemovesGranted(int count) {
    return '获得 $count 个移除。';
  }

  @override
  String get iapAdsRemoved => '已去除广告。';

  @override
  String get adPlaceholderMrec => 'MREC 横幅广告';

  @override
  String get onboardingEscapeTitle => '点击箭头';

  @override
  String get onboardingEscapeBody => '点击箭头后，它会朝箭头所指方向滑出棋盘。';

  @override
  String get onboardingBlockedTitle => '前方受阻？会被弹回';

  @override
  String get onboardingBlockedBody => '如果有箭头挡路，它会被弹回，你也会失去一颗爱心。顺序至关重要。';

  @override
  String get onboardingClearTitle => '清空棋盘即获胜';

  @override
  String get onboardingClearBody => '把所有箭头都送出棋盘即可通关，然后沿世界地图前往下一个国家。';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingStart => '开始游戏';

  @override
  String get next => '下一步';

  @override
  String get mapLoadError => '无法加载地图。';

  @override
  String get areaUnderOne => '不足 1 ㎢';

  @override
  String get gameRestartTitle => '重新开始？';

  @override
  String get gameRestartBody => '你目前清除的所有箭头都会回到起始位置。';

  @override
  String get gameRestartConfirm => '重新开始';

  @override
  String get gameLeaveTitle => '离开游戏？';

  @override
  String get gameLeaveBody => '当前棋盘不会被保存。';

  @override
  String get gameLeaveConfirm => '离开';

  @override
  String get cancel => '取消';

  @override
  String get coachTapArrow => '试着点一下发光的箭头';

  @override
  String get coachPinchZoom => '用两根手指捏合来缩放';

  @override
  String get barFit => '适应视图';

  @override
  String get barHint => '提示';

  @override
  String get barRemove => '移除';

  @override
  String get barRestart => '重新开始';

  @override
  String get heartsOutTitle => '爱心用完了';

  @override
  String get heartsOutFree => '继续游戏。';

  @override
  String get heartsOutAd => '看一个广告即可补满爱心。';

  @override
  String refillCoupon(int count) {
    return '补充券（$count）';
  }

  @override
  String get refillViaAd => '看广告补满';

  @override
  String get itemSheetNoHints => '没有提示了';

  @override
  String get itemSheetNoRemoves => '没有移除了';

  @override
  String get itemSheetRefill => '补充一下，继续解谜。';

  @override
  String get clearContinue => '继续';

  @override
  String roundBadge(String round) {
    return '第 $round 关';
  }

  @override
  String roundTeaches(String topic) {
    return '本关你将学到 —— $topic';
  }

  @override
  String roundCitiesIntro(String country, int count) {
    return '畅游 $country 的 $count 座城市，最后再挑战整个国家。';
  }

  @override
  String roundSingleIntro(String country) {
    return '在一张棋盘上解开 $country 的完整领土。';
  }

  @override
  String get roundStatStages => '关卡';

  @override
  String get roundStatCities => '城市';

  @override
  String get roundStatCountry => '国家';

  @override
  String get roundStart => '开始本关';
}
