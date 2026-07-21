import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import 'onboarding_diagram.dart';

/// First-run intro: three rule cards, then straight into play. Onboarding is
/// the project's top priority surface — it is short, skippable, and every page
/// shows the rule in motion rather than describing it in prose.
///
/// Shown by [BootScreen] when `Progress.onboarded` is false, and replayable
/// from Settings. [onDone] is called once the player finishes or skips.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = const [
    (
      rule: OnboardingRule.escape,
      title: '화살표를 탭하세요',
      body: '탭한 화살표는 머리가 향한 방향으로 미끄러져 보드를 빠져나갑니다.',
    ),
    (
      rule: OnboardingRule.blocked,
      title: '앞이 막히면 부딪힙니다',
      body: '길을 막는 화살표가 있으면 튕겨 나오고 하트를 하나 잃어요. 순서가 곧 실력입니다.',
    ),
    (
      rule: OnboardingRule.clear,
      title: '보드를 비우면 클리어',
      body: '모든 화살표를 내보내면 스테이지 완료. 세계지도를 따라 다음 나라로 나아가세요.',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Progress.instance.setOnboarded(true);
    widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    if (reduceMotion(context)) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: AppDur.normal, curve: AppCurve.gentle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip stays available on every page — never trap a player who
            // already knows the rules.
            Align(
              alignment: Alignment.centerRight,
              child: Pressable(
                haptic: false,
                onTap: _finish,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Text('건너뛰기',
                      style: AppText.label.copyWith(color: c.inkFaint)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: 220,
                          width: 220,
                          child: OnboardingDiagram(rule: page.rule),
                        ),
                        const SizedBox(height: AppGap.xxl),
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: AppText.display.copyWith(
                                color: c.ink, fontSize: 26, height: 1.2)),
                        const SizedBox(height: AppGap.md),
                        Text(page.body,
                            textAlign: TextAlign.center,
                            style: AppText.body.copyWith(
                                color: c.inkSoft, height: 1.5)),
                        const Spacer(flex: 2),
                      ],
                    ),
                  );
                },
              ),
            ),
            _Dots(count: _pages.length, index: _index, colors: c),
            const SizedBox(height: AppGap.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: Pressable(
                onTap: _next,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: kButtonPadV),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(_isLast ? '플레이 시작' : '다음',
                      style: kButtonText.copyWith(color: c.onAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.colors});
  final int count, index;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppDur.normal,
              curve: AppCurve.gentle,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? colors.accent : colors.line,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      );
}
