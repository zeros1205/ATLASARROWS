import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'level.dart';
import 'level_generator.dart';

/// A real-geography landmark board within a country (a city / major region).
/// Its silhouette is baked from atlas data. `rows`/`cols` size its own board.
class CampaignCity {
  CampaignCity({
    required this.name,
    required this.rows,
    required this.cols,
    required this.mask,
  });

  final String name;
  final int rows;
  final int cols;
  final Set<(int, int)> mask;
}

/// One country = one round. Ordered by territory area ascending, so difficulty
/// rises across the campaign. A round runs as an interleave of landmark boards
/// and basic-shape "path" puzzles that connect them:
///
///     city → shape → city → shape → … → shape → country (finale)
///
/// City landmarks come from baked atlas masks (`cities`); until those exist the
/// round is all path shapes plus the country-silhouette finale.
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
    this.cities = const [],
    this.intro = const {},
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

  /// City landmark boards, in play order. Empty until atlas city masks are
  /// baked; each one slots into a "city" position in the round sequence.
  final List<CampaignCity> cities;

  /// Short country blurbs for the round-intro page, keyed by language code
  /// (`en`, `ko`, …) for multi-language service. Baked from an encyclopedia
  /// source. Empty until intros are baked.
  final Map<String, String> intro;

  /// Normalized (u,v) 0..1 pin positions for each stage, spread across the
  /// mask — where the stage nodes sit on the country map.
  final List<(double, double)> pins;

  String get displayName => ko.isNotEmpty ? ko : name;

  /// The round-intro blurb for [languageCode], falling back to English and
  /// then any available language ('' if none baked).
  String introFor(String languageCode) =>
      intro[languageCode] ?? intro['en'] ?? (intro.isEmpty ? '' : intro.values.first);

  /// City-landmark stages in the round.
  int get cityCount => cities.length;

  /// Basic-shape "path" stages: everything but the cities and the finale.
  int get pathCount => (stageCount - cities.length - 1).clamp(0, stageCount);
}

/// What kind of board a given stage in a round is.
sealed class _StageKind {
  const _StageKind();
}

/// A city / major-region landmark board (index into [CampaignCountry.cities]).
class _CityStage extends _StageKind {
  const _CityStage(this.index);
  final int index;
}

/// A basic-shape "path to the next place" puzzle ([ordinal]-th path in the round).
class _PathStage extends _StageKind {
  const _PathStage(this.ordinal);
  final int ordinal;
}

/// The country-silhouette finale (the round's boss).
class _CountryFinale extends _StageKind {
  const _CountryFinale();
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
      final cities = _parseCities(e['cities']);
      // The round is driven by how many city landmarks the country has:
      // city → path → … → path → country, i.e. 2·(cities) + 1 stages. A
      // country with many big cities (e.g. the US) yields many more stages;
      // small countries are floored to a MINIMUM of 10 (no upper cap).
      final stageCount = math.max(10, cities.length * 2 + 1);
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
        cities: cities,
        intro: _parseIntro(e['intro']),
      ));
      global += stageCount;
    }
    _total = global;
  }

  /// Parses per-language round-intro blurbs. Accepts a `{ "en": …, "ko": … }`
  /// map, or a bare string (treated as English) for back-compat.
  static Map<String, String> _parseIntro(Object? raw) {
    if (raw is String) return raw.isEmpty ? const {} : {'en': raw};
    if (raw is Map) {
      return {
        for (final e in raw.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key.toString(): e.value as String,
      };
    }
    return const {};
  }

  /// Parses baked city landmarks from the campaign JSON (may be absent until
  /// the atlas city masks are baked, in which case the round is all paths).
  static List<CampaignCity> _parseCities(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final c in raw.cast<Map<String, dynamic>>())
        if ((c['grid'] as List?) != null)
          () {
            final g = (c['grid'] as List).cast<String>();
            return CampaignCity(
              name: (c['name'] as String?) ?? '',
              rows: g.length,
              cols: g.isEmpty ? 0 : g[0].length,
              mask: {
                for (var r = 0; r < g.length; r++)
                  for (var col = 0; col < g[r].length; col++)
                    if (g[r][col] == '#') (r, col),
              },
            );
          }(),
    ];
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

  /// Generates (and caches) the Level for a global stage index. The round's
  /// stage sequence (see [_plan]) interleaves city landmarks with basic-shape
  /// path puzzles and ends on the country silhouette. Board size and fill rise
  /// with the stage position so difficulty climbs across the round.
  Level levelAt(int globalStage) => _cache.putIfAbsent(globalStage, () {
        final (ci, local) = locate(globalStage);
        final country = countries[ci];
        final base = country.rank * 1000;
        final fill = (0.80 + 0.02 * local).clamp(0.80, 0.96);

        switch (_plan(country)[local]) {
          // The country silhouette: the round's landmark finale (boss).
          case _CountryFinale():
            return generateLevel(
              rows: country.rows,
              cols: country.cols,
              mask: country.mask,
              seed: base + 900,
              fill: 0.92,
              maxLen: 13,
            );

          // A baked city / major-region landmark board.
          case _CityStage(:final index):
            final city = country.cities[index];
            return generateLevel(
              rows: city.rows,
              cols: city.cols,
              mask: city.mask,
              seed: base + 100 + index,
              fill: fill,
              maxLen: 9 + local,
            );

          // A basic-shape "path to the next place": a square board (unified),
          // sized up as the round goes so it packs the board tightly.
          case _PathStage():
            final span = (country.stageCount - 1).clamp(1, 1 << 30);
            final side = 7 + (local * 4 / span).round(); // 7..11
            return generateLevel(
              rows: side,
              cols: side,
              mask: BoardMasks.rect(side, side),
              seed: base + local,
              fill: fill,
              maxLen: 8 + local,
            );
        }
      });

  /// The stage sequence for a round: `city → path → city → … → path → country`.
  /// Cities and paths alternate while cities remain, then paths fill the rest,
  /// and the country silhouette is always the finale. With no baked cities the
  /// sequence is simply path × (stageCount − 1) + country.
  static List<_StageKind> _plan(CampaignCountry country) {
    final kinds = <_StageKind>[];
    var city = 0, path = 0;
    var wantCity = country.cities.isNotEmpty;
    while (kinds.length < country.stageCount - 1) {
      if (wantCity && city < country.cities.length) {
        kinds.add(_CityStage(city++));
        wantCity = false; // a path follows each city
      } else {
        kinds.add(_PathStage(path++));
        wantCity = city < country.cities.length; // back to a city if any remain
      }
    }
    kinds.add(const _CountryFinale());
    return kinds;
  }


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
