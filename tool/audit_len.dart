/// What makes a fun board: how many arrows, and how long?
/// Sweeps board size x maxLen and reports the levers together.
library;

import 'dart:io';
import 'dart:math';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

int mistakes(Level lvl, int scanDepth, Random rng) {
  final b = BoardLogic.fromLevel(lvl);
  var m = 0, guard = 0;
  while (!b.isCleared && guard++ < 40000) {
    final ids = b.lines.keys.toList();
    final ok = <int>[];
    for (final id in ids) {
      final good = switch (b.tap(id)) {
        MoveEscaped() => true,
        MoveBlocked(:final freeSteps) => freeSteps >= scanDepth,
      };
      if (good) ok.add(id);
    }
    final pool = ok.isEmpty ? ids : ok;
    final pick = pool[rng.nextInt(pool.length)];
    if (b.tap(pick) is MoveEscaped) {
      b.removeLine(pick);
    } else {
      m++;
    }
  }
  return m;
}

/// 동시에 뺄 수 있는 화살 수(찾는 맛) — 낮을수록 뒤져야 한다.
double branching(Level lvl) {
  final b = BoardLogic.fromLevel(lvl);
  var steps = 0, sum = 0;
  while (!b.isCleared) {
    final free = [for (final id in b.lines.keys) if (b.tap(id) is MoveEscaped) id];
    if (free.isEmpty) break;
    sum += free.length;
    steps++;
    b.removeLine(free.first);
  }
  return steps == 0 ? 0 : sum / steps;
}

/// 광선이 자기 몸통 위를 지나는 화살 비율 — 막힌 것처럼 보이는 착시.
double selfCross(Level lvl) {
  var n = 0;
  for (final l in lvl.lines) {
    final (r1, c1) = l.cells[l.cells.length - 2];
    final (r2, c2) = l.cells.last;
    final dr = r2 - r1, dc = c2 - c1;
    var r = r2 + dr, c = c2 + dc;
    final own = l.cells.toSet();
    var hit = false;
    while (r >= 0 && r < lvl.rows && c >= 0 && c < lvl.cols) {
      if (own.contains((r, c))) { hit = true; break; }
      r += dr; c += dc;
    }
    if (hit) n++;
  }
  return n / lvl.lines.length;
}

void main() {
  final rng = Random(5);
  stdout.writeln('한변 maxLen | 화살 평균길이 | 동시제거 착시% | 판당실수 | 탭수(초)');
  for (final side in [9, 11, 13]) {
    for (final maxLen in [4, 6, 8, 12, 16, 22]) {
      var lines = 0.0, len = 0.0, br = 0.0, sc = 0.0, mi = 0.0;
      const seeds = 30;
      for (var s = 0; s < seeds; s++) {
        final lvl = generateLevel(
            rows: side, cols: side, mask: BoardMasks.rect(side, side),
            seed: 90000 + side * 1000 + maxLen * 10 + s, fill: 0.90, maxLen: maxLen);
        lines += lvl.lines.length;
        len += lvl.lines.fold<int>(0, (a, l) => a + l.cells.length) / lvl.lines.length;
        br += branching(lvl);
        sc += selfCross(lvl);
        var m = 0;
        for (var i = 0; i < 4; i++) {
          m += mistakes(lvl, 3, rng);
        }
        mi += m / 4;
      }
      final n = seeds.toDouble();
      final arrows = lines / n;
      stdout.writeln('${side.toString().padLeft(3)} '
          '${maxLen.toString().padLeft(6)} | '
          '${arrows.toStringAsFixed(0).padLeft(4)} '
          '${(len / n).toStringAsFixed(1).padLeft(6)} | '
          '${(br / n).toStringAsFixed(1).padLeft(6)} '
          '${(sc / n * 100).toStringAsFixed(0).padLeft(5)}% | '
          '${(mi / n).toStringAsFixed(1).padLeft(6)} | '
          '${(arrows * 1.5).toStringAsFixed(0).padLeft(5)}초');
    }
    stdout.writeln('');
  }
}
