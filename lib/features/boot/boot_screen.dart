import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../models/shape_catalog.dart';
import '../../models/world_map.dart';
import '../../services/ads/ads.dart';
import '../../services/iap.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../onboarding/onboarding_screen.dart';

/// Boot sequence: blank off-black splash -> off-black studio page (logo +
/// LOGAN LAND wordmark) -> paper loading plate with a progress bar while
/// services initialize -> the 4-tab shell.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

enum _Phase { splash, studio, loading }

class _BootScreenState extends State<BootScreen> {
  _Phase _phase = _Phase.splash;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _phase = _Phase.studio);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _phase = _Phase.loading);

    // Initialize services, driving the progress bar.
    final steps = <Future<void> Function()>[
      () => Progress.instance.load(),
      () => ShapeCatalog.load(),
      () => CampaignRepository.instance.load(),
      () => WorldMap.instance.load(),
      () => Ads.init(),
      () => IapService.instance.init(),
    ];
    for (var i = 0; i < steps.length; i++) {
      try {
        await steps[i]();
      } catch (_) {/* non-fatal — offline / not-yet-available assets */}
      if (!mounted) return;
      setState(() => _progress = (i + 1) / steps.length);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    // First run goes through onboarding; it hands off to the shell itself.
    final needsOnboarding = !Progress.instance.onboarded.value;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppDur.normal,
        pageBuilder: (context, a, b) => needsOnboarding
            ? OnboardingScreen(onDone: () => _toShell(context))
            : const AppShell(),
        transitionsBuilder: (_, a, b, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _toShell(BuildContext context) => Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: AppDur.normal,
          pageBuilder: (_, a, b) => const AppShell(),
          transitionsBuilder: (_, a, b, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = _phase != _Phase.loading;
    return Scaffold(
      backgroundColor: dark ? c.ink : c.bg,
      body: AnimatedSwitcher(
        duration: AppDur.normal,
        child: switch (_phase) {
          _Phase.splash => const _Splash(),
          _Phase.studio => _Studio(fg: c.bg, accent: c.accent),
          _Phase.loading => _Loading(
              ink: c.ink, accent: c.accent, faint: c.inkSoft, progress: _progress),
        },
      ),
    );
  }
}

/// Native splash carries straight into a blank off-black screen (no mark).
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('splash'));
}

class _Studio extends StatelessWidget {
  const _Studio({required this.fg, required this.accent});
  final Color fg, accent;
  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('studio'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnterFade(
              rise: 0,
              duration: const Duration(milliseconds: 380),
              child: _Mark(color: fg, accent: accent, size: 56),
            ),
            const SizedBox(height: 16),
            // The wordmark trails the mark by a beat, rising as it fades in.
            EnterFade(
              delay: const Duration(milliseconds: 140),
              child: Text('LOGAN LAND',
                  style: AppText.title.copyWith(
                      color: fg, letterSpacing: 3, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading(
      {required this.ink,
      required this.accent,
      required this.faint,
      required this.progress});
  final Color ink, accent, faint;
  final double progress;
  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('loading'),
        child: EnterFade(
          rise: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Mark(color: ink, accent: accent, size: 96),
              const SizedBox(height: 26),
              SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  // Tween the fill so each service step glides instead of
                  // snapping a fifth of the bar at a time.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: AppDur.normal,
                    curve: AppCurve.gentle,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value == 0 ? null : value,
                      minHeight: 5,
                      backgroundColor: faint.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('화살표를 불러오는 중 ${(progress * 100).round()}%',
                  style: AppText.caption.copyWith(color: faint)),
            ],
          ),
        ),
      );
}

/// The Z snake-line mark drawn inline (ink line + blue arrowhead).
class _Mark extends StatelessWidget {
  const _Mark({required this.color, required this.accent, required this.size});
  final Color color, accent;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _MarkPainter(color, accent));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ink, this.accent);
  final Color ink, accent;
  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 100;
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(22 * u, 26 * u)
      ..lineTo(78 * u, 26 * u)
      ..lineTo(78 * u, 40 * u)
      ..lineTo(52 * u, 40 * u)
      ..lineTo(52 * u, 52 * u)
      ..lineTo(48 * u, 52 * u)
      ..lineTo(48 * u, 64 * u)
      ..lineTo(22 * u, 64 * u)
      ..lineTo(22 * u, 78 * u)
      ..lineTo(68 * u, 78 * u);
    canvas.drawPath(path, p);
    final head = Path()
      ..moveTo(64 * u, 66 * u)
      ..lineTo(86 * u, 78 * u)
      ..lineTo(64 * u, 90 * u)
      ..close();
    canvas.drawPath(head, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ink != ink || old.accent != accent;
}
