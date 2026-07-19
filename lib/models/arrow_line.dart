import 'direction.dart';

/// One arrow: an ordered path of grid cells from tail to head.
/// Cells are (row, col) records; the arrowhead sits on [cells.last] and
/// points along the delta between the last two cells.
class ArrowLine {
  ArrowLine({required this.id, required this.cells})
      : assert(cells.length >= 2, 'a line needs a tail and a head');

  final int id;
  final List<(int, int)> cells;

  (int, int) get head => cells.last;

  Direction get headDir {
    final (r1, c1) = cells[cells.length - 2];
    final (r2, c2) = cells.last;
    return Direction.values.firstWhere(
      (d) => d.dy == r2 - r1 && d.dx == c2 - c1,
    );
  }

  /// Parses `"r,c:MOVES"` — tail position plus a string of U/D/L/R steps
  /// tracing the path toward the head, e.g. `"1,2:RRD"`.
  factory ArrowLine.parse(int id, String spec) {
    final [pos, moves] = spec.split(':');
    final [r, c] = pos.split(',').map(int.parse).toList();
    final cells = [(r, c)];
    for (final ch in moves.split('')) {
      final d = Direction.fromChar(ch)!;
      final (pr, pc) = cells.last;
      cells.add((pr + d.dy, pc + d.dx));
    }
    return ArrowLine(id: id, cells: cells);
  }
}
