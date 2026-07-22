import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../models/level.dart';
import 'line_component.dart';
import 'atlas_arrows_game.dart';

/// Hosts the arrow lines over faint dots marking the board silhouette.
/// Intrinsic size is [cell] px per grid cell; the game scales/centers it.
class BoardComponent extends PositionComponent
    with HasGameReference<AtlasArrowsGame> {
  BoardComponent({required this.level})
      : super(size: Vector2(level.cols * cell, level.rows * cell));

  static const double cell = 100;

  final Level level;

  @override
  Future<void> onLoad() async {
    for (final line in level.lines) {
      await add(LineComponent(line: line, boardSize: size.clone()));
    }
  }

  LineComponent? lineById(int id) {
    for (final child in children.whereType<LineComponent>()) {
      if (child.line.id == id) return child;
    }
    return null;
  }

  @override
  void render(Canvas canvas) {
    // Faint dots marking the silhouette. No background fill — the board sits
    // on the page ground; the country reveal happens on the clear screen.
    final t = game.introDots;
    if (t >= 1) {
      final dot = Paint()..color = game.palette.dot;
      for (final (r, c) in level.mask) {
        canvas.drawCircle(
            Offset(c * cell + cell / 2, r * cell + cell / 2), 6, dot);
      }
      return;
    }
    // Entrance: the dots rain in, each cell popping in at its own random time
    // and dropping the last little way into place. 't' sweeps 0→1; a cell's
    // hash sets when in that sweep it starts, then it fades in over a short
    // window. Cells whose window hasn't opened yet are simply not drawn.
    final base = game.palette.dot;
    for (final (r, c) in level.mask) {
      final start = _rainHash(r, c) * (1 - _fall);
      final a = ((t - start) / _fall).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final drop = (1 - a) * cell * 0.55; // falls the last half-cell into place
      canvas.drawCircle(
          Offset(c * cell + cell / 2, r * cell + cell / 2 - drop),
          6,
          Paint()..color = base.withValues(alpha: a));
    }
  }

  /// Width of a single dot's fade-in as a share of the whole rain sweep — the
  /// rest of the sweep is spent staggering the start times across the cells.
  static const double _fall = 0.28;

  /// Stable pseudo-random [0,1) per cell, so the rain lands the same way each
  /// frame (a fixed scatter, not a shimmer).
  static double _rainHash(int r, int c) {
    var h = (r * 73856093) ^ (c * 19349663);
    h &= 0x7fffffff;
    return (h % 1000) / 1000.0;
  }
}
