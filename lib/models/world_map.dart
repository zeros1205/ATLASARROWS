import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'campaign_repository.dart';

/// The dotted world map baked by tools/atlas/build_worldmap.py. An
/// equirectangular grid where each cell is either sea (-1) or an index into
/// [names] (the country's ADMIN name). Names resolve to campaign countries so
/// each land dot can be coloured by that country's progress state.
class WorldMap {
  WorldMap._();
  static final WorldMap instance = WorldMap._();

  int cols = 0, rows = 0;
  List<String> names = const [];
  Int32List cells = Int32List(0);
  final Map<String, int> _nameToCountry = {}; // ADMIN name -> campaign index

  /// Per-cell position within its own country, and each country's dot count.
  ///
  /// Together these let the map colour a country *partially*: clearing one
  /// stage of twelve fills a twelfth of its dots. Whole-country states would
  /// leave a player seeing nothing change for an entire round, which is where
  /// the sense of progress is supposed to come from.
  Int32List _ordinal = Int32List(0);
  final Map<int, int> _countryDots = {};

  bool get isLoaded => cols > 0;

  /// How many map dots belong to [countryIndex].
  int dotsOf(int countryIndex) => _countryDots[countryIndex] ?? 0;

  /// This cell's index within its country, or -1 for sea / off-campaign land.
  int ordinalAt(int linearIndex) => _ordinal[linearIndex];

  Future<void> load() async {
    if (isLoaded) return;
    String raw;
    try {
      raw = await rootBundle.loadString('assets/campaign/worldmap.json');
    } catch (_) {
      return; // asset not bundled
    }
    final d = jsonDecode(raw) as Map<String, dynamic>;
    cols = d['cols'] as int;
    rows = d['rows'] as int;
    names = (d['names'] as List).cast<String>();
    cells = Int32List.fromList((d['cells'] as List).cast<int>());
    _resolve();
  }

  /// Re-links world countries to the loaded campaign (call after both load).
  void _resolve() {
    _nameToCountry.clear();
    _countryDots.clear();
    final repo = CampaignRepository.instance;
    final byName = <String, int>{
      for (var i = 0; i < repo.countries.length; i++) repo.countries[i].name: i,
    };
    for (final name in names) {
      final ci = byName[name];
      if (ci != null) _nameToCountry[name] = ci;
    }
    // Number each country's dots in row order so a partial fill sweeps
    // top-down rather than flickering at random.
    _ordinal = Int32List(cells.length)..fillRange(0, cells.length, -1);
    for (var i = 0; i < cells.length; i++) {
      final ci = countryOfCell(cells[i]);
      if (ci == null) continue;
      _ordinal[i] = _countryDots[ci] ?? 0;
      _countryDots[ci] = _ordinal[i] + 1;
    }
  }

  int cellAt(int r, int c) => cells[r * cols + c];

  /// Campaign country index for a land cell value, or null if the cell is sea
  /// or the country isn't part of the (current) campaign.
  int? countryOfCell(int cellValue) =>
      cellValue < 0 ? null : _nameToCountry[names[cellValue]];
}
