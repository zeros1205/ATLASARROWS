import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../models/arrow_line.dart';
import '../theme.dart';
import 'board_component.dart';
import 'z_arrows_game.dart';

enum _Anim { idle, escaping, bumpOut, bumpBack }

/// One arrow line. Lives in board coordinates (position 0,0, size = board),
/// drawn as a thin ink stroke sliding along its own extended path.
/// All lines share the ink color — reading the maze is the puzzle — and
/// only speak in color when tapped: blue while escaping, red when blocked.
class LineComponent extends PositionComponent
    with TapCallbacks, HasGameReference<ZArrowsGame> {
  LineComponent({required this.line, required Vector2 boardSize})
      : super(position: Vector2.zero(), size: boardSize);

  static const double cell = BoardComponent.cell;

  final ArrowLine line;

  late final ui.PathMetric _metric;
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

  /// Briefly tints this line red — used on the blocker so the player sees
  /// what stopped their arrow.
  void flashRed() => _flash = 0.4;

  Color get _color => switch (_anim) {
        _Anim.idle => _flash > 0 ? ZTheme.danger : ZTheme.ink,
        _Anim.escaping => ZTheme.accent,
        _Anim.bumpOut || _Anim.bumpBack => ZTheme.danger,
      };

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
    _anim = _Anim.escaping;
    _speed = cell * 5;
    _onGone = onGone;
    priority = 100;
  }

  void bump(int freeSteps, {required VoidCallback onImpact}) {
    _anim = _Anim.bumpOut;
    _bumpTarget = freeSteps * cell + cell * 0.32;
    _t = 0;
    _impactFired = false;
    _onImpact = onImpact;
    priority = 50;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    switch (_anim) {
      case _Anim.idle:
        break;
      case _Anim.escaping:
        _speed += cell * 26 * dt;
        _slide += _speed * dt;
        if (_slide >= _metric.length) {
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
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (animating) return false;
    final p = Offset(point.x, point.y);
    final centers = _centers;
    for (var i = 0; i < centers.length - 1; i++) {
      if (_distToSegment(p, centers[i], centers[i + 1]) < cell * 0.42) {
        return true;
      }
    }
    return false;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    var t = len2 == 0 ? 0.0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    game.handleTap(this);
  }

  @override
  void render(Canvas canvas) {
    final end = (_slide + _lineLen).clamp(0.0, _metric.length);
    if (_slide >= end) return;
    final visible = _metric.extractPath(_slide, end);
    final color = _color;

    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.13
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
        final head = Path()
          ..moveTo(cell * 0.30, 0)
          ..lineTo(-cell * 0.08, -cell * 0.24)
          ..lineTo(-cell * 0.08, cell * 0.24)
          ..close();
        canvas.drawPath(head, Paint()..color = color);
        canvas.restore();
      }
    }
  }
}
