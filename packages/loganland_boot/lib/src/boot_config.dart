import 'package:flutter/material.dart';

/// 콜드스타트 로딩 화면(01c)의 앱별 설정.
///
/// 여기 없는 값(퍼블리셔 카드 규격 등)은 `LoganLand` 에 있고 앱이 바꿀 수 없다.
/// 여기 있는 값도 색·치수는 기본값을 쓰는 것이 원칙 — 앱이 반드시 지정해야 하는
/// 것은 사실상 [wordmarkAsset] 과 [captionBuilder] 둘뿐이다.
@immutable
class LoganLandBootConfig {
  const LoganLandBootConfig({
    required this.wordmarkAsset,
    required this.captionBuilder,
    this.wordmarkPackage,
    this.plateColor = kLoadingPlate,
    this.wordmarkWidthFactor = 0.61,
    this.barWidthFactor = 0.62,
    this.captionColor = kLoadingCaptionColor,
    this.captionSize = 16,
    this.captionWeight = FontWeight.w600,
    this.captionGap = 8,
    this.barThickness = 5,
    this.barTrack = kLoadingBarTrack,
    this.barFill = kLoadingBarFill,
    this.bottomInset = 92,
    this.horizontalInset = 36,
    this.loadingMinDuration = const Duration(milliseconds: 1800),
  });

  /// 앱 워드마크(락업) PNG. 로딩 화면과 로그인 화면이 **같은 에셋**을 쓰는 것이
  /// 원칙 — 브랜드가 화면마다 다르게 그려지는 것을 막는다.
  final String wordmarkAsset;
  final String? wordmarkPackage;

  /// 캡션 문구. 진행률(0~100 정수)을 받아 문자열을 돌려준다.
  /// l10n 을 쓰는 앱이면 여기서 번역 문자열을 조립한다.
  /// 예) `(p) => '블록을 불러오는 중 $p%'`
  final String Function(int percent) captionBuilder;

  final Color plateColor;
  final double wordmarkWidthFactor;
  final double barWidthFactor;
  final Color captionColor;
  final double captionSize;
  final FontWeight captionWeight;
  final double captionGap;
  final double barThickness;
  final Color barTrack;
  final Color barFill;
  final double bottomInset;
  final double horizontalInset;

  /// 로딩 화면 최소 노출 — 퍼블리셔 카드가 넘어간 시점부터 계산한다.
  /// 실제 부트 작업과 **오버랩**이므로 느린 기기에 대기가 누적되지 않는다.
  final Duration loadingMinDuration;
}

/// 로딩 플레이트(크림). 다크→크림 전환이 곧 퍼블리셔→앱 경계라서
/// 중립 배경색이 아니라 **브랜드 비트**다.
const Color kLoadingPlate = Color(0xFFE9E2D8);
const Color kLoadingCaptionColor = Color(0xFF57534B);
const Color kLoadingBarTrack = Color(0xFF6E6961);
const Color kLoadingBarFill = Color(0xFF00A19B);

/// 콜드스타트 진행바는 **하나의 0→100% 여정**을 두 위젯 트리가 나눠 그린다.
/// 부트 게이트(pre-Riverpod)가 0→[kBootPhaseCeiling], 앱 진입 후 프리로드가
/// 나머지를 채운다. 두 화면이 같은 스케일을 쓰므로 인수인계에서 바가 0%로
/// 되돌아가는 일이 없다.
const double kBootPhaseCeiling = 0.65;
