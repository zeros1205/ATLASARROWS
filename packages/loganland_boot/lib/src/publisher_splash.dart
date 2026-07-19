import 'package:flutter/material.dart';

import 'brand.dart';

/// 01b 퍼블리셔 브랜드 카드 — 콜드스타트에서 가장 먼저 보이는 화면.
///
/// 순수 표시용이며 테마에 의존하지 않는다(하드코딩 흑/백 + 번들 Paperlogy).
/// 그래야 pre-Riverpod / post-Riverpod 어디서 그려도 동일하다.
/// **노출 시간은 이 위젯이 소유하지 않는다** — `LoganLandBootGate` 가 소유하며,
/// 서비스 부트와 오버랩시켜 빠른 기기에서 추가 대기가 생기지 않게 한다.
class PublisherSplash extends StatelessWidget {
  const PublisherSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LoganLand.offBlack,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `unit` = 락업의 스케일 기준. 마크 아트는 여백 없이 타이트하게
            // 크롭돼 있으므로 큐브 크기와 아래 간격을 모두 unit 비율로 잡는다
            // (이미지에 투명 패딩이 있으면 간격이 제멋대로 벌어진다).
            final cubeSide = constraints.maxWidth.clamp(320.0, 900.0) * 0.42;
            final unit = cubeSide.clamp(150.0, 300.0);
            final cube = unit * 0.62;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: LoganLand.cardFadeIn,
              curve: Curves.easeOut,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    LoganLand.markAsset,
                    package: LoganLand.markPackage,
                    width: cube,
                    height: cube,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(height: unit * 0.10),
                  Text(
                    LoganLand.publisher,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: LoganLand.fontFamily,
                      package: LoganLand.fontPackage,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: unit * 0.185,
                      letterSpacing: 1.0,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
