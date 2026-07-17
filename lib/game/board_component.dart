import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../models/level.dart';
import '../theme.dart';
import 'line_component.dart';

/// Hosts the arrow lines over faint dots marking the board silhouette.
/// Intrinsic size is [cell] px per grid cell; the game scales/centers it.
class BoardComponent extends PositionComponent {
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
    final dot = Paint()..color = ZTheme.dot;
    for (final (r, c) in level.mask) {
      canvas.drawCircle(
        Offset(c * cell + cell / 2, r * cell + cell / 2),
        6,
        dot,
      );
    }
  }
}
