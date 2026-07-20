import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../models/level.dart';
import 'line_component.dart';
import 'z_arrows_game.dart';

/// Hosts the arrow lines over faint dots marking the board silhouette.
/// Intrinsic size is [cell] px per grid cell; the game scales/centers it.
class BoardComponent extends PositionComponent
    with HasGameReference<ZArrowsGame> {
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

  // Terrain colors. Playing: sky-blue sea around a white territory that the
  // arrows sit on, so clearing them reveals the country shape. Cleared: the
  // sea goes white and the territory greys — a clean geographic silhouette.
  static const _seaPlay = Color(0xFFBFE3F5);
  static const _territoryPlay = Color(0xFFFFFFFF);
  static const _seaRevealed = Color(0xFFFFFFFF);
  static const _territoryRevealed = Color(0xFFA9AEB8);

  @override
  void render(Canvas canvas) {
    if (!game.terrainEnabled) {
      // Original look: faint dots marking the silhouette.
      final dot = Paint()..color = game.palette.dot;
      for (final (r, c) in level.mask) {
        canvas.drawCircle(
            Offset(c * cell + cell / 2, r * cell + cell / 2), 6, dot);
      }
      return;
    }
    final revealed = game.boardRevealed;
    final sea = Paint()..color = revealed ? _seaRevealed : _seaPlay;
    final territory = Paint()..color = revealed ? _territoryRevealed : _territoryPlay;
    // Sea fills the whole board box; the mask cells paint the territory on top.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), sea);
    for (final (r, c) in level.mask) {
      canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), territory);
    }
  }
}
