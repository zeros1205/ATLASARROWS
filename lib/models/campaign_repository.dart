import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'arrow_line.dart';
import 'level.dart';

/// What a stage's silhouette depicts.
enum StageKind {
  /// A city / major-region landmark — the body of a round.
  city,

  /// The country silhouette that closes the round.
  country,
}

/// One playable board, baked ahead of time by `tools/atlas/build_bank.py`.
///
/// Boards are **not** generated on the device. Every one was produced and
/// verified solvable offline, which is what lets the campaign ship a fixed,
/// measurable difficulty curve instead of whatever a seed happens to yield.
class CampaignStage {
  CampaignStage({
    required this.kind,
    required this.name,
    required this.ko,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.lineSpecs,
    this.teaches = '',
  });

  final StageKind kind;
  final String name;
  final String ko;
  final int rows;
  final int cols;

  /// Silhouette rows, `#` for board cells. Kept as strings and expanded only
  /// when a board is actually opened: building every mask up front means
  /// allocating a few hundred thousand cell records during boot, which is
  /// several seconds of a progress bar sitting still.
  final List<String> grid;

  /// What this board is meant to teach, on the opening tutorial rounds only
  /// ('' everywhere else).
  final String teaches;

  /// Raw `"r,c:MOVES"` specs; parsed into a [Level] on first play.
  final List<String> lineSpecs;

  String get displayName => ko.isNotEmpty ? ko : name;

  Set<(int, int)>? _mask;

  /// The board's cells, built on first use and kept for as long as the stage
  /// is referenced.
  Set<(int, int)> get mask => _mask ??= {
        for (var r = 0; r < grid.length; r++)
          for (var c = 0; c < grid[r].length; c++)
            if (grid[r][c] == '#') (r, c),
      };

  Level toLevel() => Level.fromLines(
        rows: rows,
        cols: cols,
        mask: mask,
        lines: [
          for (var i = 0; i < lineSpecs.length; i++)
            ArrowLine.parse(i, lineSpecs[i]),
        ],
      );
}

/// One country = one round, ordered by territory area ascending so the
/// campaign widens as it goes. A round plays its city landmarks first and
/// finishes on the country silhouette.
class CampaignCountry {
  CampaignCountry({
    required this.rank,
    required this.name,
    required this.ko,
    required this.areaKm2,
    required this.continent,
    required this.iso,
    required this.stages,
    this.intro = const {},
  });

  final int rank;
  final String name;
  final String ko;
  final int areaKm2;
  final String continent;

  /// ISO 3166-1 alpha-2 (uppercase), or '' for disputed territories without a
  /// standard code. Drives the flag emoji shown on clear.
  final String iso;

  /// The national flag as a Unicode emoji (two regional-indicator symbols),
  /// or '' when there is no ISO code. Renders where the platform font has flag
  /// glyphs; degrades to the country letters otherwise.
  String get flagEmoji {
    if (iso.length != 2) return '';
    const base = 0x1F1E6; // regional indicator 'A'
    final a = iso.codeUnitAt(0), b = iso.codeUnitAt(1);
    if (a < 65 || a > 90 || b < 65 || b > 90) return '';
    return String.fromCharCode(base + (a - 65)) +
        String.fromCharCode(base + (b - 65));
  }

  final List<CampaignStage> stages;

  /// Short blurbs for the round intro, keyed by language code.
  final Map<String, String> intro;

  List<(double, double)>? _pins;

  /// Normalized (u,v) 0..1 positions for each stage over the country shape.
  /// Computed on demand — nothing needs them until a country's detail is
  /// actually drawn, and sampling 221 masks during boot is pure delay.
  List<(double, double)> get pins => _pins ??=
      CampaignRepository._spreadPins(mask, rows, cols, stages.length);

  String get displayName => ko.isNotEmpty ? ko : name;

  /// The country silhouette board — always the last stage.
  CampaignStage get finale => stages.last;

  int get rows => finale.rows;
  int get cols => finale.cols;
  Set<(int, int)> get mask => finale.mask;
  int get cells => finale.mask.length;

  int get stageCount => stages.length;
  int get cityCount => stages.where((s) => s.kind == StageKind.city).length;

  /// Kept for the round-intro readout; every non-city stage is the finale.
  int get pathCount => 0;

  /// The lesson this round exists to teach, if it is one of the opening
  /// tutorial rounds.
  String get teaches =>
      stages.map((s) => s.teaches).firstWhere((t) => t.isNotEmpty,
          orElse: () => '');

  String introFor(String languageCode) =>
      intro[languageCode] ??
      intro['en'] ??
      (intro.isEmpty ? '' : intro.values.first);
}

/// Loads the prebaked campaign (assets/campaign/bank.json) and exposes a flat,
/// globally-ordered list of stages. Falls back to an empty campaign if the
/// asset is missing, in which case the UI shows nothing to play rather than
/// crashing.
class CampaignRepository {
  CampaignRepository._();
  static final CampaignRepository instance = CampaignRepository._();

  final List<CampaignCountry> countries = [];
  final List<int> _firstStage = []; // global index of each country's stage 0
  final Map<String, List<int>> _byContinent = {}; // continent -> country indices
  int _total = 0;

  /// Parsed levels, kept small: boards are big and a player only revisits a
  /// handful. Evicted oldest-first.
  final Map<int, Level> _cache = {};
  final List<int> _cacheOrder = [];
  static const _cacheLimit = 8;

  bool get isLoaded => countries.isNotEmpty;
  int get totalStages => _total;

  Future<void> load() async {
    if (isLoaded) return;
    String raw;
    try {
      raw = await rootBundle.loadString('assets/campaign/bank.json');
    } catch (_) {
      return; // no campaign asset available
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['countries'] as List).cast<Map<String, dynamic>>();
    var global = 0;
    for (final e in list) {
      final stages = [
        for (final s in (e['stages'] as List).cast<Map<String, dynamic>>())
          _parseStage(s),
      ];
      if (stages.isEmpty) continue;
      _firstStage.add(global);
      countries.add(CampaignCountry(
        rank: e['rank'] as int,
        name: e['name'] as String,
        ko: (e['ko'] as String?) ?? '',
        areaKm2: (e['area_km2'] as num?)?.toInt() ?? 0,
        continent: (e['continent'] as String?) ?? '',
        iso: ((e['iso'] as String?) ?? '').toUpperCase(),
        stages: stages,
        intro: _parseIntro(e['intro']),
      ));
      final continent = countries.last.continent;
      if (continent.isNotEmpty) {
        (_byContinent[continent] ??= []).add(countries.length - 1);
      }
      global += stages.length;
    }
    _total = global;
  }

  /// Continents whose every country is at or below [completedCountryIndex] —
  /// i.e. fully cleared. The campaign is linear by area, so completing country
  /// N means countries 0..N are done; a continent is complete once its
  /// highest-index country is. Drives the continent-completion achievements.
  List<String> completedContinents(int completedCountryIndex) {
    final done = <String>[];
    for (final entry in _byContinent.entries) {
      if (entry.value.every((i) => i <= completedCountryIndex)) {
        done.add(entry.key);
      }
    }
    return done;
  }

  static CampaignStage _parseStage(Map<String, dynamic> s) => CampaignStage(
        kind: s['kind'] == 'country' ? StageKind.country : StageKind.city,
        name: (s['name'] as String?) ?? '',
        ko: (s['ko'] as String?) ?? '',
        rows: (s['rows'] as num).toInt(),
        cols: (s['cols'] as num).toInt(),
        grid: (s['grid'] as List).cast<String>(),
        lineSpecs: (s['lines'] as List).cast<String>(),
        teaches: (s['teaches'] as String?) ?? '',
      );

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

  /// (country index, stage-within-country) for a global stage index.
  (int, int) locate(int globalStage) {
    if (_firstStage.isEmpty) return (0, 0);
    // Binary search: the campaign is ~800 stages and this runs on every frame
    // that renders a stage label.
    var lo = 0, hi = _firstStage.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_firstStage[mid] <= globalStage) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return (lo, globalStage - _firstStage[lo]);
  }

  int firstStageOf(int countryIndex) => _firstStage[countryIndex];

  /// The stage descriptor at a global index, or null when out of range.
  CampaignStage? stageAt(int globalStage) {
    if (!isLoaded || globalStage < 0 || globalStage >= _total) return null;
    final (ci, local) = locate(globalStage);
    return countries[ci].stages[local];
  }

  /// The playable level at a global index. Parsed on demand and cached.
  Level levelAt(int globalStage) {
    final hit = _cache[globalStage];
    if (hit != null) return hit;
    final stage = stageAt(globalStage) ?? countries.first.stages.first;
    final level = stage.toLevel();
    _cache[globalStage] = level;
    _cacheOrder.add(globalStage);
    if (_cacheOrder.length > _cacheLimit) {
      _cache.remove(_cacheOrder.removeAt(0));
    }
    return level;
  }

  /// Farthest-point sampling so stage pins spread over the country shape.
  static List<(double, double)> _spreadPins(
      Set<(int, int)> mask, int rows, int cols, int n) {
    final cellList = mask.toList();
    if (cellList.isEmpty) return const [];
    cellList.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    // Sampling every cell of a 1,500-cell mask n times is wasteful; a stride
    // keeps this linear enough for the biggest countries.
    final stride = math.max(1, cellList.length ~/ 400);
    final pool = [
      for (var i = 0; i < cellList.length; i += stride) cellList[i],
    ];
    final picked = <(int, int)>[pool.first];
    while (picked.length < n && picked.length < pool.length) {
      (int, int)? best;
      var bestD = -1.0;
      for (final cell in pool) {
        var nearest = double.infinity;
        for (final p in picked) {
          final dr = (cell.$1 - p.$1).toDouble();
          final dc = (cell.$2 - p.$2).toDouble();
          final d = dr * dr + dc * dc;
          if (d < nearest) nearest = d;
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
