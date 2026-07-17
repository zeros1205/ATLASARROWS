import 'dart:math';

import 'arrow_line.dart';
import 'direction.dart';
import 'level.dart';

/// Silhouette masks for non-rectangular boards. Cells are (row, col).
abstract final class BoardMasks {
  static Set<(int, int)> rect(int rows, int cols) => {
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++) (r, c),
      };

  static Set<(int, int)> ellipse(int rows, int cols) => {
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            if (_inEllipse(r, c, (rows - 1) / 2, (cols - 1) / 2, rows / 2,
                cols / 2))
              (r, c),
      };

  static Set<(int, int)> diamond(int rows, int cols) => {
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            if ((r - (rows - 1) / 2).abs() / (rows / 2) +
                    (c - (cols - 1) / 2).abs() / (cols / 2) <=
                1.0)
              (r, c),
      };

  /// Organic blob: union of a few seeded, offset ellipses.
  static Set<(int, int)> blob(int rows, int cols, int seed) {
    final rng = Random(seed);
    final mask = <(int, int)>{};
    for (var i = 0; i < 3; i++) {
      final cy = rows * (0.3 + rng.nextDouble() * 0.4);
      final cx = cols * (0.3 + rng.nextDouble() * 0.4);
      final ry = rows * (0.28 + rng.nextDouble() * 0.22);
      final rx = cols * (0.28 + rng.nextDouble() * 0.22);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (_inEllipse(r, c, cy, cx, ry, rx)) mask.add((r, c));
        }
      }
    }
    return mask;
  }

  static bool _inEllipse(
      int r, int c, double cy, double cx, double ry, double rx) {
    final dy = (r - cy) / ry;
    final dx = (c - cx) / rx;
    return dy * dy + dx * dx <= 1.0;
  }
}

/// Generates a dense maze level inside [mask], solvable by construction:
/// lines are inserted one by one, and each line's straight exit ray must
/// avoid the cells of every line inserted BEFORE it — so removing lines
/// in reverse insertion order always clears the board. Cells outside the
/// mask are never occupied, so rays pass freely over them.
Level generateLevel({
  required int rows,
  required int cols,
  required Set<(int, int)> mask,
  required int seed,
  double fill = 0.88,
  int maxLen = 12,
}) {
  final rng = Random(seed);
  final occupied = <(int, int)>{};
  final oriented = <List<(int, int)>>[];
  final target = (mask.length * fill).floor();
  var failures = 0;

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  // The head's straight path off the board must avoid earlier lines.
  bool rayClear(List<(int, int)> path) {
    final (r1, c1) = path[path.length - 2];
    final (r2, c2) = path.last;
    final dr = r2 - r1;
    final dc = c2 - c1;
    var r = r2 + dr;
    var c = c2 + dc;
    while (inBounds(r, c)) {
      if (occupied.contains((r, c))) return false;
      r += dr;
      c += dc;
    }
    return true;
  }

  // Mixed lengths: plenty of short arrows (they drive the line count and
  // the scan difficulty), mid corridors, and a few long snakes.
  int sampleLen() {
    final x = rng.nextDouble();
    if (x < 0.38) return 2 + rng.nextInt(2); // 2–3
    if (x < 0.80) return 4 + rng.nextInt(3); // 4–6
    return 7 + rng.nextInt(max(1, maxLen - 6)); // 7–maxLen
  }

  while (occupied.length < target && failures < 500) {
    final empties = [
      for (final cell in mask)
        if (!occupied.contains(cell)) cell,
    ];
    if (empties.isEmpty) break;
    var cur = empties[rng.nextInt(empties.length)];
    final path = [cur];
    final used = {cur};
    Direction? lastDir;
    final targetLen = sampleLen();
    while (path.length < targetLen) {
      final dirs = [...Direction.values]..shuffle(rng);
      // Bias toward straight runs so the maze reads as corridors.
      if (lastDir != null && rng.nextDouble() < 0.6) {
        dirs
          ..remove(lastDir)
          ..insert(0, lastDir);
      }
      var moved = false;
      for (final d in dirs) {
        final next = (cur.$1 + d.dy, cur.$2 + d.dx);
        if (mask.contains(next) &&
            !occupied.contains(next) &&
            !used.contains(next)) {
          path.add(next);
          used.add(next);
          cur = next;
          lastDir = d;
          moved = true;
          break;
        }
      }
      if (!moved) break;
    }
    if (path.length < 2) {
      failures++;
      continue;
    }
    // Either end may serve as the head; keep whichever exits cleanly.
    final candidates = [path, path.reversed.toList()]..shuffle(rng);
    List<(int, int)>? chosen;
    for (final cand in candidates) {
      if (rayClear(cand)) {
        chosen = cand;
        break;
      }
    }
    if (chosen == null) {
      failures++;
      continue;
    }
    occupied.addAll(path);
    oriented.add(chosen);
    failures = 0;
  }

  // Stub pass: pack leftover gaps with 2-cell arrows wherever one still
  // has a clean exit — pushes density up and adds short-line variety.
  var progressed = true;
  while (progressed) {
    progressed = false;
    for (final cell in mask) {
      if (occupied.contains(cell)) continue;
      for (final d in Direction.values) {
        final next = (cell.$1 + d.dy, cell.$2 + d.dx);
        if (!mask.contains(next) || occupied.contains(next)) continue;
        List<(int, int)>? chosen;
        for (final cand in [
          [cell, next],
          [next, cell],
        ]) {
          if (rayClear(cand)) {
            chosen = cand;
            break;
          }
        }
        if (chosen != null) {
          occupied.addAll(chosen);
          oriented.add(chosen);
          progressed = true;
          break;
        }
      }
    }
  }

  return Level.fromLines(
    rows: rows,
    cols: cols,
    mask: mask,
    lines: [
      for (var i = 0; i < oriented.length; i++)
        ArrowLine(id: i, cells: oriented[i]),
    ],
  );
}
