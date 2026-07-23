import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../models/arrow_line.dart';
import 'board_component.dart';
import 'atlas_arrows_game.dart';

enum _Anim { idle, escaping, bumpOut, bumpBack, vaporizing }

/// One arrow line. Lives in board coordinates (position 0,0, size = board),
/// drawn as a thin ink stroke sliding along its own extended path.
/// All lines share the ink color — reading the maze is the puzzle — and
/// only speak in color when tapped: blue while escaping, red when blocked.
class LineComponent extends PositionComponent
    with HasGameReference<AtlasArrowsGame> {
  LineComponent({required this.line, required Vector2 boardSize})
      : super(position: Vector2.zero(), size: boardSize);

  static const double cell = BoardComponent.cell;

  final ArrowLine line;

  late ui.PathMetric _metric;
  late final double _lineLen;

  _Anim _anim = _Anim.idle;
  double _slide = 0;
  double _speed = 0;
  double _bumpTarget = 0;
  double _t = 0;
  VoidCallback? _onGone;
  VoidCallback? _onImpact;
  bool _impactFired = false;

  bool get animating => _anim != _Anim.idle;

  double _flash = 0;
  bool _hintHeld = false;
  double _hintClock = 0;
  double _fade = 1;

  /// Briefly tints this line red — used on the blocker so the player sees
  /// what stopped their arrow.
  void flashRed() => _flash = 0.4;

  /// Blinks this line blue and keeps blinking — the hint highlight for a free
  /// line, held until [clearHint] (the player's next arrow tap).
  void holdHint() => _hintHeld = true;
  void clearHint() {
    _hintHeld = false;
    _hintClock = 0;
  }

  Color get _color {
    final p = game.palette;
    return switch (_anim) {
      _Anim.idle => _flash > 0
          ? p.danger
          : _hintHeld && (_hintClock * 3).floor().isOdd
              ? p.accent
              : p.ink,
      _Anim.escaping => p.accent,
      _Anim.bumpOut || _Anim.bumpBack => p.danger,
      _Anim.vaporizing => p.accent,
    };
  }

  List<Offset> get _centers => [
        for (final (r, c) in line.cells)
          Offset(c * cell + cell / 2, r * cell + cell / 2),
      ];

  @override
  Future<void> onLoad() async {
    // Extended path = the line itself plus its straight exit ray, carried
    // far enough past the board edge that the tail fully leaves the view.
    final centers = _centers;
    final dir = line.headDir;
    final (hr, hc) = line.head;
    final cellsToEdge = switch (dir.dx) {
      1 => size.x / cell - 1 - hc,
      -1 => hc.toDouble(),
      _ => dir.dy == 1 ? size.y / cell - 1 - hr : hr.toDouble(),
    };
    final exit = centers.last +
        Offset(dir.dx.toDouble(), dir.dy.toDouble()) *
            ((cellsToEdge + 3.0) * cell);
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (final p in centers.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(exit.dx, exit.dy);
    _metric = path.computeMetrics().first;
    _lineLen = (line.cells.length - 1) * cell;
  }

  void escape({required VoidCallback onGone}) {
    // Lengthen the exit ray so the whole line slides off the visible play area
    // (the Flame canvas) before it is removed — otherwise a letterboxed or
    // small board removes it a few cells past the board edge, mid-view.
    _extendExitOffScreen();
    _anim = _Anim.escaping;
    _speed = cell * 15 * _escapeSpeedMul;
    _onGone = onGone;
    priority = 100;
  }

  /// Escape glide is 1.5x its original pace end to end (start speed, ramp,
  /// and cap all scaled together so the motion keeps the same shape).
  static const double _escapeSpeedMul = 1.5;

  /// Rebuilds the path's straight exit ray so the line leaves the screen,
  /// using the board's fit transform and the current pan/zoom. Falls back to
  /// the onLoad path if the board hasn't been laid out yet.
  void _extendExitOffScreen() {
    final board = parent;
    if (board is! PositionComponent || board.scale.x <= 0) return;
    final s = board.scale.x; // fit scale
    final view = game.visibleRect;
    final bx = board.size.x, by = board.size.y;
    final px = board.position.x, py = board.position.y; // board centre on canvas
    final centers = _centers;
    final head = centers.last;
    final dir = line.headDir;
    // Board-coord travel for the head to pass the edge of the visible area
    // along its heading.
    final t = switch ((dir.dx, dir.dy)) {
      (1, _) => bx / 2 + (view.right - px) / s - head.dx,
      (-1, _) => head.dx - bx / 2 - (view.left - px) / s,
      (_, 1) => by / 2 + (view.bottom - py) / s - head.dy,
      _ => head.dy - by / 2 - (view.top - py) / s,
    };
    // The ray has to carry the *tail* past the edge, not just the head: the
    // head stops dead at the end of the path (render clamps to it) and the
    // line then collapses in place instead of flying off. So add the body's
    // own length, plus 2 cells of slack.
    final rayLen = math.max(t + _lineLen + cell * 2, cell * 3);
    final exit = head + Offset(dir.dx.toDouble(), dir.dy.toDouble()) * rayLen;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (final p in centers.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(exit.dx, exit.dy);
    _metric = path.computeMetrics().first;
  }

  void bump(int freeSteps, {required VoidCallback onImpact}) {
    _anim = _Anim.bumpOut;
    _bumpTarget = freeSteps * cell + cell * 0.32;
    _t = 0;
    _impactFired = false;
    _onImpact = onImpact;
    priority = 50;
  }

  /// Remove item: a lightning strike vaporizes the line — a quick fade-out.
  void vaporize({required VoidCallback onGone}) {
    _anim = _Anim.vaporizing;
    _t = 0;
    _fade = 1;
    _onGone = onGone;
    priority = 100;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    if (_hintHeld) _hintClock += dt;
    switch (_anim) {
      case _Anim.idle:
        break;
      case _Anim.escaping:
        // A gentle ramp to a capped glide speed. Uncapped acceleration made a
        // full-board exit at zoom-out flash past in a couple of frames (janky);
        // the cap holds it near ~1 cell/frame — a smooth slide at any zoom.
        _speed = math.min(
            cell * 70 * _escapeSpeedMul, _speed + cell * 20 * _escapeSpeedMul * dt);
        _slide += _speed * dt;
        // Gone once the *head* reaches the end of the extended path — by then
        // the tail is off screen too. Waiting for the tail to travel the whole
        // path instead would park the head at the end and eat the body in
        // place, which reads as vanishing mid-air.
        if (_slide + _lineLen >= _metric.length) {
          removeFromParent();
          _onGone?.call();
        }
      case _Anim.bumpOut:
        _t += dt / 0.16;
        _slide = _bumpTarget * Curves.easeOutQuad.transform(_t.clamp(0, 1));
        if (_t >= 1) {
          if (!_impactFired) {
            _impactFired = true;
            _onImpact?.call();
          }
          _anim = _Anim.bumpBack;
          _t = 0;
        }
      case _Anim.bumpBack:
        _t += dt / 0.24;
        _slide =
            _bumpTarget * (1 - Curves.easeOutBack.transform(_t.clamp(0, 1)));
        if (_t >= 1) {
          _slide = 0;
          _anim = _Anim.idle;
          priority = 0;
        }
      case _Anim.vaporizing:
        _t += dt / 0.3;
        _fade = (1 - _t).clamp(0.0, 1.0);
        if (_t >= 1) {
          removeFromParent();
          _onGone?.call();
        }
    }
  }

  /// Nearest distance from [point] (board coordinates) to this line's body, or
  /// infinity while it is animating. The game uses it to pick the tapped line.
  /// Tap detection itself now lives in the Flutter layer (game_screen), which
  /// routes a stationary press here and a drag to the board's pan/zoom — so a
  /// near-tap is never swallowed by the InteractiveViewer's pan recogniser.
  double distanceToPoint(Vector2 point) {
    if (animating) return double.infinity;
    final p = Offset(point.x, point.y);
    final centers = _centers;
    var best = double.infinity;
    for (var i = 0; i < centers.length - 1; i++) {
      final d = _distToSegment(p, centers[i], centers[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    var t = len2 == 0 ? 0.0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// Entrance fill (phase 4): once the dots have rained in, the arrows fade up
  /// over them, each line on its own staggered slot of the [game.introArrows]
  /// sweep. 1 outside the intro, so normal play is untouched.
  double _introAlpha() {
    final t = game.introArrows;
    if (t >= 1) return 1;
    final h = (line.id * 0.61803398875) % 1.0; // golden-ratio scatter per line
    const window = 0.42;
    return ((t - h * (1 - window)) / window).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final end = (_slide + _lineLen).clamp(0.0, _metric.length);
    if (_slide >= end) return;
    final introA = _introAlpha();
    if (introA <= 0) return;
    final visible = _metric.extractPath(_slide, end);
    var color = _anim == _Anim.vaporizing
        ? _color.withValues(alpha: _fade)
        : _color;
    if (introA < 1) color = color.withValues(alpha: color.a * introA);

    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Arrowhead riding the path tangent; hidden once the head slides past
    // the extended path's end (only the tail remains in view by then).
    final headOffset = _slide + _lineLen;
    if (headOffset < _metric.length) {
      final tangent = _metric.getTangentForOffset(headOffset);
      if (tangent != null) {
        final pos = tangent.position;
        final ang = -tangent.angle;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(ang);
        // Head base 3x the shaft (strokeWidth cell*0.2). The heading is what
        // the player reads to plan a move, so it carries a little more weight
        // than the airy reference — still far short of the 0.96 cell base that
        // made a dense board look solid.
        final head = Path()
          ..moveTo(cell * 0.34, 0)
          ..lineTo(-cell * 0.17, -cell * 0.30)
          ..lineTo(-cell * 0.17, cell * 0.30)
          ..close();
        canvas.drawPath(head, Paint()..color = color);
        canvas.restore();
      }
    }
  }
}
