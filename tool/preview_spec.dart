/// Renders real campaign masks at the spec's cell-count boundaries into JSON
/// for visual review: 80 (normal 하한) / 130 (normal 상한) / 200 (boss 상한).
library;

import 'dart:convert';
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

double branching(Level lvl) {
  final b = BoardLogic.fromLevel(lvl);
  var steps = 0, sum = 0;
  while (!b.isCleared) {
    final free = [for (final id in b.lines.keys) if (b.tap(id) is MoveEscaped) id];
    if (free.isEmpty) break;
    sum += free.length; steps++;
    b.removeLine(free.first);
  }
  return steps == 0 ? 0 : sum / steps;
}

void main() {
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  final rng = Random(2026);
  final out = <Map<String, dynamic>>[];

  for (final want in [80, 130, 200]) {
    Map<String, dynamic>? best;
    for (final e in cs.cast<Map<String, dynamic>>()) {
      if (best == null ||
          ((e['cells'] as int) - want).abs() < ((best['cells'] as int) - want).abs()) {
        best = e;
      }
    }
    final e = best!;
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++) if (grid[r][c] == '#') (r, c)};
    final lvl = generateLevel(rows: grid.length, cols: grid[0].length,
        mask: mask, seed: 20260719 + want, fill: 0.90, maxLen: 12);
    var m = 0;
    const runs = 40;
    for (var i = 0; i < runs; i++) {
      m += mistakes(lvl, 3, rng);
    }
    final avgLen =
        lvl.lines.fold<int>(0, (a, l) => a + l.cells.length) / lvl.lines.length;
    out.add({
      'target': want,
      'name': e['name'], 'ko': e['ko'], 'cells': e['cells'],
      'rows': lvl.rows, 'cols': lvl.cols,
      'mask': grid,
      'arrows': lvl.lines.length,
      'avgLen': double.parse(avgLen.toStringAsFixed(1)),
      'branching': double.parse(branching(lvl).toStringAsFixed(1)),
      'mistakes': double.parse((m / runs).toStringAsFixed(2)),
      'lines': [for (final l in lvl.lines) [for (final (r, c) in l.cells) [r, c]]],
    });
    stdout.writeln('$want셀 -> ${e['ko']} ${e['cells']}셀 '
        '${lvl.rows}x${lvl.cols} 화살${lvl.lines.length}개 '
        '평균길이${avgLen.toStringAsFixed(1)} 실수${(m / runs).toStringAsFixed(2)}');
  }
  File('tools/atlas/preview_spec.json')
      .writeAsStringSync(jsonEncode({'boards': out}));
  stdout.writeln('-> tools/atlas/preview_spec.json');
}
