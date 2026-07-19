/// Onboarding boards: three tiny puzzles, one per interaction the player has
/// to learn (tap to clear / pinch to zoom / drag to pan). They use the five
/// countries the campaign had to drop — scattered archipelagos whose largest
/// connected piece is only 3–10 cells — so nothing is duplicated and a mask
/// that was otherwise unusable earns a place.
library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

const targets = [4, 6, 8, 10, 14];

List<String> rescale(List<String> g, double s) {
  final rows = max(3, (g.length * s).round());
  final cols = max(3, (g[0].length * s).round());
  return [
    for (var r = 0; r < rows; r++)
      String.fromCharCodes([
        for (var c = 0; c < cols; c++)
          g[(r / s).floor().clamp(0, g.length - 1)]
                  [(c / s).floor().clamp(0, g[0].length - 1)].codeUnitAt(0)
      ])
  ];
}

Level gen(List<String> g, int seed) {
  final mask = <(int, int)>{
    for (var r = 0; r < g.length; r++)
      for (var c = 0; c < g[r].length; c++) if (g[r][c] == '#') (r, c)};
  return generateLevel(rows: g.length, cols: g[0].length, mask: mask,
      seed: seed, fill: 0.92, maxLen: 8, lenMix: LenMixes.balanced);
}

String encode(List<(int, int)> cells) {
  final b = StringBuffer('${cells.first.$1},${cells.first.$2}:');
  for (var i = 1; i < cells.length; i++) {
    final dr = cells[i].$1 - cells[i - 1].$1, dc = cells[i].$2 - cells[i - 1].$2;
    b.write(dr == -1 ? 'U' : dr == 1 ? 'D' : dc == -1 ? 'L' : 'R');
  }
  return b.toString();
}

void main() {
  final shapes = (jsonDecode(
      File('tools/atlas/atlas_countries.json').readAsStringSync())
      as Map<String, dynamic>)['shapes'] as List;
  final by = {for (final s in shapes.cast<Map<String, dynamic>>()) s['name']: s};

  const picks = [
    ('Tonga', '통가', '탭해서 화살 빼기'),
    ('Maldives', '몰디브', '줌인 · 줌아웃'),
    ('South Georgia and the Islands', '남조지아', '드래그로 이동'),
    ('Cayman Islands', '케이맨 제도', '(예비)'),
    ('French Southern and Antarctic Lands', '프랑스령 남방', '(예비)'),
  ];

  final out = <Map<String, dynamic>>[];
  for (final (name, ko, teaches) in picks) {
    final src = (by[name]!['grid'] as List).cast<String>();
    for (final want in targets) {
      var scale = 2.0;
      Level? best;
      List<String>? bestG;
      for (var i = 0; i < 24; i++) {
        final g = rescale(src, scale);
        final lvl = gen(g, 424242 + want);
        if (best == null ||
            (lvl.lines.length - want).abs() < (best.lines.length - want).abs()) {
          best = lvl;
          bestG = g;
        }
        if (lvl.lines.length == want) break;
        scale *= lvl.lines.length < want ? 1.10 : 0.94;
        scale = scale.clamp(1.0, 14.0);
      }
      final lens = best!.lines.map((l) => l.cells.length).toList()..sort();
      out.add({
        'name': name, 'ko': ko, 'teaches': teaches, 'want': want,
        'rows': bestG!.length, 'cols': bestG[0].length,
        'cells': best.mask.length, 'arrows': best.lines.length,
        'lmin': lens.first, 'lmax': lens.last,
        'lavg': double.parse(
            (lens.reduce((a, b) => a + b) / lens.length).toStringAsFixed(1)),
        'srcCells': (by[name]!['cells'] as int),
        'scale': double.parse(
            (bestG.length / src.length).toStringAsFixed(2)),
        'solvable': BoardLogic.isSolvable(best),
        'grid': bestG,
        'lines': [for (final l in best.lines) encode(l.cells)],
      });
    }
  }
  File('tools/atlas/onboarding_boards.json')
      .writeAsStringSync(jsonEncode({'boards': out}));
  for (final b in out) {
    stdout.writeln('${b['ko']} 목표${b['want']} -> 화살 ${b['arrows']} '
        '${b['rows']}x${b['cols']} ${b['cells']}셀 x${b['scale']} '
        '풀림 ${b['solvable']}');
  }
}
