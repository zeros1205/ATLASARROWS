library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

int mistakes(Level lvl, int d, Random rng) {
  final b = BoardLogic.fromLevel(lvl);
  var m = 0, g = 0;
  while (!b.isCleared && g++ < 40000) {
    final ids = b.lines.keys.toList();
    final ok = <int>[];
    for (final id in ids) {
      final good = switch (b.tap(id)) {
        MoveEscaped() => true,
        MoveBlocked(:final freeSteps) => freeSteps >= d,
      };
      if (good) ok.add(id);
    }
    final pool = ok.isEmpty ? ids : ok;
    final p = pool[rng.nextInt(pool.length)];
    if (b.tap(p) is MoveEscaped) { b.removeLine(p); } else { m++; }
  }
  return m;
}

void main() {
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  final rng = Random(99);
  stdout.writeln('마스크         셀   요청fill  실제fill 화살  실수');
  for (final want in [80, 130, 200]) {
    Map<String, dynamic>? best;
    for (final e in cs.cast<Map<String, dynamic>>()) {
      if (best == null || ((e['cells'] as int) - want).abs() < ((best['cells'] as int) - want).abs()) best = e;
    }
    final e = best!;
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++) if (grid[r][c] == '#') (r, c)};
    for (final f in [0.75, 0.85, 0.95]) {
      final lvl = generateLevel(rows: grid.length, cols: grid[0].length,
          mask: mask, seed: 777 + want, fill: f, maxLen: 12);
      var m = 0;
      for (var i = 0; i < 30; i++) { m += mistakes(lvl, 3, rng); }
      final used = lvl.lines.fold<int>(0, (a, l) => a + l.cells.length);
      stdout.writeln('${(e['ko'] as String).padRight(8)} ${(e['cells'] as int).toString().padLeft(5)}  '
          '${f.toStringAsFixed(2).padLeft(7)}  ${(used / mask.length).toStringAsFixed(3).padLeft(7)} '
          '${lvl.lines.length.toString().padLeft(4)}  ${(m / 30).toStringAsFixed(2).padLeft(5)}');
    }
  }
}
