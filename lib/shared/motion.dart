import 'package:flutter/material.dart';

/// True when the OS asks for reduced motion. Every decorative animation in the
/// app checks this and degrades to a plain cut / static frame — per the
/// project's motion policy (enter = ease-out, no motion the player didn't ask
/// for, honour the accessibility setting).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A one-shot enter animation: fade in, optionally rising a few px. Uses an
/// ease-out curve (things arriving should decelerate). Collapses to a static
/// child when the OS requests reduced motion.
class EnterFade extends StatefulWidget {
  const EnterFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.rise = 10,
  });

  final Widget child;
  final Duration duration, delay;

  /// Px the child travels upward while fading in. 0 = pure fade.
  final double rise;

  @override
  State<EnterFade> createState() => _EnterFadeState();
}

class _EnterFadeState extends State<EnterFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.rise * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}
