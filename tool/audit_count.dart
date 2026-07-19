/// Does arrow count actually drive mistakes? Buckets every campaign stage by
/// line count and reports mistakes-per-stage, mistakes-per-tap, and taps.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

(int, int) play(Level lvl, int scanDepth, Random rng) {
  final b = BoardLogic.fromLevel(lvl);
  var mistakes = 0, taps = 0, guard = 0;
  while (!b.isCleared && guard++ < 40000) {
    final ids = b.lines.keys.toList();
    final looksOk = <int>[];
    for (final id in ids) {
      final ok = switch (b.tap(id)) {
        MoveEscaped() => true,
        MoveBlocked(:final freeSteps) => freeSteps >= scanDepth,
      };
      if (ok) looksOk.add(id);
    }
    final pool = looksOk.isEmpty ? ids : looksOk;
    final pick = pool[rng.nextInt(pool.length)];
    taps++;
    if (b.tap(pick) is MoveEscaped) {
      b.removeLine(pick);
    } else {
      mistakes++;
    }
  }
  return (mistakes, taps);
}

void main() {
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  final rng = Random(11);
  // 라인 수 구간 -> [실수합, 탭합, 판수]
  final buckets = <String, List<double>>{};
  const edges = [10, 15, 20, 30, 45, 70, 120, 999];
  String bucketOf(int n) {
    for (var i = 0; i < edges.length; i++) {
      if (n < edges[i]) return '${i == 0 ? 0 : edges[i - 1]}~${edges[i] - 1}';
    }
    return '${edges.last}+';
  }

  for (final e in cs.cast<Map<String, dynamic>>()) {
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++) if (grid[r][c] == '#') (r, c)};
    final base = (e['rank'] as int) * 1000;
    for (var local = 0; local < 10; local++) {
      final Level lvl;
      if (local == 9) {
        lvl = generateLevel(rows: grid.length, cols: grid[0].length, mask: mask,
            seed: base + 900, fill: 0.92, maxLen: 13);
      } else {
        final side = 7 + (local * 4 / 9).round();
        lvl = generateLevel(rows: side, cols: side, mask: BoardMasks.rect(side, side),
            seed: base + local, fill: (0.80 + 0.02 * local).clamp(0.80, 0.96),
            maxLen: 8 + local);
      }
      var m = 0, t = 0;
      const runs = 5;
      for (var i = 0; i < runs; i++) {
        final (mm, tt) = play(lvl, 3, rng);
        m += mm; t += tt;
      }
      final b = buckets.putIfAbsent(bucketOf(lvl.lines.length), () => [0, 0, 0]);
      b[0] += m / runs;
      b[1] += t / runs;
      b[2] += 1;
    }
  }

  stdout.writeln('플레이어 = 광선 3칸만 확인');
  stdout.writeln('라인수구간   판수   판당실수  판당탭수  탭당실수율');
  final keys = buckets.keys.toList()
    ..sort((a, b) => int.parse(a.split('~')[0].replaceAll('+', ''))
        .compareTo(int.parse(b.split('~')[0].replaceAll('+', ''))));
  for (final k in keys) {
    final v = buckets[k]!;
    final n = v[2];
    stdout.writeln('${k.padRight(11)} ${n.toInt().toString().padLeft(5)} '
        '${(v[0] / n).toStringAsFixed(2).padLeft(9)} '
        '${(v[1] / n).toStringAsFixed(1).padLeft(9)} '
        '${(v[0] / v[1] * 100).toStringAsFixed(1).padLeft(9)}%');
  }
}
