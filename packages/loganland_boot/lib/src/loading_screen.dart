import 'package:flutter/material.dart';

import 'boot_config.dart';

/// 콜드스타트 로딩 화면의 두 국면.
enum BootPhase {
  /// pre-Riverpod 서비스 부트: 0 → [kBootPhaseCeiling]
  boot,

  /// 앱 트리 부착 후 홈 프리로드: [kBootPhaseCeiling] → 1
  preload,
}

/// 01c 로딩 화면. **pre-Riverpod 게이트와 post-Riverpod 스플래시가 이 하나의
/// 위젯을 공유**한다 — 두 벌을 따로 만들면 padding 1dp 차이로도 인수인계에서
/// 깜빡인다(HIDDEN BLOCKS 에서 실제로 겪은 문제).
class LoganLandLoadingScreen extends StatelessWidget {
  const LoganLandLoadingScreen({
    super.key,
    required this.config,
    required this.progress,
    required this.phase,
  });

  final LoganLandBootConfig config;

  /// 해당 국면 내부의 로컬 진행률 0~1.
  final double progress;
  final BootPhase phase;

  double get _display {
    final p = progress.clamp(0.0, 1.0);
    return switch (phase) {
      BootPhase.boot => p * kBootPhaseCeiling,
      BootPhase.preload => kBootPhaseCeiling + p * (1 - kBootPhaseCeiling),
    };
  }

  @override
  Widget build(BuildContext context) {
    final display = _display;
    final percent = (display * 100).round().clamp(0, 100);
    // Material 조상을 둬서 Text 가 실제 DefaultTextStyle 을 잡게 한다. 이게
    // 없으면 이 시점엔 Scaffold/Material 이 전혀 없어서 Flutter 의 디버그
    // 텍스트 스타일(노란 이중밑줄)이 튀어나온다.
    return Material(
      color: config.plateColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: config.wordmarkWidthFactor,
              child: Image(
                image: AssetImage(
                  config.wordmarkAsset,
                  package: config.wordmarkPackage,
                ),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: config.horizontalInset,
                  right: config.horizontalInset,
                  bottom: config.bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.captionBuilder(percent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      // 번들 폰트를 일부러 피한다: pre-Riverpod 에는 테마 트리가
                      // 없고, 폰트 로딩 타이밍 차이로 두 국면의 글자가 달라
                      // 보이는 것을 막는다. 테마 색상도 참조하지 않는다.
                      style: TextStyle(
                        fontSize: config.captionSize,
                        fontWeight: config.captionWeight,
                        color: config.captionColor,
                        fontFamily: 'sans-serif',
                        fontFamilyFallback: const [],
                      ),
                    ),
                    SizedBox(height: config.captionGap),
                    _LoadingBar(config: config, value: display),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.config, required this.value});

  final LoganLandBootConfig config;
  final double value;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: config.barWidthFactor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value,
          minHeight: config.barThickness,
          backgroundColor: config.barTrack,
          valueColor: AlwaysStoppedAnimation<Color>(config.barFill),
        ),
      ),
    );
  }
}
