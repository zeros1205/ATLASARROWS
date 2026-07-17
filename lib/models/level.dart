import 'arrow_line.dart';

/// An immutable level: a bounding grid, a silhouette mask (the cells that
/// belong to the board — need not be rectangular), and the arrow lines.
class Level {
  Level._(this.rows, this.cols, this.mask, this.lines);

  factory Level.fromLines({
    required int rows,
    required int cols,
    required Set<(int, int)> mask,
    required List<ArrowLine> lines,
  }) {
    final seen = <(int, int)>{};
    for (final line in lines) {
      for (final cell in line.cells) {
        final (r, c) = cell;
        assert(
          r >= 0 && r < rows && c >= 0 && c < cols,
          'line ${line.id} cell $cell out of ${rows}x$cols board',
        );
        assert(mask.contains(cell),
            'line ${line.id} cell $cell outside the board mask');
        assert(seen.add(cell),
            'line ${line.id} overlaps another line at $cell');
      }
    }
    assert(lines.isNotEmpty, 'level has no lines');
    return Level._(
      rows,
      cols,
      Set.unmodifiable(mask),
      List.unmodifiable(lines),
    );
  }

  /// Rectangular-mask convenience used by tests and hand-authored levels.
  /// Line specs use the `"r,c:MOVES"` format of [ArrowLine.parse].
  factory Level.parse({
    required int rows,
    required int cols,
    required List<String> lineSpecs,
  }) {
    return Level.fromLines(
      rows: rows,
      cols: cols,
      mask: {
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++) (r, c),
      },
      lines: [
        for (var i = 0; i < lineSpecs.length; i++)
          ArrowLine.parse(i, lineSpecs[i]),
      ],
    );
  }

  final int rows;
  final int cols;
  final Set<(int, int)> mask;
  final List<ArrowLine> lines;
}
