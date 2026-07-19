/// Detached fragments: a mask piece far from the main body holding only a
/// handful of arrows. The player has to hunt for them after the main body is
/// clear, which reads as a chore, not a puzzle.
library;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> args) {
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
          if (cells.contains(n) && seen.add(n)) {
            q.add(n);
            comp.add(n);
          }
        }
      }
      out.add(comp);
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  final show = args.toSet();
  var boardsWithTiny = 0, tinyTotal = 0;
  final worst = <(String, int, int, int, double)>[];

  for (final b in boards.cast<Map<String, dynamic>>()) {
    final g = (b['grid'] as List).cast<String>();
    final ps = pieces(g);
    if (ps.length < 2) continue;
    final main = ps.first;
    final mr = main.map((e) => e.$1).reduce((a, x) => a + x) / main.length;
    final mc = main.map((e) => e.$2).reduce((a, x) => a + x) / main.length;
    final span = max(g.length, g[0].length).toDouble();

    // arrows whose head sits on each piece
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

    var tinyHere = 0;
    for (final p in ps.skip(1)) {
      final n = heads.where(p.contains).length;
      if (n == 0 || n > 5) continue;
      final pr = p.map((e) => e.$1).reduce((a, x) => a + x) / p.length;
      final pc = p.map((e) => e.$2).reduce((a, x) => a + x) / p.length;
      final dist = sqrt(pow(pr - mr, 2) + pow(pc - mc, 2)) / span;
      tinyHere++;
      tinyTotal++;
      worst.add((b['ko'] as String, n, p.length, ps.length, dist));
    }
    if (tinyHere > 0) boardsWithTiny++;

    if (show.contains(b['ko'])) {
      stdout.writeln('\n=== ${b['ko']}  ${g.length}x${g[0].length} '
          '조각 ${ps.length}개  화살 ${b['arrows']}');
      for (var i = 0; i < ps.length && i < 12; i++) {
        final p = ps[i];
        final n = heads.where(p.contains).length;
        final pr = p.map((e) => e.$1).reduce((a, x) => a + x) / p.length;
        final pc = p.map((e) => e.$2).reduce((a, x) => a + x) / p.length;
        final d = i == 0
            ? 0.0
            : sqrt(pow(pr - mr, 2) + pow(pc - mc, 2)) / span;
        stdout.writeln('  조각${i + 1}: ${p.length.toString().padLeft(4)}셀 '
            '화살 ${n.toString().padLeft(3)}  '
            '본토와의 거리 ${(d * 100).toStringAsFixed(0)}%');
      }
    }
  }

  worst.sort((a, b) => b.$5.compareTo(a.$5));
  stdout.writeln('\n전체 ${boards.length}개 보드');
  stdout.writeln('  화살 1~5개짜리 동떨어진 조각을 가진 보드: $boardsWithTiny개');
  stdout.writeln('  그런 조각 총 개수: $tinyTotal개');
  stdout.writeln('\n본토에서 가장 먼 사례:');
  for (final w in worst.take(12)) {
    stdout.writeln('  ${w.$1.padRight(16)} 화살 ${w.$2} · ${w.$3}셀 · '
        '거리 ${(w.$5 * 100).toStringAsFixed(0)}% · 총조각 ${w.$4}');
  }
}
