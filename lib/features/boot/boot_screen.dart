import 'package:flutter/material.dart';
import 'package:loganland_boot/loganland_boot.dart';

import '../../app/boot.dart';
import '../../app/shell.dart';
import '../../app/tokens/dimens.dart';
import '../../services/progress.dart';
import '../onboarding/onboarding_screen.dart';

/// The second half of the cold start. `LoganLandBootGate` owns the native
/// splash, the LOGAN LAND card and the first 0 → 0.65 of the bar; this screen
/// is the app's own tree picking the same bar up at 0.65 and carrying it to 1
/// while the first frame warms.
///
/// It draws the kit's loading widget rather than a copy of it — the two halves
/// have to be pixel-identical or the plate flickers at the handover.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await preloadFirstFrame(
      context,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    // Held onto before the replace: this screen's element is defunct the
    // moment onboarding takes its place, so its context cannot be the thing
    // that later routes on to the shell.
    final nav = Navigator.of(context);
    // First run goes through onboarding; it hands off to the shell itself.
    final needsOnboarding = !Progress.instance.onboarded.value;
    nav.pushReplacement(_fade(needsOnboarding
        ? OnboardingScreen(onDone: () => nav.pushReplacement(_fade(const AppShell())))
        : const AppShell()));
  }

  static PageRoute<void> _fade(Widget page) => PageRouteBuilder(
        transitionDuration: AppDur.normal,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      );

  @override
  Widget build(BuildContext context) => LoganLandLoadingScreen(
        config: kBootConfig,
        progress: _progress,
        phase: BootPhase.preload,
      );
}
