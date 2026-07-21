import 'dart:convert';
import 'dart:io';

import 'package:atlas_arrows/game/board_logic.dart';
import 'package:atlas_arrows/models/arrow_line.dart';
import 'package:atlas_arrows/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks every board the app ships.
///
/// The campaign is 800 prebaked boards; nobody is going to tap through them,
/// so this is the only thing standing between a bad bake and a stage that is
/// unplayable — or unfinishable — in a player's hands. It reads the asset
/// directly rather than through CampaignRepository so it runs without a
/// Flutter binding.
void main() {
  final file = File('assets/campaign/bank.json');

  test('bank.json is present', () {
    expect(file.existsSync(), isTrue,
        reason: 'run: python tools/atlas/build_bank.py');
  });

  if (!file.existsSync()) return;

  final countries = (jsonDecode(file.readAsStringSync())
      as Map<String, dynamic>)['countries'] as List;

  Level levelOf(Map<String, dynamic> stage) {
    final grid = (stage['grid'] as List).cast<String>();
    return Level.fromLines(
      rows: (stage['rows'] as num).toInt(),
      cols: (stage['cols'] as num).toInt(),
      mask: {
        for (var r = 0; r < grid.length; r++)
          for (var c = 0; c < grid[r].length; c++)
            if (grid[r][c] == '#') (r, c),
      },
      lines: [
        for (final (i, spec)
            in (stage['lines'] as List).cast<String>().indexed)
          ArrowLine.parse(i, spec),
      ],
    );
  }

  test('every country round ends on its country silhouette', () {
    for (final country in countries.cast<Map<String, dynamic>>()) {
      final stages = (country['stages'] as List).cast<Map<String, dynamic>>();
      expect(stages, isNotEmpty, reason: '${country['name']} has no stages');
      expect(stages.last['kind'], 'country',
          reason: '${country['name']} does not finish on the country board');
      for (final s in stages.take(stages.length - 1)) {
        expect(s['kind'], anyOf('city', 'path'),
            reason: '${country['name']} has a country board before the finale');
      }
    }
  });

  test('every board builds a valid level', () {
    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        // Level.fromLines asserts lines stay inside the mask and never
        // overlap, which is exactly what a bad crop would break.
        expect(() => levelOf(stage), returnsNormally,
            reason: '${country['name']} / ${stage['name']}');
      }
    }
  });

  test('every board is solvable', () {
    final unsolved = <String>[];
    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        if (!BoardLogic.isSolvable(levelOf(stage))) {
          unsolved.add('${country['name']} / ${stage['name']}');
        }
      }
    }
    expect(unsolved, isEmpty, reason: 'unsolvable boards: $unsolved');
  });

  test('the campaign keeps the order baked into the bank', () {
    // Round order is decided when the boards are generated — rank 1..216,
    // Vatican through Russia — and the bake must not re-sort it, however
    // tempting some other measure looks.
    final ranks = [
      for (final c in countries.cast<Map<String, dynamic>>()) c['rank'] as int,
    ];
    expect(ranks, List.generate(ranks.length, (i) => i + 1),
        reason: 'rounds are not in the bank\'s own rank order');
    expect((countries.first as Map<String, dynamic>)['name'], 'Vatican');
    expect((countries.last as Map<String, dynamic>)['name'], 'Russia');
  });

  test('no board falls under the 60-arrow floor', () {
    // Under 60 arrows a board is a demonstration, not a puzzle. The generated
    // bank sits at 80 and up; this catches anything slipping in below it.
    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        expect((stage['lines'] as List).length, greaterThanOrEqualTo(60),
            reason: '${country['name']} / ${stage['name']}');
      }
    }
  });

  test('the campaign is city, country and path boards only', () {
    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        expect(stage['kind'], anyOf('city', 'country', 'path'),
            reason: '${country['name']} carries a ${stage['kind']} stage');
      }
    }
  });

  test('every path stage names a transport silhouette', () {
    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        if (stage['kind'] != 'path') continue;
        expect((stage['vehicle'] as String?) ?? '', isNotEmpty,
            reason: '${country['name']} has a path stage with no vehicle');
      }
    }
  });
}
