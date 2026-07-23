import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../l10n/app_localizations.dart';
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
  static const _rules = [
    OnboardingRule.escape,
    OnboardingRule.blocked,
    OnboardingRule.clear,
  ];

  /// Localized title + body for a rule card.
  static (String, String) _copy(AppLocalizations l, OnboardingRule rule) =>
      switch (rule) {
        OnboardingRule.escape =>
          (l.onboardingEscapeTitle, l.onboardingEscapeBody),
        OnboardingRule.blocked =>
          (l.onboardingBlockedTitle, l.onboardingBlockedBody),
        OnboardingRule.clear =>
          (l.onboardingClearTitle, l.onboardingClearBody),
      };

  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _rules.length - 1;

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
    final l = AppLocalizations.of(context);
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
                  child: Text(l.onboardingSkip,
                      style: AppText.label.copyWith(color: c.inkFaint)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _rules.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final rule = _rules[i];
                  final (title, body) = _copy(l, rule);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: 220,
                          width: 220,
                          child: OnboardingDiagram(rule: rule),
                        ),
                        const SizedBox(height: AppGap.xxl),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: AppText.display.copyWith(
                                color: c.ink, fontSize: 26, height: 1.2)),
                        const SizedBox(height: AppGap.md),
                        Text(body,
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
            _Dots(count: _rules.length, index: _index, colors: c),
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
                  child: Text(_isLast ? l.onboardingStart : l.next,
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
