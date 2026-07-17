import 'level.dart';
import 'level_generator.dart';
import 'levels.dart';
import 'shape_catalog.dart';

/// Lazy level source. When the shape catalog is loaded, every catalog
/// silhouette is a level, generated on first entry (generating ~1,500
/// dense boards up front would stall startup). Falls back to the 50
/// bundled parametric levels when the catalog is missing.
class LevelRepository {
  LevelRepository._();

  static final LevelRepository instance = LevelRepository._();

  final Map<int, Level> _cache = {};

  bool get _fromCatalog => ShapeCatalog.isLoaded;

  int get length =>
      _fromCatalog ? ShapeCatalog.shapes.length : bundledLevels.length;

  Level levelAt(int index) => _cache.putIfAbsent(index, () {
        if (!_fromCatalog) return bundledLevels[index];
        final shape = ShapeCatalog.shapes[index];
        return generateLevel(
          rows: shape.rows,
          cols: shape.cols,
          mask: shape.mask,
          seed: 7000 + index,
          fill: shape.isBoss ? 0.9 : 0.87,
          maxLen: shape.isBoss ? 14 : 12,
        );
      });
}
