import 'dart:convert';

import 'package:flutter/services.dart';

/// One validated silhouette from assets/shapes/shapes.json
/// (built by tools/build_shape_masks.py from the GPT metaphor table).
class ShapeDef {
  ShapeDef({
    required this.name,
    required this.theme,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.mask,
  });

  final String name;
  final String theme;
  final String difficulty;
  final int rows;
  final int cols;
  final Set<(int, int)> mask;

  bool get isBoss => difficulty == 'boss';
}

abstract final class ShapeCatalog {
  static List<ShapeDef> _shapes = const [];

  static List<ShapeDef> get shapes => _shapes;
  static bool get isLoaded => _shapes.isNotEmpty;

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/shapes/shapes.json');
      _shapes = parse(raw);
    } catch (_) {
      _shapes = const []; // repository falls back to bundled levels
    }
  }

  static List<ShapeDef> parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['shapes'] as List<dynamic>;
    return [
      for (final entry in list.cast<Map<String, dynamic>>())
        ShapeDef(
          name: entry['name'] as String,
          theme: (entry['theme'] as String?) ?? '',
          difficulty: (entry['difficulty'] as String?) ?? 'normal',
          rows: entry['rows'] as int,
          cols: entry['cols'] as int,
          mask: {
            for (var r = 0; r < (entry['grid'] as List).length; r++)
              for (var c = 0;
                  c < ((entry['grid'] as List)[r] as String).length;
                  c++)
                if (((entry['grid'] as List)[r] as String)[c] == '#') (r, c),
          },
        ),
    ];
  }
}
