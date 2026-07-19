/// Difficulty proxy per stage slot: average branching factor (how many lines
/// are escapable at each step of a solve). Low = tight/forced = hard.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

double branching(Level lvl) {
  final b = BoardLogic.fromLevel(lvl);
  var steps = 0; var sum = 0;
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
  final byLocal = List.generate(10, (_) => <double>[]);
  final linesByLocal = List.generate(10, (_) => <int>[]);
  for (final e in cs.cast<Map<String, dynamic>>()) {
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++) if (grid[r][c] == '#') (r, c)};
    final base = (e['rank'] as int) * 1000;
    for (var local = 0; local < 10; local++) {
      final fill = (0.80 + 0.02 * local).clamp(0.80, 0.96);
      final Level lvl;
      if (local == 9) {
        lvl = generateLevel(rows: grid.length, cols: grid[0].length, mask: mask,
            seed: base + 900, fill: 0.92, maxLen: 13);
      } else {
        final side = 7 + (local * 4 / 9).round();
        lvl = generateLevel(rows: side, cols: side, mask: BoardMasks.rect(side, side),
            seed: base + local, fill: fill, maxLen: 8 + local);
      }
      byLocal[local].add(branching(lvl));
      linesByLocal[local].add(lvl.lines.length);
    }
  }
  for (var i = 0; i < 10; i++) {
    final b = byLocal[i]; final l = linesByLocal[i];
    final bm = b.reduce((a, x) => a + x) / b.length;
    final lm = l.reduce((a, x) => a + x) / l.length;
    stdout.writeln('stage $i  lines=${lm.toStringAsFixed(1)}  '
        'branching=${bm.toStringAsFixed(2)}  '
        'forced%=${(b.where((x) => x < 1.5).length * 100 / b.length).toStringAsFixed(0)}');
  }
  math.max(0, 0);
}
