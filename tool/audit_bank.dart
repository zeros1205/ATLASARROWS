/// Audits the live problem bank: regenerates every campaign stage exactly as
/// CampaignRepository does and reports density, line counts, solvability and
/// generation cost. Usage: dart run tool/audit_bank.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

void main() {
  final data = jsonDecode(
      File('assets/campaign/campaign.json').readAsStringSync()) as Map<String, dynamic>;
  final countries = (data['countries'] as List).cast<Map<String, dynamic>>();

  var stages = 0, unsolvable = 0, thinLines = 0;
  final fillRatios = <double>[];
  final lineCounts = <int>[];
  final pathFill = <double>[];
  final finaleFill = <double>[];
  final slow = <String>[];
  final sw = Stopwatch()..start();

  for (final e in countries) {
    final grid = (e['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++)
          if (grid[r][c] == '#') (r, c),
    };
    final rank = e['rank'] as int;
    final base = rank * 1000;
    final stageCount = math.max(10, 0 * 2 + 1); // no baked cities -> 10
    for (var local = 0; local < stageCount; local++) {
      final fill = (0.80 + 0.02 * local).clamp(0.80, 0.96);
      final isFinale = local == stageCount - 1;
      final t = Stopwatch()..start();
      final Level lvl;
      if (isFinale) {
        lvl = generateLevel(
            rows: grid.length,
            cols: grid[0].length,
            mask: mask,
            seed: base + 900,
            fill: 0.92,
            maxLen: 13);
      } else {
        final span = (stageCount - 1).clamp(1, 1 << 30);
        final side = 7 + (local * 4 / span).round();
        lvl = generateLevel(
            rows: side,
            cols: side,
            mask: BoardMasks.rect(side, side),
            seed: base + local,
            fill: fill,
            maxLen: 8 + local);
      }
      t.stop();
      if (t.elapsedMilliseconds > 120) {
        slow.add('${e['name']} s$local ${t.elapsedMilliseconds}ms '
            'mask=${lvl.mask.length}');
      }
      final cells = lvl.lines.fold<int>(0, (a, l) => a + l.cells.length);
      final ratio = cells / lvl.mask.length;
      fillRatios.add(ratio);
      lineCounts.add(lvl.lines.length);
      (isFinale ? finaleFill : pathFill).add(ratio);
      if (lvl.lines.length < 10) thinLines++;
      if (!BoardLogic.isSolvable(lvl)) {
        unsolvable++;
        stdout.writeln('UNSOLVABLE ${e['name']} stage $local');
      }
      stages++;
    }
  }
  sw.stop();

  String stat(List<num> xs) {
    final s = [...xs]..sort();
    String q(double p) => s[(s.length * p).clamp(0, s.length - 1).toInt()]
        .toStringAsFixed(3);
    return 'min=${s.first.toStringAsFixed(3)} p10=${q(0.1)} med=${q(0.5)} '
        'p90=${q(0.9)} max=${s.last.toStringAsFixed(3)}';
  }

  stdout.writeln('stages=$stages  unsolvable=$unsolvable  '
      '<10 lines=$thinLines  total=${sw.elapsedMilliseconds}ms');
  stdout.writeln('fill(actual)  ${stat(fillRatios)}');
  stdout.writeln('  path        ${stat(pathFill)}');
  stdout.writeln('  finale      ${stat(finaleFill)}');
  stdout.writeln('lines/board   ${stat(lineCounts)}');
  stdout.writeln('slow boards (>120ms): ${slow.length}');
  for (final s in slow.take(10)) {
    stdout.writeln('  $s');
  }
}
