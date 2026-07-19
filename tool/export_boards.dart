/// Exports every campaign country + baked city as a real generated puzzle
/// meeting the current spec: 80–150 arrows, maxLen 20, average arrow length
/// >= 3.7 (no upper bound), cycled across the 3.7 / 4.1 / 4.9 presets so the
/// bank stays varied. Territory area does not set board size — the mask is
/// rescaled in either direction until the arrow count lands in the band.
library;
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

const minArrows = 80;
const maxArrows = 150;
const maxLen = 20;
const mixes = [LenMixes.shorter, LenMixes.balanced, LenMixes.longer];

/// Nearest-neighbour resample of a mask grid. [s] > 1 enlarges, < 1 shrinks.
List<String> rescale(List<String> g, double s) {
  final rows = max(3, (g.length * s).round());
  final cols = max(3, (g[0].length * s).round());
  return [
    for (var r = 0; r < rows; r++)
      String.fromCharCodes([
        for (var c = 0; c < cols; c++)
          g[(r / s).floor().clamp(0, g.length - 1)]
                  [(c / s).floor().clamp(0, g[0].length - 1)]
              .codeUnitAt(0)
      ])
  ];
}

Level gen(List<String> g, int seed, LenMix mix) {
  final mask = <(int, int)>{
    for (var r = 0; r < g.length; r++)
      for (var c = 0; c < g[r].length; c++) if (g[r][c] == '#') (r, c)};
  return generateLevel(rows: g.length, cols: g[0].length, mask: mask,
      seed: seed, fill: 0.92, maxLen: maxLen, lenMix: mix);
}

String encode(List<(int, int)> cells) {
  final b = StringBuffer('${cells.first.$1},${cells.first.$2}:');
  for (var i = 1; i < cells.length; i++) {
    final dr = cells[i].$1 - cells[i - 1].$1, dc = cells[i].$2 - cells[i - 1].$2;
    b.write(dr == -1 ? 'U' : dr == 1 ? 'D' : dc == -1 ? 'L' : 'R');
  }
  return b.toString();
}

const minAvgLen = 3.7;

double avgOf(Level l) =>
    l.lines.fold<int>(0, (a, x) => a + x.cells.length) / l.lines.length;

/// Gates every board must clear: at least [minArrows] arrows, and an average
/// arrow length of at least [minAvgLen] (no upper bound — user decision).
/// City boards additionally cap at [maxArrows]; country boards are the round
/// finale and may run as large as their silhouette gives.
///
/// Arrow count scales with mask area, so the mask is resampled in whichever
/// direction the count needs — territory area never sets board size. The
/// scale is solved for rather than stepped: arrows ≈ cells / average length
/// and cells ≈ s², so `s ≈ sqrt(target / arrows)` lands close in one jump and
/// a few refinements finish it. Narrow, winding masks truncate walks and come
/// out short, so the length mix escalates when the average falls below gate.
Map<String, dynamic> board(String kind, int rank, String name, String ko,
    List<String> src, int seed, LenMix mix, String mixName) {
  const ladder = [
    (LenMixes.shorter, '3.7'),
    (LenMixes.balanced, '4.1'),
    (LenMixes.longer, '4.9'),
  ];
  final start = ladder.indexWhere((e) => e.$2 == mixName);
  final cap = kind == 'city' ? maxArrows : 1 << 30;
  final aim = kind == 'city' ? (minArrows + maxArrows) ~/ 2 : minArrows + 20;

  bool passes(Level l) =>
      l.lines.length >= minArrows &&
      l.lines.length <= cap &&
      avgOf(l) >= minAvgLen;

  var scale = 1.0;
  var g = src;
  Level? best;
  var bestMix = mixName;
  var bestScale = 1.0;

  for (var m = start; m < ladder.length; m++) {
    scale = 1.0;
    for (var iter = 0; iter < 8; iter++) {
      g = scale == 1.0 ? src : rescale(src, scale);
      for (var s = 0; s < 3; s++) {
        final cand = gen(g, seed + s * 7919, ladder[m].$1);
        if (passes(cand)) {
          final lens = cand.lines.map((l) => l.cells.length).toList()..sort();
          return _emit(kind, rank, name, ko, src, g, cand, lens, ladder[m].$2,
              scale);
        }
        // Keep whichever candidate is closest to the band so a board that
        // never fully converges still ships something sane.
        if (best == null || _miss(cand, cap) < _miss(best, cap)) {
          best = cand;
          bestMix = ladder[m].$2;
          bestScale = scale;
        }
      }
      final n = gen(g, seed, ladder[m].$1).lines.length;
      if (n >= minArrows && n <= cap) break; // count is fine; mix is the issue
      scale *= sqrt(aim / n).clamp(0.55, 1.9);
      scale = scale.clamp(0.35, 4.0);
    }
  }
  final lens = best!.lines.map((l) => l.cells.length).toList()..sort();
  return _emit(kind, rank, name, ko, src,
      bestScale == 1.0 ? src : rescale(src, bestScale), best, lens, bestMix,
      bestScale);
}

/// How far a candidate sits outside the gates — 0 means it passes.
double _miss(Level l, int cap) {
  final n = l.lines.length;
  final over = n > cap ? (n - cap).toDouble() : 0.0;
  final under = n < minArrows ? (minArrows - n).toDouble() : 0.0;
  final short = avgOf(l) < minAvgLen ? (minAvgLen - avgOf(l)) * 50 : 0.0;
  return over + under + short;
}

Map<String, dynamic> _emit(String kind, int rank, String name, String ko,
    List<String> src, List<String> g, Level lvl, List<int> lens, String mixName,
    double scale) {
  return {
    'kind': kind, 'rank': rank, 'name': name, 'ko': ko,
    'src': src.fold<int>(0, (a, r) => a + '#'.allMatches(r).length),
    'scale': double.parse(scale.toStringAsFixed(2)),
    'rows': g.length, 'cols': g[0].length,
    'cells': lvl.mask.length,
    'arrows': lvl.lines.length,
    'lmin': lens.first, 'lmax': lens.last,
    'lavg': double.parse(
        (lens.reduce((a, b) => a + b) / lens.length).toStringAsFixed(1)),
    'mix': mixName,
    'solvable': BoardLogic.isSolvable(lvl),
    'grid': g,
    'lines': [for (final l in lvl.lines) encode(l.cells)],
  };
}

void main() {
  const names = ['3.7', '4.1', '4.9'];
  final out = <Map<String, dynamic>>[];

  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  for (final e in cs.cast<Map<String, dynamic>>()) {
    final rank = e['rank'] as int;
    final i = (rank - 1) % 3;
    out.add(board('country', rank, e['name'] as String, e['ko'] as String,
        (e['grid'] as List).cast<String>(), rank * 1000 + 900, mixes[i], names[i]));
    if (out.length % 50 == 0) stdout.writeln('  ${out.length}...');
  }

  final cities = (jsonDecode(
      File('tools/atlas/atlas_cities.json').readAsStringSync())
      as Map<String, dynamic>)['shapes'] as List;
  var n = 0;
  for (final e in cities.cast<Map<String, dynamic>>()) {
    n++;
    final i = (n - 1) % 3;
    out.add(board('city', n, e['name'] as String,
        (e['ko'] as String?) ?? e['name'] as String,
        (e['grid'] as List).cast<String>(), 600000 + n * 100, mixes[i], names[i]));
  }

  final f = File('tools/atlas/all_boards.json')
    ..writeAsStringSync(jsonEncode({'boards': out}));

  void report(String kind) {
    final s = out.where((b) => b['kind'] == kind).toList();
    final a = s.map((b) => b['arrows'] as int).toList()..sort();
    final lv = s.map((b) => b['lavg'] as double).toList()..sort();
    final lx = s.map((b) => b['lmax'] as int).reduce((x, y) => x > y ? x : y);
    stdout.writeln('$kind ${s.length}개 · 풀림 ${s.every((b) => b['solvable'] as bool)}');
    final cap = kind == 'city' ? maxArrows : 1 << 30;
    stdout.writeln('  화살 ${a.first}~${a.last} (중앙 ${a[a.length ~/ 2]}) · '
        '하한 미달 ${a.where((x) => x < minArrows).length}개'
        '${kind == 'city' ? ' · 상한 초과 ${a.where((x) => x > cap).length}개' : ''}');
    stdout.writeln('  평균길이 ${lv.first}~${lv.last} · 최장 화살 $lx칸');
  }
  report('country');
  report('city');
  stdout.writeln('${(f.lengthSync() / 1024).toStringAsFixed(0)} KB');
}
