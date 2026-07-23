import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import 'onboarding_diagram.dart';

/// First-run intro: two rule cards that show the rule in motion, then an items
/// card for the two consumable controls (hint / remove), then straight into
/// play. Onboarding is the project's top priority surface — short and skippable.
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
  // Two animated rule pages; a third, custom "items" page follows them.
  static const _rules = [
    OnboardingRule.escape,
    OnboardingRule.blocked,
  ];
  int get _pageCount => _rules.length + 1;

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

  bool get _isLast => _index == _pageCount - 1;

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
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => i < _rules.length
                    ? _rulePage(c, l, _rules[i])
                    : _itemsPage(c, l),
              ),
            ),
            _Dots(count: _pageCount, index: _index, colors: c),
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

  /// An animated rule card: the diagram in motion over its title + body.
  Widget _rulePage(AppColors c, AppLocalizations l, OnboardingRule rule) {
    final (title, body) = _copy(l, rule);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
              height: 220, width: 220, child: OnboardingDiagram(rule: rule)),
          const SizedBox(height: AppGap.xxl),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.display
                  .copyWith(color: c.ink, fontSize: 26, height: 1.2)),
          const SizedBox(height: AppGap.md),
          Text(body,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.inkSoft, height: 1.5)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  /// The items card: the two consumable controls (hint, remove) stacked in a
  /// single centred column — each as button image → name → effect. The play
  /// screen shows them as bare icons, so this is where they are taught.
  Widget _itemsPage(AppColors c, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _itemCard(c, 'assets/images/icons/hint.png', l.barHint,
              l.onboardingItemHintDesc),
          const SizedBox(height: AppGap.xxl),
          _itemCard(c, 'assets/images/icons/remove.png', l.barRemove,
              l.onboardingItemRemoveDesc),
        ],
      ),
    );
  }

  /// One item, centred: its in-game button tile (icon at 2x), then its name,
  /// then what it does.
  Widget _itemCard(AppColors c, String icon, String name, String desc) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: c.line, width: 1.5),
            ),
            child: Center(child: Image.asset(icon, width: 68, height: 68)),
          ),
          const SizedBox(height: 14),
          Text(name,
              textAlign: TextAlign.center,
              style: AppText.headline
                  .copyWith(color: c.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(desc,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.inkSoft, height: 1.4)),
        ],
      );
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
