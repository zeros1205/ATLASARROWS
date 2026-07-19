/// Picks three atlas silhouettes — most cells, closest to the candidate
/// mean, and fewest cells (>= the 80-cell floor) — and generates a real
/// puzzle on each with the game's generateLevel().
///
/// Usage: dart run tool/preview_levels.dart
/// Output: tools/atlas/preview_levels.json
library;

import 'dart:convert';
import 'dart:io';

import 'package:atlas_arrows/models/level_generator.dart';

const minCells = 80; // atlas candidate floor

void main() {
  final shapes = <Map<String, dynamic>>[];
  for (final f in [
    'tools/atlas/atlas_countries.json',
    'tools/atlas/atlas_cities.json',
    'tools/atlas/atlas_animals.json',
  ]) {
    final data = jsonDecode(File(f).readAsStringSync());
    for (final s in (data['shapes'] as List).cast<Map<String, dynamic>>()) {
      if ((s['cells'] as int) >= minCells) shapes.add(s);
    }
  }
  final mean =
      shapes.fold<int>(0, (a, s) => a + (s['cells'] as int)) / shapes.length;
  shapes.sort((a, b) => (a['cells'] as int).compareTo(b['cells'] as int));
  final smallest = shapes.first;
  final largest = shapes.last;
  final average = shapes.reduce((a, b) =>
      ((a['cells'] as int) - mean).abs() < ((b['cells'] as int) - mean).abs()
          ? a
          : b);
  stdout.writeln('candidates=${shapes.length} mean=${mean.toStringAsFixed(1)}');

  final out = <Map<String, dynamic>>[];
  for (final (label, s) in [
    ('largest', largest),
    ('average', average),
    ('smallest', smallest),
  ]) {
    final grid = (s['grid'] as List).cast<String>();
    final mask = <(int, int)>{
      for (var r = 0; r < grid.length; r++)
        for (var c = 0; c < grid[r].length; c++)
          if (grid[r][c] == '#') (r, c),
    };
    final sw = Stopwatch()..start();
    final level = generateLevel(
      rows: grid.length,
      cols: grid[0].length,
      mask: mask,
      seed: 20260718,
      fill: 0.97,
      maxLen: 12,
    );
    stdout.writeln('$label: ${s['ko']} ${level.rows}x${level.cols} '
        'mask=${mask.length} lines=${level.lines.length} '
        '(${sw.elapsedMilliseconds}ms)');
    out.add({
      'label': label,
      'name': s['name'],
      'ko': s['ko'],
      'rows': level.rows,
      'cols': level.cols,
      'maskCells': mask.length,
      'mask': grid,
      'lines': [
        for (final line in level.lines)
          [for (final (r, c) in line.cells) [r, c]],
      ],
    });
  }
  File('tools/atlas/preview_levels.json')
      .writeAsStringSync(jsonEncode({'levels': out}));
  stdout.writeln('-> tools/atlas/preview_levels.json');
}
