import 'dart:math' as math;

/// The four cardinal directions an arrow tile can point.
enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dx, this.dy);

  /// Column delta when moving one cell in this direction.
  final int dx;

  /// Row delta when moving one cell in this direction.
  final int dy;

  /// Rotation from an up-pointing glyph, in radians.
  double get angle => switch (this) {
        Direction.up => 0,
        Direction.right => math.pi / 2,
        Direction.down => math.pi,
        Direction.left => -math.pi / 2,
      };

  static Direction? fromChar(String c) => switch (c) {
        'U' => Direction.up,
        'D' => Direction.down,
        'L' => Direction.left,
        'R' => Direction.right,
        _ => null,
      };
}
