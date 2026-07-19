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
        expect(s['kind'], 'city',
            reason: '${country['name']} has a non-city before the finale');
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

  test('the opening rounds stay small enough to tap without zooming', () {
    // A board's longest side sets how small its cells get when fitted to a
    // phone. The first rounds have to be comfortable before the player has
    // been taught to pinch.
    for (final country in countries.take(2).cast<Map<String, dynamic>>()) {
      final first = (country['stages'] as List).first as Map<String, dynamic>;
      final longest = [
        (first['rows'] as num).toInt(),
        (first['cols'] as num).toInt(),
      ].reduce((a, b) => a > b ? a : b);
      expect(longest, lessThanOrEqualTo(16),
          reason: '${country['name']} opens on a ${first['rows']}x'
              '${first['cols']} board');
    }
  });

  test('the campaign opens gently and every round is playable', () {
    final firstRound =
        (countries.first as Map<String, dynamic>)['stages'] as List;
    final firstBoard = firstRound.first as Map<String, dynamic>;
    expect((firstBoard['lines'] as List).length, lessThanOrEqualTo(6),
        reason: 'the very first board should be a handful of arrows');

    for (final country in countries.cast<Map<String, dynamic>>()) {
      for (final stage
          in (country['stages'] as List).cast<Map<String, dynamic>>()) {
        expect((stage['lines'] as List), isNotEmpty,
            reason: '${country['name']} / ${stage['name']} has no arrows');
      }
    }
  });
}
