/// How FAR away is the blocker? Near blocks are visible walls (player never
/// errs). Far blocks are "거의 나갈 뻔" illusions — the mistakes that feel
/// like the player's own fault and drive the heart economy.
library;

import 'dart:convert';
import 'dart:io';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

void main() {
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  final dist = <int, int>{};
  var blocked = 0, free = 0;
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
      // 판을 실제로 풀어나가며 매 상태의 막힘 거리를 전부 수집
      final b = BoardLogic.fromLevel(lvl);
      var guard = 0;
      while (!b.isCleared && guard++ < 5000) {
        int? next;
        for (final id in b.lines.keys) {
          switch (b.tap(id)) {
            case MoveEscaped():
              free++;
              next ??= id;
            case MoveBlocked(:final freeSteps):
              blocked++;
              dist[freeSteps] = (dist[freeSteps] ?? 0) + 1;
          }
        }
        if (next == null) break;
        b.removeLine(next);
      }
    }
  }
  final total = blocked + free;
  stdout.writeln('전체 탭 후보 $total  |  뺄 수 있음 $free (${free * 100 ~/ total}%)  '
      '막힘 $blocked (${blocked * 100 ~/ total}%)');
  stdout.writeln('막힘까지의 거리 분포:');
  var cum = 0;
  for (var d = 0; d <= 8; d++) {
    final n = dist[d] ?? 0;
    cum += n;
    stdout.writeln('  ${d.toString().padLeft(2)}칸 앞에서 막힘: '
        '${(n * 100 / blocked).toStringAsFixed(1)}%  (누적 ${(cum * 100 / blocked).toStringAsFixed(1)}%)');
  }
  final far = blocked - cum;
  stdout.writeln('  9칸 이상(착시 유발): ${(far * 100 / blocked).toStringAsFixed(1)}%');
}
