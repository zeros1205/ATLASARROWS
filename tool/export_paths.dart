/// Builds the "path" pool — the puzzle that sits between a round's landmark
/// stages ("path to the next place"). These are basic geometric boards, not
/// silhouettes; the landmarks carry the scenery. The three shapes are mixed
/// in equal thirds so consecutive paths do not read as the same board twice.
///
/// One path per landmark board, sized off that board: 15–20% fewer arrows.
/// So a path always reads as a lighter run-up to the landmark it leads to,
/// and the pool inherits the campaign ramp without a second difficulty curve.
library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

const easeLo = 0.80; // 20% fewer arrows than the landmark board
const easeHi = 0.85; // 15% fewer
const tolerance = 0.10;
const maxLen = 20;

/// Average arrow length rises with the board's arrow count: a small path is
/// made of short stubs, a big one threads long corridors through the board.
///
/// This has to be driven by the mix, not by the board size. A fixed mix holds
/// its realised average flat no matter how big the grid gets — `shorter` even
/// drifts DOWN, 3.50 on 14x14 to 3.25 on 38x38 — because the length
/// distribution, not the room available, is what decides it.
///
/// Weights are interpolated rather than picked from presets so the ramp is
/// smooth across the pool's 55–305 arrow range.
double ramp(int want) => ((want - 60) / 220).clamp(0.0, 1.0);

LenMix mixFor(int want) {
  final t = ramp(want);
  final long = 0.06 + 0.58 * t;   // .06 -> .64
  final short = 0.58 - 0.44 * t;  // .58 -> .14
  return (short: short, mid: 1.0 - short - long, long: long);
}

/// The floor rides the same ramp — a 60-arrow path is meant to be made of
/// stubs, so holding it to the same average as a 280-arrow one would undo
/// the ramp entirely.
double minAvgFor(int want) => 3.3 + 1.1 * ramp(want);

/// Fallbacks when a board comes out below [minAvgLen] — each step lengthens.
const ladder = [
  (LenMixes.balanced, '4.1'),
  (LenMixes.longer, '4.9'),
];

double avgOf(Level l) =>
    l.lines.fold<int>(0, (a, x) => a + x.cells.length) / l.lines.length;

/// Equal thirds. An ellipse fills ~79% of its grid and a diamond ~53%, so a
/// given arrow count needs a bigger grid for the rounder shapes — the size
/// search below handles that on its own, no per-shape correction needed.
enum PathShape { rect, ellipse, diamond }

Set<(int, int)> maskFor(PathShape shape, int rows, int cols) =>
    switch (shape) {
      PathShape.rect => BoardMasks.rect(rows, cols),
      PathShape.ellipse => BoardMasks.ellipse(rows, cols),
      PathShape.diamond => BoardMasks.diamond(rows, cols),
    };

Level gen(PathShape shape, int rows, int cols, int seed, LenMix mix) =>
    generateLevel(
      rows: rows,
      cols: cols,
      mask: maskFor(shape, rows, cols),
      seed: seed,
      fill: 0.92,
      maxLen: maxLen,
      lenMix: mix,
    );

String encode(List<(int, int)> cells) {
  final b = StringBuffer('${cells.first.$1},${cells.first.$2}:');
  for (var i = 1; i < cells.length; i++) {
    final dr = cells[i].$1 - cells[i - 1].$1, dc = cells[i].$2 - cells[i - 1].$2;
    b.write(dr == -1 ? 'U' : dr == 1 ? 'D' : dc == -1 ? 'L' : 'R');
  }
  return b.toString();
}

/// Solves for the near-square board that lands [want] arrows.
///
/// Bisection, not a secant step. Arrows rise with area for a fixed mix and
/// seed, but not smoothly: the `longer` mix realises an average length of
/// 5.3 on a 29x31 board and 4.1 on a 35x36 one, so the same 40% more area
/// can double the arrow count. A secant update oscillated between the two
/// sides of the target and settled on whichever it happened to try first.
///
/// The board is near-square rather than strictly square. A square only steps
/// in whole sides, and one side costs 8–15 arrows, so plenty of targets are
/// unreachable; letting rows and cols differ by a row halves the step.
(Level, int, int, String) build(PathShape shape, int want, int seed) {
  final lo = (want * (1 - tolerance)).round();
  final hi = (want * (1 + tolerance)).round();
  final mix = (mixFor(want), 'ramp');

  (int, int) gridFor(int a) {
    final side = sqrt(a).floor().clamp(6, 64);
    final other = (a / side).round().clamp(6, 64);
    return (min(side, other), max(side, other));
  }

  Level? best;
  var bestRows = 6, bestCols = 6;
  Level probe(int area) {
    final (r, c) = gridFor(area);
    final cand = gen(shape, r, c, seed, mix.$1);
    final n = cand.lines.length;
    if (best == null || (n - want).abs() < (best!.lines.length - want).abs()) {
      best = cand;
      bestRows = r;
      bestCols = c;
    }
    return cand;
  }

  // Bracket the target, then close in.
  var loArea = 36, hiArea = 4096;
  final density = switch (shape) {
    PathShape.rect => 1.0,
    PathShape.ellipse => 0.79,
    PathShape.diamond => 0.53,
  };
  final seed0 = max(36, (want * 4.0 / 0.92 / density).round());
  final first = probe(seed0).lines.length;
  if (first >= lo && first <= hi) return (best!, bestRows, bestCols, mix.$2);
  if (first < want) {
    loArea = seed0;
  } else {
    hiArea = seed0;
  }
  for (var i = 0; i < 9 && hiArea - loArea > 8; i++) {
    final mid = (loArea + hiArea) ~/ 2;
    final n = probe(mid).lines.length;
    if (n >= lo && n <= hi) break;
    if (n < want) {
      loArea = mid;
    } else {
      hiArea = mid;
    }
  }

  // Average length is a property of the mix, not the size — swap the mix up
  // only if the chosen board came out short for its position on the ramp.
  final floor = minAvgFor(want);
  if (avgOf(best!) < floor) {
    for (var m = 0; m < ladder.length; m++) {
      final cand = gen(shape, bestRows, bestCols, seed, ladder[m].$1);
      if (avgOf(cand) >= floor &&
          (cand.lines.length - want).abs() <= want * tolerance) {
        return (cand, bestRows, bestCols, ladder[m].$2);
      }
    }
  }
  return (best!, bestRows, bestCols, mix.$2);
}

void main() {
  final boards = (jsonDecode(
          File('tools/atlas/all_boards.json').readAsStringSync())
      as Map<String, dynamic>)['boards'] as List;
  final out = <Map<String, dynamic>>[];
  var done = 0;

  for (final b in boards.cast<Map<String, dynamic>>()) {
    final base = b['arrows'] as int;
    // Alternate across the 15–20% band so consecutive rounds differ.
    final t = (out.length % 5) / 4.0;
    final want = (base * (easeHi - (easeHi - easeLo) * t)).round();
    final seed = (b['kind'] == 'country' ? 300000 : 700000) +
        (b['rank'] as int) * 131;
    // Equal thirds, cycling so a round never repeats a shape back to back.
    final shape = PathShape.values[out.length % 3];
    final (lvl, rows, cols, mix) = build(shape, want, seed);
    final lens = lvl.lines.map((l) => l.cells.length).toList()..sort();
    out.add({
      'kind': b['kind'],
      'shape': shape.name,
      'for': b['name'],
      'ko': b['ko'],
      'rank': b['rank'],
      'rows': rows,
      'cols': cols,
      'cells': lvl.mask.length,
      'want': want,
      'arrows': lvl.lines.length,
      'landmarkArrows': base,
      'ratio':
          double.parse((lvl.lines.length / base * 100).toStringAsFixed(1)),
      'lmin': lens.first,
      'lmax': lens.last,
      'lavg': double.parse(
          (lens.reduce((a, b) => a + b) / lens.length).toStringAsFixed(1)),
      'mix': mix,
      'solvable': BoardLogic.isSolvable(lvl),
      'lines': [for (final l in lvl.lines) encode(l.cells)],
    });
    done++;
    if (done % 100 == 0) stdout.writeln('  $done/${boards.length}...');
  }

  final f = File('tools/atlas/path_boards.json')
    ..writeAsStringSync(jsonEncode({'paths': out}));

  final byShape = <String, int>{};
  for (final p in out) {
    byShape[p['shape'] as String] = (byShape[p['shape'] as String] ?? 0) + 1;
  }

  void report(String kind) {
    final s = out.where((p) => p['kind'] == kind).toList();
    final a = s.map((p) => p['arrows'] as int).toList()..sort();
    final r = s.map((p) => p['ratio'] as double).toList()..sort();
    stdout.writeln('${kind == 'country' ? '국가' : '도시'}용 path ${s.length}개');
    stdout.writeln('  화살 ${a.first}~${a.last} (중앙 ${a[a.length ~/ 2]})');
    stdout.writeln('  랜드마크 대비 ${r.first}~${r.last}% '
        '(중앙 ${r[r.length ~/ 2]}%)');
  }

  stdout.writeln('총 ${out.length}개 · 풀림 '
      '${out.every((p) => p['solvable'] as bool)}');
  report('country');
  report('city');
  final off = out
      .where((p) =>
          ((p['arrows'] as int) - (p['want'] as int)).abs() >
          (p['want'] as int) * tolerance)
      .length;
  stdout.writeln('형상: ${byShape.entries.map((e) => '${e.key} ${e.value}').join(' · ')}');
  stdout.writeln('목표 밖 $off개 · ${(f.lengthSync() / 1024).toStringAsFixed(0)} KB');
}
