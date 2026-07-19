/// Arrow count >= 50 is the spec. Masks are upscaled (nearest-neighbour)
/// until they can hold it. Reports per country, smallest territory first.
library;
import 'dart:convert';
import 'dart:io';
import 'package:atlas_arrows/models/level.dart';
import 'package:atlas_arrows/models/level_generator.dart';

const minArrows = 50;

List<String> upscale(List<String> g, double s) {
  final rows = (g.length * s).round(), cols = (g[0].length * s).round();
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

(Level, List<String>) build(List<String> grid, int seed) {
  var g = grid;
  for (var i = 0; i < 12; i++) {
    final mask = <(int, int)>{
      for (var r = 0; r < g.length; r++)
        for (var c = 0; c < g[r].length; c++) if (g[r][c] == '#') (r, c)};
    final lvl = generateLevel(rows: g.length, cols: g[0].length, mask: mask,
        seed: seed, fill: 0.92, maxLen: 12);
    if (lvl.lines.length >= minArrows) return (lvl, g);
    g = upscale(grid, 1.0 + 0.15 * (i + 1));
  }
  final mask = <(int, int)>{
    for (var r = 0; r < g.length; r++)
      for (var c = 0; c < g[r].length; c++) if (g[r][c] == '#') (r, c)};
  return (generateLevel(rows: g.length, cols: g[0].length, mask: mask,
      seed: seed, fill: 0.92, maxLen: 12), g);
}

void main(List<String> args) {
  final n = args.isEmpty ? 14 : int.parse(args.first);
  final cs = (jsonDecode(File('assets/campaign/campaign.json').readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;
  stdout.writeln('순위 국가        원본셀 배율  격자    셀  화살 길이(최소~최대/평균) 방향분포 U/D/L/R');
  for (final e in cs.cast<Map<String, dynamic>>().take(n)) {
    final grid = (e['grid'] as List).cast<String>();
    final (lvl, g) = build(grid, (e['rank'] as int) * 1000 + 900);
    final lens = lvl.lines.map((l) => l.cells.length).toList()..sort();
    final avg = lens.reduce((a, b) => a + b) / lens.length;
    final dir = <String, int>{'U': 0, 'D': 0, 'L': 0, 'R': 0};
    for (final l in lvl.lines) {
      final a = l.cells[l.cells.length - 2], t = l.cells.last;
      final k = t.$1 - a.$1 == -1 ? 'U' : t.$1 - a.$1 == 1 ? 'D'
          : t.$2 - a.$2 == -1 ? 'L' : 'R';
      dir[k] = dir[k]! + 1;
    }
    final cells = g.fold<int>(0, (a, r) => a + '#'.allMatches(r).length);
    final scale = (g.length / grid.length);
    stdout.writeln(
        '${e['rank'].toString().padLeft(3)} ${(e['ko'] as String).padRight(11)}'
        '${(e['cells'] as int).toString().padLeft(5)} '
        '${scale.toStringAsFixed(2).padLeft(5)} '
        '${'${g.length}x${g[0].length}'.padLeft(7)} '
        '${cells.toString().padLeft(5)} '
        '${lvl.lines.length.toString().padLeft(4)}  '
        '${lens.first}~${lens.last} / ${avg.toStringAsFixed(1)}'.padRight(20) +
        '  ${dir['U']}/${dir['D']}/${dir['L']}/${dir['R']}');
  }
}
