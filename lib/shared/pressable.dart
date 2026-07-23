import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tokens/dimens.dart';
import '../services/progress.dart';

/// The universal press signature: scale down and dim slightly on press,
/// release with an easeOutBack overshoot — the same dual shrink+dim feedback
/// iOS gives its own cards and rows. A light haptic on tap. Degrades under
/// reduce-motion.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

/// Opacity a pressed [Pressable] dims to, at full press.
const double _pressedOpacity = 0.88;

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  // 0 = at rest, 1 = fully pressed.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDur.fast,
    reverseDuration: AppDur.normal,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.animateTo(1, curve: Curves.easeOut);
  void _up() => _c.animateTo(0, curve: AppCurve.overshoot);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final noMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled && !noMotion ? _down : null,
      onTapCancel: enabled && !noMotion ? _up : null,
      onTapUp: enabled && !noMotion ? (_) => _up() : null,
      onTap: enabled
          ? () {
              // Settings › 진동 is the master switch for every press haptic.
              if (widget.haptic && Progress.instance.hapticsOn.value) {
                HapticFeedback.lightImpact();
              }
              widget.onTap!();
            }
          : null,
      child: noMotion
          ? widget.child
          : AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Transform.scale(
                scale: 1 - _c.value * (1 - widget.scale),
                child: Opacity(
                  opacity:
                      (1 - _c.value * (1 - _pressedOpacity)).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
              child: widget.child,
            ),
    );
  }
}
