import 'package:flutter/material.dart';

/// LOGAN LAND 퍼블리셔 브랜드 상수. **앱별로 바꾸지 않는다.**
/// 바꾸는 순간 퍼블리셔 아이덴티티가 앱마다 갈라진다.
class LoganLand {
  const LoganLand._();

  /// 퍼블리셔 표기명.
  static const String publisher = 'LOGAN LAND';

  /// 네이티브 스플래시 = 퍼블리셔 카드 배경. 순수 검정이 아닌 오프블랙 —
  /// OS 스플래시와 Flutter 첫 프레임이 같은 값이어야 이음매가 없다.
  static const Color offBlack = Color(0xFF0D0D0D);

  /// LL 모노그램(아이소메트릭 큐브에서 각 면의 1사분면을 덜어 "L"을 남긴 형태).
  static const String markAsset = 'assets/brand/logan_mark.png';
  static const String markPackage = 'loganland_boot';

  /// 워드마크 서체.
  static const String fontFamily = 'Paperlogy';
  static const String fontPackage = 'loganland_boot';

  /// 퍼블리셔 카드 페이드인 / 최소 노출.
  static const Duration cardFadeIn = Duration(milliseconds: 520);
  static const Duration cardMinDuration = Duration(milliseconds: 1600);

  /// 퍼블리셔 카드 → 로딩 크로스페이드.
  static const Duration handoffDuration = Duration(milliseconds: 350);
}
