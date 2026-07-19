import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../shared/motion.dart';

/// Which rule a diagram demonstrates.
enum OnboardingRule {
  /// A free arrow slides out of the board when tapped.
  escape,

  /// A blocked arrow bumps its blocker and costs a heart.
  blocked,

  /// Emptying the board clears the stage.
  clear,
}

/// A small looping diagram of one rule, drawn with the same vocabulary as the
/// live board (dot grid, ink stroke, triangular arrowhead) so the onboarding
/// reads as the game and not as a separate illustration.
///
/// Loops on a 2.6s cycle; freezes on the resting frame under reduced motion.
class OnboardingDiagram extends StatefulWidget {
  const OnboardingDiagram({super.key, required this.rule});

  final OnboardingRule rule;

  @override
  State<OnboardingDiagram> createState() => _OnboardingDiagramState();
}

class _OnboardingDiagramState extends State<OnboardingDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (reduceMotion(context)) {
      // Rest frame: the moment the rule is legible without any motion.
      return CustomPaint(
        painter: _DiagramPainter(rule: widget.rule, t: 0.42, colors: c),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _DiagramPainter(rule: widget.rule, t: _c.value, colors: c),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter({required this.rule, required this.t, required this.colors});

  final OnboardingRule rule;
  final double t;
  final AppColors colors;

  /// Board is 5x5 cells; the painter fits it to the shorter side.
  static const int grid = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.shortestSide) / grid;
    final board = cell * grid;
    canvas.save();
    canvas.translate((size.width - board) / 2, (size.height - board) / 2);
    canvas.clipRect(Rect.fromLTWH(-cell, -cell, board + cell * 2, board + cell * 2));

    _dots(canvas, cell);
    switch (rule) {
      case OnboardingRule.escape:
        _escape(canvas, cell);
      case OnboardingRule.blocked:
        _blocked(canvas, cell);
      case OnboardingRule.clear:
        _clear(canvas, cell);
    }
    canvas.restore();
  }

  Offset _c(int r, int col, double cell) =>
      Offset(col * cell + cell / 2, r * cell + cell / 2);

  void _dots(Canvas canvas, double cell) {
    final p = Paint()..color = colors.dot;
    for (var r = 0; r < grid; r++) {
      for (var col = 0; col < grid; col++) {
        canvas.drawCircle(_c(r, col, cell), cell * 0.06, p);
      }
    }
  }

  /// Draws a straight arrow of [len] cells whose head sits at [head],
  /// pointing along [dir], shifted [slide] px along that direction.
  void _arrow(Canvas canvas, double cell,
      {required Offset head,
      required Offset dir,
      required int len,
      required Color color,
      double slide = 0,
      double alpha = 1}) {
    final paintColor = color.withValues(alpha: alpha);
    final h = head + dir * slide;
    final tail = h - dir * (cell * (len - 1));
    canvas.drawLine(
      tail,
      h,
      Paint()
        ..color = paintColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.13
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(h.dx, h.dy);
    canvas.rotate(dir.direction);
    canvas.drawPath(
      Path()
        ..moveTo(cell * 0.30, 0)
        ..lineTo(-cell * 0.08, -cell * 0.24)
        ..lineTo(-cell * 0.08, cell * 0.24)
        ..close(),
      Paint()..color = paintColor,
    );
    canvas.restore();
  }

  /// A tap ripple — the finger cue.
  void _tap(Canvas canvas, Offset at, double cell, double progress) {
    if (progress <= 0 || progress >= 1) return;
    final ease = Curves.easeOutCubic.transform(progress);
    canvas.drawCircle(
      at,
      cell * (0.25 + ease * 0.5),
      Paint()
        ..color = colors.accent.withValues(alpha: (1 - ease) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06,
    );
  }

  /// Rule 1 — tap a free arrow, it slides out of the board.
  void _escape(Canvas canvas, double cell) {
    const head = 2, col = 2;
    final at = _c(head, col, cell);
    // 0.00–0.25 idle+tap · 0.25–0.85 slide out · 0.85–1.0 empty beat. The
    // empty tail is kept short: a diagram that sits blank for a quarter of
    // its loop reads as a rendering bug rather than a pause.
    final tapT = (t / 0.25).clamp(0.0, 1.0);
    final slideT = ((t - 0.25) / 0.6).clamp(0.0, 1.0);
    final gone = slideT >= 1;
    if (!gone) {
      final eased = Curves.easeInCubic.transform(slideT);
      _arrow(canvas, cell,
          head: at,
          dir: const Offset(1, 0),
          len: 3,
          color: slideT > 0 ? colors.accent : colors.ink,
          slide: eased * cell * 5.5);
    }
    _tap(canvas, at, cell, tapT);
  }

  /// Rule 2 — a blocked arrow bumps and springs back; a heart is spent.
  void _blocked(Canvas canvas, double cell) {
    const row = 2;
    final mover = _c(row, 1, cell);
    // Blocker: a vertical arrow standing in the mover's way at column 3.
    _arrow(canvas, cell,
        head: _c(1, 3, cell),
        dir: const Offset(0, -1),
        len: 3,
        color: t > 0.30 && t < 0.55 ? colors.danger : colors.ink);

    final tapT = (t / 0.25).clamp(0.0, 1.0);
    // Bump out fast, spring back — mirrors LineComponent's bump timing.
    double slide;
    Color color = colors.ink;
    if (t < 0.25) {
      slide = 0;
    } else if (t < 0.36) {
      slide = Curves.easeOutQuad.transform((t - 0.25) / 0.11) * cell * 0.9;
      color = colors.danger;
    } else if (t < 0.55) {
      slide =
          (1 - Curves.easeOutBack.transform((t - 0.36) / 0.19)) * cell * 0.9;
      color = colors.danger;
    } else {
      slide = 0;
    }
    _arrow(canvas, cell,
        head: mover, dir: const Offset(1, 0), len: 2, color: color,
        slide: slide);
    _tap(canvas, mover, cell, tapT);

    // A heart drains out above the collision.
    if (t > 0.30) {
      final f = ((t - 0.30) / 0.35).clamp(0.0, 1.0);
      _heart(canvas, _c(0, 3, cell) + Offset(0, -cell * 0.1 - f * cell * 0.5),
          cell * 0.30, colors.danger.withValues(alpha: (1 - f) * 0.9));
    }
  }

  /// Rule 3 — the last arrow leaves and the board is clear.
  void _clear(Canvas canvas, double cell) {
    final last = _c(2, 2, cell);
    final slideT = (t / 0.4).clamp(0.0, 1.0);
    if (slideT < 1) {
      _arrow(canvas, cell,
          head: last,
          dir: const Offset(1, 0),
          len: 2,
          color: colors.accent,
          slide: Curves.easeInCubic.transform(slideT) * cell * 5.5);
    } else {
      // Check mark draws itself on, then holds.
      final draw = ((t - 0.4) / 0.25).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(draw);
      final o = _c(2, 2, cell);
      final a = o + Offset(-cell * 0.55, 0);
      final b = o + Offset(-cell * 0.15, cell * 0.42);
      final cpt = o + Offset(cell * 0.62, -cell * 0.5);
      final p = Paint()
        ..color = colors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(a.dx, a.dy);
      if (e <= 0.5) {
        final k = e / 0.5;
        path.lineTo(a.dx + (b.dx - a.dx) * k, a.dy + (b.dy - a.dy) * k);
      } else {
        final k = (e - 0.5) / 0.5;
        path.lineTo(b.dx, b.dy);
        path.lineTo(b.dx + (cpt.dx - b.dx) * k, b.dy + (cpt.dy - b.dy) * k);
      }
      canvas.drawPath(path, p);
    }
  }

  void _heart(Canvas canvas, Offset at, double r, Color color) {
    final path = Path()
      ..moveTo(at.dx, at.dy + r * 0.75)
      ..cubicTo(at.dx - r * 1.5, at.dy - r * 0.35, at.dx - r * 0.55,
          at.dy - r * 1.15, at.dx, at.dy - r * 0.35)
      ..cubicTo(at.dx + r * 0.55, at.dy - r * 1.15, at.dx + r * 1.5,
          at.dy - r * 0.35, at.dx, at.dy + r * 0.75)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DiagramPainter old) =>
      old.t != t || old.rule != rule || old.colors != colors;
}
