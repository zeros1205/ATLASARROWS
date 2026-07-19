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

  bool get isLoaded => cols > 0;

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
    final repo = CampaignRepository.instance;
    final byName = <String, int>{
      for (var i = 0; i < repo.countries.length; i++) repo.countries[i].name: i,
    };
    for (final name in names) {
      final ci = byName[name];
      if (ci != null) _nameToCountry[name] = ci;
    }
  }

  int cellAt(int r, int c) => cells[r * cols + c];

  /// Campaign country index for a land cell value, or null if the cell is sea
  /// or the country isn't part of the (current) campaign.
  int? countryOfCell(int cellValue) =>
      cellValue < 0 ? null : _nameToCountry[names[cellValue]];
}
