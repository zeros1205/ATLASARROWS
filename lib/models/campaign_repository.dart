import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'level.dart';
import 'level_generator.dart';

/// One country = one round. Ordered by territory area ascending, so
/// difficulty rises across the campaign. Its stages (city/point boards)
/// are generated from the country mask with a rising fill/length so
/// difficulty also rises within the round.
class CampaignCountry {
  CampaignCountry({
    required this.rank,
    required this.name,
    required this.ko,
    required this.areaKm2,
    required this.rows,
    required this.cols,
    required this.mask,
    required this.cells,
    required this.stageCount,
    required this.pins,
  });

  final int rank;
  final String name;
  final String ko;
  final int areaKm2;
  final int rows;
  final int cols;
  final Set<(int, int)> mask;
  final int cells;
  final int stageCount;

  /// Normalized (u,v) 0..1 pin positions for each stage, spread across the
  /// mask — where the stage nodes sit on the country map.
  final List<(double, double)> pins;

  String get displayName => ko.isNotEmpty ? ko : name;
}

/// Loads the prebaked campaign (assets/campaign/campaign.json) and exposes
/// a flat, globally-ordered list of stages. Falls back to an empty campaign
/// if the asset is missing (offline / not yet generated).
class CampaignRepository {
  CampaignRepository._();
  static final CampaignRepository instance = CampaignRepository._();

  final List<CampaignCountry> countries = [];
  final List<int> _firstStage = []; // global index of each country's stage 0
  int _total = 0;
  final Map<int, Level> _cache = {};

  bool get isLoaded => countries.isNotEmpty;
  int get totalStages => _total;

  Future<void> load() async {
    if (isLoaded) return;
    String raw;
    try {
      raw = await rootBundle.loadString('assets/campaign/campaign.json');
    } catch (_) {
      return; // no campaign asset available
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['countries'] as List).cast<Map<String, dynamic>>();
    var global = 0;
    for (final e in list) {
      final grid = (e['grid'] as List).cast<String>();
      final mask = <(int, int)>{
        for (var r = 0; r < grid.length; r++)
          for (var col = 0; col < grid[r].length; col++)
            if (grid[r][col] == '#') (r, col),
      };
      final cells = mask.length;
      final stageCount = (cells / 150).round().clamp(3, 6);
      final pins = _spreadPins(mask, grid.length, grid[0].length, stageCount);
      _firstStage.add(global);
      countries.add(CampaignCountry(
        rank: e['rank'] as int,
        name: e['name'] as String,
        ko: (e['ko'] as String?) ?? '',
        areaKm2: (e['area_km2'] as num?)?.toInt() ?? 0,
        rows: grid.length,
        cols: grid[0].length,
        mask: mask,
        cells: cells,
        stageCount: stageCount,
        pins: pins,
      ));
      global += stageCount;
    }
    _total = global;
  }

  /// (country index, stage-within-country) for a global stage index.
  (int, int) locate(int globalStage) {
    for (var i = countries.length - 1; i >= 0; i--) {
      if (globalStage >= _firstStage[i]) {
        return (i, globalStage - _firstStage[i]);
      }
    }
    return (0, 0);
  }

  int firstStageOf(int countryIndex) => _firstStage[countryIndex];

  /// Generates (and caches) the Level for a global stage index. Difficulty
  /// rises with the stage-within-country (fill + maxLen).
  Level levelAt(int globalStage) => _cache.putIfAbsent(globalStage, () {
        final (ci, local) = locate(globalStage);
        final country = countries[ci];
        final fill = (0.82 + 0.03 * local).clamp(0.82, 0.97);
        final maxLen = 9 + local;
        return generateLevel(
          rows: country.rows,
          cols: country.cols,
          mask: country.mask,
          seed: country.rank * 1000 + local,
          fill: fill,
          maxLen: maxLen,
        );
      });

  /// Farthest-point sampling so stage pins spread over the country shape.
  static List<(double, double)> _spreadPins(
      Set<(int, int)> mask, int rows, int cols, int n) {
    final cellList = mask.toList();
    if (cellList.isEmpty) return const [];
    // start from the topmost-leftmost cell
    cellList.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    final picked = <(int, int)>[cellList.first];
    while (picked.length < n && picked.length < cellList.length) {
      (int, int)? best;
      var bestD = -1.0;
      for (final cell in cellList) {
        var nearest = double.infinity;
        for (final p in picked) {
          final d = math.pow(cell.$1 - p.$1, 2) + math.pow(cell.$2 - p.$2, 2);
          if (d < nearest) nearest = d.toDouble();
        }
        if (nearest > bestD) {
          bestD = nearest;
          best = cell;
        }
      }
      if (best == null) break;
      picked.add(best);
    }
    return [
      for (final (r, cc) in picked)
        ((cc + 0.5) / cols, (r + 0.5) / rows),
    ];
  }
}
