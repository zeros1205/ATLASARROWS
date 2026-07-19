/// Measures planning depth: can a legal move ever be a mistake?
/// Taps a RANDOM escapable arrow every time (zero planning) and checks
/// whether the board still always clears.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level_generator.dart';

void main() {
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  final rng = Random(42);
  var trials = 0, cleared = 0;
  for (final e in cs.cast<Map<String, dynamic>>().take(60)) {
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++) if (grid[r][c] == '#') (r, c)};
    final lvl = generateLevel(rows: grid.length, cols: grid[0].length,
        mask: mask, seed: (e['rank'] as int) * 1000 + 900, fill: 0.92, maxLen: 13);
    for (var t = 0; t < 20; t++) {
      final b = BoardLogic.fromLevel(lvl);
      while (!b.isCleared) {
        final free = [for (final id in b.lines.keys) if (b.tap(id) is MoveEscaped) id];
        if (free.isEmpty) break;
        b.removeLine(free[rng.nextInt(free.length)]); // 아무거나 뺀다
      }
      trials++;
      if (b.isCleared) cleared++;
    }
  }
  stdout.writeln('무작위로 아무거나 뺀 시도: $trials회');
  stdout.writeln('그래도 클리어된 횟수: $cleared회 (${cleared * 100 ~/ trials}%)');
}
