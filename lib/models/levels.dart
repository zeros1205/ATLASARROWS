import 'level.dart';
import 'level_generator.dart';

/// Levels per chapter in the level-select UI.
const int levelsPerChapter = 10;

/// Bundled levels: 50 dense generated mazes (5 chapters), ramping in
/// size, fill, and line length. Silhouettes rotate blob/ellipse/rect/
/// diamond; GPT-designed picture silhouettes arrive via the shape
/// pipeline (tools/validate_shapes.py) in M3.
///
/// NOTE(M3): dart:math Random may differ across VM/web, so generated
/// boards can vary per platform (each still solvable). The real level
/// pipeline will pre-bake levels to JSON assets.
final List<Level> bundledLevels = _generate();

List<Level> _generate() {
  final levels = <Level>[];
  for (var i = 0; i < 50; i++) {
    final rows = 12 + i ~/ 9; // 12..17
    final cols = 9 + i ~/ 18; // 9..11
    final fill = 0.78 + (i * 0.003).clamp(0.0, 0.15); // .78 → .93
    final mask = switch (i % 4) {
      0 => BoardMasks.blob(rows, cols, 900 + i),
      1 => BoardMasks.ellipse(rows, cols),
      2 => BoardMasks.rect(rows, cols),
      _ => BoardMasks.diamond(rows, cols),
    };
    levels.add(
      generateLevel(
        rows: rows,
        cols: cols,
        mask: mask,
        seed: 1000 + i,
        fill: fill,
        maxLen: 9 + i ~/ 10, // 9..14
      ),
    );
  }
  return levels;
}
