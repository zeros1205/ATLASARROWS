/// Does the board fall to a mindless rim sweep? Two things are measured:
///
///  1. Bias — do arrows near the mask edge point OUTWARD more often than
///     chance? The generator picks the shallower end as the head so the exit
///     ray runs outward, which would produce exactly that.
///  2. Exploitability — can a player clear the board by repeatedly walking
///     the rim and tapping whatever is there, never looking at the interior?
library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/arrow_line.dart';
import 'package:atlas_arrows/models/level.dart';

/// BFS distance of every mask cell from the silhouette boundary.
Map<(int, int), int> depths(Set<(int, int)> mask) {
  final d = <(int, int), int>{};
  final q = <(int, int)>[];
  for (final cell in mask) {
    final (r, c) = cell;
    if ([(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
        .any((n) => !mask.contains(n))) {
      d[cell] = 0;
      q.add(cell);
    }
  }
  for (var i = 0; i < q.length; i++) {
    final (r, c) = q[i];
    for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
      if (mask.contains(n) && !d.containsKey(n)) {
        d[n] = d[(r, c)]! + 1;
        q.add(n);
      }
    }
  }
  return d;
}

/// Is the head aimed at the nearer side of the board on its axis?
bool pointsOutward(ArrowLine l, int rows, int cols) {
  final (hr, hc) = l.head;
  final d = l.headDir;
  if (d.dy != 0) return d.dy < 0 ? hr < rows - 1 - hr : (rows - 1 - hr) < hr;
  return d.dx < 0 ? hc < cols - 1 - hc : (cols - 1 - hc) < hc;
}

void main() {
  final boards = (jsonDecode(
          File('tools/atlas/all_boards.json').readAsStringSync())
      as Map<String, dynamic>)['boards'] as List;

  var rimOut = 0, rimTot = 0, coreOut = 0, coreTot = 0;
  final sweepCleared = <double>[];
  final sweepTapsNeeded = <double>[];

  for (final b in boards.cast<Map<String, dynamic>>()) {
    final grid = (b['grid'] as List).cast<String>();
    final rows = grid.length, cols = grid[0].length;
    final mask = <(int, int)>{
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++) if (grid[r][c] == '#') (r, c)};
    final dep = depths(mask);

    final lines = <ArrowLine>[];
    var id = 0;
    for (final spec in (b['lines'] as List).cast<String>()) {
      lines.add(ArrowLine.parse(id++, spec));
    }
    final lvl = Level.fromLines(
        rows: rows, cols: cols, mask: mask, lines: lines);

    for (final l in lines) {
      final near = (dep[l.head] ?? 0) <= 1;
      final out = pointsOutward(l, rows, cols);
      if (near) {
        rimTot++;
        if (out) rimOut++;
      } else {
        coreTot++;
        if (out) coreOut++;
      }
    }

    // Rim sweep: only ever tap arrows whose head sits on the outer shell.
    // Repeat laps until a full lap removes nothing.
    final board = BoardLogic.fromLevel(lvl);
    final total = lines.length;
    var taps = 0;
    var progress = true;
    while (progress && !board.isCleared) {
      progress = false;
      final rim = [
        for (final e in board.lines.entries)
          if ((dep[e.value.head] ?? 99) <= 1) e.key
      ]..sort((a, b) {
          final ha = board.lines[a]!.head, hb = board.lines[b]!.head;
          final aa = atan2(ha.$1 - rows / 2, ha.$2 - cols / 2);
          final ab = atan2(hb.$1 - rows / 2, hb.$2 - cols / 2);
          return aa.compareTo(ab);
        });
      for (final k in rim) {
        if (!board.lines.containsKey(k)) continue;
        taps++;
        if (board.tap(k) is MoveEscaped) {
          board.removeLine(k);
          progress = true;
        }
      }
    }
    sweepCleared.add((total - board.lines.length) / total);
    sweepTapsNeeded.add(taps / total);
  }

  double mean(List<double> x) => x.reduce((a, b) => a + b) / x.length;
  final full = sweepCleared.where((x) => x >= 0.999).length;

  stdout.writeln('보드 ${boards.length}개');
  stdout.writeln('');
  stdout.writeln('[1] 바깥을 향하는 화살 비율');
  stdout.writeln('  테두리(깊이 0~1) : ${(rimOut * 100 / rimTot).toStringAsFixed(1)}%'
      '  ($rimOut / $rimTot)');
  stdout.writeln('  안쪽            : ${(coreOut * 100 / coreTot).toStringAsFixed(1)}%'
      '  ($coreOut / $coreTot)');
  stdout.writeln('  (무작위라면 둘 다 50%)');
  stdout.writeln('');
  stdout.writeln('[2] 테두리만 훑는 전략');
  stdout.writeln('  평균 제거율     : ${(mean(sweepCleared) * 100).toStringAsFixed(1)}%');
  stdout.writeln('  완전히 클리어됨 : $full / ${boards.length}개 보드');
  stdout.writeln('  화살 1개당 탭수 : ${mean(sweepTapsNeeded).toStringAsFixed(2)}');
}
