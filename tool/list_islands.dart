/// Full inventory of detached mask fragments that hold only a few arrows.
library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main() {
  final boards = (jsonDecode(
          File('tools/atlas/all_boards.json').readAsStringSync())
      as Map<String, dynamic>)['boards'] as List;

  List<Set<(int, int)>> pieces(List<String> g) {
    final cells = <(int, int)>{
      for (var r = 0; r < g.length; r++)
        for (var c = 0; c < g[r].length; c++) if (g[r][c] == '#') (r, c)};
    final seen = <(int, int)>{};
    final out = <Set<(int, int)>>[];
    for (final s in cells) {
      if (!seen.add(s)) continue;
      final q = <(int, int)>[s];
      final comp = <(int, int)>{s};
      for (var i = 0; i < q.length; i++) {
        final (r, c) = q[i];
        for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
          if (cells.contains(n) && seen.add(n)) { q.add(n); comp.add(n); }
        }
      }
      out.add(comp);
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  final rows = <Map<String, dynamic>>[];
  for (final b in boards.cast<Map<String, dynamic>>()) {
    final g = (b['grid'] as List).cast<String>();
    final ps = pieces(g);
    if (ps.length < 2) continue;
    final main = ps.first;
    final mr = main.map((e) => e.$1).reduce((a, x) => a + x) / main.length;
    final mc = main.map((e) => e.$2).reduce((a, x) => a + x) / main.length;
    final span = max(g.length, g[0].length).toDouble();

    final heads = <(int, int)>[];
    for (final spec in (b['lines'] as List).cast<String>()) {
      final p = spec.split(':');
      final s = p[0].split(',');
      var r = int.parse(s[0]), c = int.parse(s[1]);
      for (final m in p[1].split('')) {
        r += m == 'U' ? -1 : m == 'D' ? 1 : 0;
        c += m == 'L' ? -1 : m == 'R' ? 1 : 0;
      }
      heads.add((r, c));
    }

    var frags = 0, fragArrows = 0, fragCells = 0;
    var far = 0.0, smallest = 1 << 30;
    for (final p in ps.skip(1)) {
      final n = heads.where(p.contains).length;
      if (n == 0 || n > 5) continue;
      final pr = p.map((e) => e.$1).reduce((a, x) => a + x) / p.length;
      final pc = p.map((e) => e.$2).reduce((a, x) => a + x) / p.length;
      final d = sqrt(pow(pr - mr, 2) + pow(pc - mc, 2)) / span;
      frags++;
      fragArrows += n;
      fragCells += p.length;
      far = max(far, d);
      smallest = min(smallest, n);
    }
    if (frags == 0) continue;
    rows.add({
      'kind': b['kind'], 'ko': b['ko'], 'name': b['name'],
      'arrows': b['arrows'], 'mainCells': main.length,
      'frags': frags, 'fragArrows': fragArrows, 'fragCells': fragCells,
      'ratio': double.parse(
          (fragCells / main.length * 100).toStringAsFixed(1)),
      'far': (far * 100).round(), 'minArrows': smallest,
      'rows': g.length, 'cols': g[0].length,
      'grid': g,
      'lines': b['lines'],
      // cells of every fragment that would be dropped at a 5% threshold
      'cut': [
        for (final p in ps.skip(1))
          if (p.length / main.length < 0.05)
            [for (final (r, c) in p) [r, c]],
      ],
    });
  }

  rows.sort((a, b) {
    final k = (a['kind'] as String).compareTo(b['kind'] as String);
    return k != 0 ? k : (b['far'] as int).compareTo(a['far'] as int);
  });

  File('tools/atlas/island_report.json')
      .writeAsStringSync(jsonEncode({'rows': rows}));

  for (final kind in ['country', 'city']) {
    final s = rows.where((r) => r['kind'] == kind).toList();
    stdout.writeln('\n########## ${kind == 'country' ? '국가' : '도시'} '
        '${s.length}개 ##########');
    stdout.writeln('이름                 화살  본토셀  조각수 조각화살 조각셀 본토대비% 최원거리%');
    for (final r in s) {
      stdout.writeln('${(r['ko'] as String).padRight(20)}'
          '${r['arrows'].toString().padLeft(5)}'
          '${r['mainCells'].toString().padLeft(7)}'
          '${r['frags'].toString().padLeft(7)}'
          '${r['fragArrows'].toString().padLeft(8)}'
          '${r['fragCells'].toString().padLeft(7)}'
          '${r['ratio'].toString().padLeft(9)}'
          '${r['far'].toString().padLeft(9)}');
    }
  }
  stdout.writeln('\n-> tools/atlas/island_report.json');
}
