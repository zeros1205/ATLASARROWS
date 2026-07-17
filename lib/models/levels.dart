import 'level.dart';
import 'level_generator.dart';

/// Bundled levels: dense generated mazes with varied silhouettes and
/// mixed line lengths. Every level is solvable by construction and the
/// suite in board_logic_test.dart re-verifies with the greedy solver.
///
/// NOTE(M3): dart:math Random may differ across VM/web, so generated
/// boards can vary per platform (each still solvable). The real level
/// pipeline will pre-bake levels to JSON assets.
List<Level> loadBundledLevels() {
  return [
    // Warm-up: organic blob, still ~20 lines.
    generateLevel(
      rows: 12,
      cols: 9,
      mask: BoardMasks.blob(12, 9, 7),
      seed: 101,
      fill: 0.78,
      maxLen: 9,
    ),
    generateLevel(
      rows: 12,
      cols: 9,
      mask: BoardMasks.ellipse(12, 9),
      seed: 102,
      fill: 0.82,
      maxLen: 10,
    ),
    generateLevel(
      rows: 13,
      cols: 10,
      mask: BoardMasks.rect(13, 10),
      seed: 103,
      fill: 0.84,
      maxLen: 10,
    ),
    generateLevel(
      rows: 14,
      cols: 11,
      mask: BoardMasks.diamond(14, 11),
      seed: 104,
      fill: 0.86,
      maxLen: 11,
    ),
    generateLevel(
      rows: 14,
      cols: 10,
      mask: BoardMasks.blob(14, 10, 21),
      seed: 105,
      fill: 0.87,
      maxLen: 12,
    ),
    generateLevel(
      rows: 15,
      cols: 11,
      mask: BoardMasks.ellipse(15, 11),
      seed: 106,
      fill: 0.88,
      maxLen: 12,
    ),
    generateLevel(
      rows: 15,
      cols: 10,
      mask: BoardMasks.rect(15, 10),
      seed: 107,
      fill: 0.9,
      maxLen: 12,
    ),
    generateLevel(
      rows: 16,
      cols: 11,
      mask: BoardMasks.blob(16, 11, 33),
      seed: 108,
      fill: 0.9,
      maxLen: 13,
    ),
    generateLevel(
      rows: 16,
      cols: 12,
      mask: BoardMasks.diamond(16, 12),
      seed: 109,
      fill: 0.91,
      maxLen: 13,
    ),
    generateLevel(
      rows: 17,
      cols: 12,
      mask: BoardMasks.blob(17, 12, 55),
      seed: 110,
      fill: 0.92,
      maxLen: 14,
    ),
  ];
}
