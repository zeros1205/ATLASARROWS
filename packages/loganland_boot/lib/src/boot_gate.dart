import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'boot_config.dart';
import 'brand.dart';
import 'loading_screen.dart';
import 'publisher_splash.dart';

/// 콜드스타트 브랜드 구간 전체를 소유하는 게이트. **`runApp` 에 넘기는
/// 최상위 위젯**이 되어야 한다.
///
/// 왜 이런 구조인가:
/// Android 의 네이티브 SplashScreen 은 Flutter 가 **첫 프레임을 그리는 즉시**
/// 사라진다. 예전처럼 `main()` 에서 Hive/Firebase/repo 초기화를 전부 `await`
/// 한 뒤 `runApp` 하면, 그 시간 내내 OS 의 밋밋한 아이콘 화면이 떠 있게 된다.
/// 그래서 이 게이트가 가장 먼저 프레임을 그려 OS 스플래시를 즉시 걷어내고,
/// 실제 초기화는 **우리가 통제하는 브랜드 화면 뒤에서** 돌린다.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(LoganLandBootGate<BootServices>(
///     config: kBootConfig,
///     bootstrap: bootServices,          // Future<T> Function(void Function(double))
///     builder: (context, services) => MyApp(services: services),
///   ));
/// }
/// ```
class LoganLandBootGate<T> extends StatefulWidget {
  const LoganLandBootGate({
    super.key,
    required this.config,
    required this.bootstrap,
    required this.builder,
    this.onBooted,
  });

  final LoganLandBootConfig config;

  /// 실제 부트 작업. `onProgress(0~1)` 로 진행률을 보고한다.
  /// **여기서 던지는 예외는 앱을 스플래시에 얼어붙게 만든다** — 개별 단계는
  /// 내부에서 try/catch 후 진행하는 것을 원칙으로 한다.
  final Future<T> Function(void Function(double progress) onProgress) bootstrap;

  /// 부트 완료 후 실제 앱 트리(ProviderScope + MaterialApp 등)를 만든다.
  final Widget Function(BuildContext context, T services) builder;

  /// 게이트가 앱으로 넘어간 직후 fire-and-forget 으로 돌릴 비필수 SDK 초기화
  /// (광고 SDK 핸드셰이크 등). 여기에 두면 진입을 지연시키지 않는다.
  final Future<void> Function(T services)? onBooted;

  @override
  State<LoganLandBootGate<T>> createState() => _LoganLandBootGateState<T>();
}

class _LoganLandBootGateState<T> extends State<LoganLandBootGate<T>> {
  double _progress = 0;
  T? _services;
  bool _hasServices = false;

  /// 퍼블리셔 카드 최소 노출이 끝났는지. 그 전까진 부트 진행과 무관하게 카드 유지.
  bool _brandDone = false;

  /// 로딩 화면 최소 노출이 끝났는지(카드가 넘어간 시점부터 계산).
  bool _loadingMinDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
    Future.delayed(LoganLand.cardMinDuration, () {
      if (!mounted) return;
      setState(() => _brandDone = true);
      // 로딩 최소 시간은 화면이 실제로 보이기 시작한 시점부터 잰다.
      Future.delayed(widget.config.loadingMinDuration, () {
        if (mounted) setState(() => _loadingMinDone = true);
      });
    });
  }

  Future<void> _run() async {
    final services = await widget.bootstrap((p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    setState(() {
      _services = services;
      _hasServices = true;
    });
    final onBooted = widget.onBooted;
    if (onBooted != null) unawaited(onBooted(services));
  }

  @override
  Widget build(BuildContext context) {
    // 카드가 앞 1.6s, 로딩이 최소 1.8s 를 각각 소유한다. 부트가 일찍 끝나도
    // 둘 다 붙잡는다 — 안 그러면 빠른 기기에서 브랜드가 몇 프레임 만에 스쳐
    // 지나간다. 두 화면이 하나의 MaterialApp 을 공유해야 크로스페이드가 성립.
    if (!_brandDone || !_loadingMinDone || !_hasServices) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedSwitcher(
          duration: LoganLand.handoffDuration,
          child: !_brandDone
              ? const PublisherSplash()
              : _RampedLoading(
                  key: const ValueKey('boot'),
                  config: widget.config,
                  progress: _progress,
                ),
        ),
      );
    }
    return widget.builder(context, _services as T);
  }
}

/// 진행바가 "실제 부트"와 "최소 노출시간 선형 램프" 중 **느린 쪽**을 따라가게
/// 한다. 램프가 없으면 빠른 부팅에서 바가 곧장 상한까지 튄 뒤 남은 최소시간
/// 내내 얼어붙어 있게 된다 — 화면이 떠 있는 동안 바는 계속 움직여야 한다.
class _RampedLoading extends StatelessWidget {
  const _RampedLoading({
    super.key,
    required this.config,
    required this.progress,
  });

  final LoganLandBootConfig config;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: config.loadingMinDuration,
      curve: Curves.linear,
      builder: (context, ramp, _) => LoganLandLoadingScreen(
        config: config,
        progress: math.min(progress.clamp(0.0, 1.0), ramp),
        phase: BootPhase.boot,
      ),
    );
  }
}
