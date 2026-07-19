/// Measures the monetization engine: how often does a player tap a BLOCKED
/// arrow? Simulates three personas per stage and reports mistakes-per-stage
/// against the 3-heart budget.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

/// scanDepth = how many ray cells the player bothers to check before tapping.
/// 0 = taps blind. 99 = checks the whole ray (perfect play, never errs).
(int, int) play(Level lvl, int scanDepth, Random rng) {
  final b = BoardLogic.fromLevel(lvl);
  var mistakes = 0, taps = 0, guard = 0;
  while (!b.isCleared && guard++ < 20000) {
    final ids = b.lines.keys.toList();
    // Player picks among arrows that LOOK clear as far as they checked.
    final looksOk = <int>[];
    for (final id in ids) {
      final r = b.tap(id);
      final ok = switch (r) {
        MoveEscaped() => true,
        MoveBlocked(:final freeSteps) => freeSteps >= scanDepth,
      };
      if (ok) looksOk.add(id);
    }
    final pick = (looksOk.isEmpty ? ids : looksOk)[
        rng.nextInt(looksOk.isEmpty ? ids.length : looksOk.length)];
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
  final rng = Random(7);
  // persona: 이름, 확인하는 광선 칸수
  const personas = [('생각없이 탭', 0), ('두세칸만 확인', 3), ('대충 훑음', 6)];

  for (final (label, depth) in personas) {
    final perStage = <double>[];
    final failRate = <double>[];
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
        var mSum = 0, fails = 0;
        const runs = 5;
        for (var t = 0; t < runs; t++) {
          final (m, _) = play(lvl, depth, rng);
          mSum += m;
          if (m >= 3) fails++; // 하트 3개 소진
        }
        perStage.add(mSum / runs);
        failRate.add(fails / runs);
      }
    }
    perStage.sort();
    double q(List<double> s, double p) => s[(s.length * p).clamp(0, s.length - 1).toInt()];
    final mean = perStage.reduce((a, b) => a + b) / perStage.length;
    final fr = failRate.where((x) => x > 0).length / failRate.length;
    stdout.writeln('[$label] 스테이지당 실수 '
        '평균=${mean.toStringAsFixed(1)}  '
        '중앙=${q(perStage, 0.5).toStringAsFixed(1)}  '
        'p90=${q(perStage, 0.9).toStringAsFixed(1)}  '
        '| 하트3 소진(실패) 발생 스테이지=${(fr * 100).toStringAsFixed(0)}%');
  }
}
