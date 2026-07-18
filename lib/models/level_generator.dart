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

  // Depth = BFS distance from the mask boundary. Lines are started at the
  // deepest empty cells first: a line inserted early only needs its exit
  // ray to avoid the few lines already placed, so the interior must be
  // populated before the outer shells wall it in.
  final depth = <(int, int), int>{};
  final bfs = <(int, int)>[];
  for (final cell in mask) {
    final (r, c) = cell;
    final edge = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
        .any((n) => !mask.contains(n));
    if (edge) {
      depth[cell] = 0;
      bfs.add(cell);
    }
  }
  for (var i = 0; i < bfs.length; i++) {
    final (r, c) = bfs[i];
    final d = depth[(r, c)]!;
    for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
      if (mask.contains(n) && !depth.containsKey(n)) {
        depth[n] = d + 1;
        bfs.add(n);
      }
    }
  }

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

  while (occupied.length < target && failures < 800) {
    // Only cells that still have an empty neighbor can host a line —
    // isolated singles can never be filled and must not eat the budget.
    final empties = [
      for (final cell in mask)
        if (!occupied.contains(cell) &&
            [
              (cell.$1 - 1, cell.$2),
              (cell.$1 + 1, cell.$2),
              (cell.$1, cell.$2 - 1),
              (cell.$1, cell.$2 + 1),
            ].any((n) => mask.contains(n) && !occupied.contains(n)))
          cell,
    ];
    if (empties.isEmpty) break;
    empties.sort((a, b) => depth[b]!.compareTo(depth[a]!));
    final band = min(8, empties.length);
    var cur = rng.nextDouble() < 0.6
        ? empties[rng.nextInt(band)]
        : empties[rng.nextInt(empties.length)];
    final path = [cur];
    final used = {cur};
    Direction? lastDir;
    final targetLen = sampleLen();
    while (path.length < targetLen) {
      final options = <(Direction, (int, int))>[];
      for (final d in Direction.values) {
        final next = (cur.$1 + d.dy, cur.$2 + d.dx);
        if (mask.contains(next) &&
            !occupied.contains(next) &&
            !used.contains(next)) {
          options.add((d, next));
        }
      }
      if (options.isEmpty) break;
      options.shuffle(rng);
      // Bias toward straight runs so the maze reads as corridors, then
      // toward deeper cells so walks consume pockets from the inside out
      // instead of snaking outward and walling them off.
      (Direction, (int, int))? pick;
      if (lastDir != null && rng.nextDouble() < 0.6) {
        for (final o in options) {
          if (o.$1 == lastDir) pick = o;
        }
      }
      if (pick == null && rng.nextDouble() < 0.7) {
        pick = options
            .reduce((a, b) => depth[a.$2]! >= depth[b.$2]! ? a : b);
      }
      pick ??= options.first;
      path.add(pick.$2);
      used.add(pick.$2);
      cur = pick.$2;
      lastDir = pick.$1;
    }
    if (path.length < 2) {
      failures++;
      continue;
    }
    // Either end may serve as the head; try the shallower end first so
    // the exit ray runs outward across still-empty shells.
    final fwd = path;
    final rev = path.reversed.toList();
    final candidates = depth[path.last]! <= depth[path.first]!
        ? [fwd, rev]
        : [rev, fwd];
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

  // Exit-ray cells of an oriented line, out to the bounding-box edge.
  List<(int, int)> rayCells(List<(int, int)> line) {
    final (r1, c1) = line[line.length - 2];
    final (r2, c2) = line.last;
    final dr = r2 - r1;
    final dc = c2 - c1;
    var r = r2 + dr;
    var c = c2 + dc;
    final out = <(int, int)>[];
    while (inBounds(r, c)) {
      out.add((r, c));
      r += dr;
      c += dc;
    }
    return out;
  }

  // Repair passes — fill every remaining hole while preserving the
  // reverse-removal invariant (line i's exit ray avoids lines 0..i-1):
  //
  //  (a) stubs: 2-cell arrows appended last wherever a ray is still clear
  //  (b) splice: a hole-line L can go at ANY position k in the insertion
  //      order, provided k is after every line whose ray L's cells would
  //      block (they must precede L) and before every line sitting on
  //      L's own ray (L must precede them). Feasible iff maxBlocked <
  //      minBlocker; splice at maxBlocked + 1.
  //  (c) tail growth: an isolated single is absorbed by extending an
  //      adjacent line's tail onto it, allowed when no later-inserted
  //      line's ray crosses the cell (the head and its ray are untouched).
  const maxGrown = 16;
  var progressed = true;
  while (progressed) {
    progressed = false;

    final rays = [for (final line in oriented) rayCells(line).toSet()];
    final cellOwner = <(int, int), int>{
      for (var i = 0; i < oriented.length; i++)
        for (final cell in oriented[i]) cell: i,
    };

    bool splice(List<(int, int)> cand) {
      var maxBlocked = -1;
      for (var i = 0; i < oriented.length; i++) {
        if (cand.any(rays[i].contains)) maxBlocked = max(maxBlocked, i);
      }
      var minBlocker = oriented.length;
      for (final cell in rayCells(cand)) {
        final owner = cellOwner[cell];
        if (owner != null) minBlocker = min(minBlocker, owner);
      }
      if (maxBlocked >= minBlocker) return false;
      oriented.insert(maxBlocked + 1, cand);
      occupied.addAll(cand);
      return true;
    }

    for (final cell in mask) {
      if (occupied.contains(cell)) continue;
      final (r, c) = cell;
      var done = false;
      for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
        if (!mask.contains(n) || occupied.contains(n)) continue;
        done = splice([cell, n]) || splice([n, cell]);
        if (done) break;
      }
      if (!done) {
        // isolated single: grow an adjacent line's tail onto it
        for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
          final owner = cellOwner[n];
          if (owner == null ||
              oriented[owner].first != n ||
              oriented[owner].length >= maxGrown) {
            continue;
          }
          var crossed = false;
          for (var j = owner + 1; j < oriented.length && !crossed; j++) {
            crossed = rays[j].contains(cell);
          }
          if (crossed) continue;
          oriented[owner] = [cell, ...oriented[owner]];
          occupied.add(cell);
          done = true;
          break;
        }
      }
      if (done) {
        progressed = true;
        break; // structures are stale — rebuild and rescan
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
