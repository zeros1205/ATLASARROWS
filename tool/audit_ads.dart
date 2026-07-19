/// Finds the arrow count that maximizes ad impressions without wrecking the
/// session. Hearts=3; each depletion is one rewarded-ad wall (progress is
/// kept, so the player continues rather than restarting).
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
  final rng = Random(3);
  stdout.writeln('정사각 보드를 크기별로 생성 → 실수/광고벽 측정 (플레이어=3칸 확인)');
  stdout.writeln('한변  화살  판당실수  광고벽  1회이상  판당탭  추정시간');
  for (var side = 7; side <= 20; side++) {
    var lines = 0.0, mist = 0.0, walls = 0.0, any = 0.0, taps = 0.0;
    const seeds = 40;
    for (var s = 0; s < seeds; s++) {
      final lvl = generateLevel(
          rows: side, cols: side, mask: BoardMasks.rect(side, side),
          seed: 50000 + side * 100 + s, fill: 0.90, maxLen: 12);
      lines += lvl.lines.length;
      var m = 0, t = 0;
      const runs = 4;
      for (var i = 0; i < runs; i++) {
        final (mm, tt) = play(lvl, 3, rng);
        m += mm; t += tt;
      }
      final avgM = m / runs;
      mist += avgM;
      walls += avgM ~/ 3;          // 하트 3개 소진 = 광고벽 1회
      any += avgM >= 3 ? 1 : 0;
      taps += t / runs;
    }
    final secs = taps / seeds * 1.5;
    stdout.writeln('${side.toString().padLeft(3)}  '
        '${(lines / seeds).toStringAsFixed(0).padLeft(5)}  '
        '${(mist / seeds).toStringAsFixed(1).padLeft(8)}  '
        '${(walls / seeds).toStringAsFixed(2).padLeft(6)}  '
        '${(any / seeds * 100).toStringAsFixed(0).padLeft(6)}%  '
        '${(taps / seeds).toStringAsFixed(0).padLeft(6)}  '
        '${secs.toStringAsFixed(0).padLeft(6)}초');
  }
}
