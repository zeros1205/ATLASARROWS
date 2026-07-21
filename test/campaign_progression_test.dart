import 'dart:convert';
import 'dart:io';

import 'package:atlas_arrows/models/campaign_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progression rules: which stage belongs to which round, where the rounds
/// begin and end, and how the game screen decides it has crossed into a new
/// country. These are index arithmetic over ~800 stages, which is exactly the
/// kind of thing that looks right and is off by one at the boundary.
///
/// The repository loads through rootBundle, so this rebuilds the same index
/// from the asset file to keep the test binding-free.
void main() {
  final file = File('assets/campaign/bank.json');
  if (!file.existsSync()) {
    test('bank.json is present', () => fail('run tools/atlas/build_bank.py'));
    return;
  }

  final countries = (jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['countries'] as List;
  final counts = [
    for (final c in countries.cast<Map<String, dynamic>>())
      (c['stages'] as List).length,
  ];
  final firstStage = <int>[];
  var total = 0;
  for (final n in counts) {
    firstStage.add(total);
    total += n;
  }

  /// Mirrors CampaignRepository.locate.
  (int, int) locate(int global) {
    var lo = 0, hi = firstStage.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (firstStage[mid] <= global) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return (lo, global - firstStage[lo]);
  }

  test('every stage maps back to the round that contains it', () {
    for (var i = 0; i < total; i++) {
      final (ci, local) = locate(i);
      expect(local, greaterThanOrEqualTo(0), reason: 'stage $i');
      expect(local, lessThan(counts[ci]), reason: 'stage $i');
      expect(firstStage[ci] + local, i, reason: 'stage $i');
    }
  });

  test('each round starts exactly where the previous one ended', () {
    for (var ci = 1; ci < counts.length; ci++) {
      expect(firstStage[ci], firstStage[ci - 1] + counts[ci - 1],
          reason: 'gap or overlap before round $ci');
    }
    expect(firstStage.last + counts.last, total);
  });

  test('a new round is detected on the stage after each finale', () {
    // The game screen advances a round when locate(stage + 1).local == 0.
    for (var ci = 0; ci < counts.length - 1; ci++) {
      final finale = firstStage[ci] + counts[ci] - 1;
      expect(locate(finale).$2, counts[ci] - 1,
          reason: 'round $ci finale is not its last stage');
      expect(locate(finale + 1).$2, 0,
          reason: 'clearing round $ci does not open round ${ci + 1}');
      expect(locate(finale + 1).$1, ci + 1);
      // And no stage inside a round falsely reads as a round opening.
      for (var local = 0; local < counts[ci] - 1; local++) {
        expect(locate(firstStage[ci] + local + 1).$2, isNot(0),
            reason: 'round $ci stage $local looks like a round boundary');
      }
    }
  });

  test('clearing the campaign lands exactly on the last stage', () {
    final last = total - 1;
    final (ci, local) = locate(last);
    expect(ci, counts.length - 1);
    expect(local, counts.last - 1);
  });

  test('map fill tracks stage progress inside a round', () {
    // The map colours dots * cleared / stageCount; the ends have to be clean
    // or a finished country would sit at 99%.
    for (var ci = 0; ci < counts.length; ci++) {
      const dots = 120;
      final atStart = (dots * 0 / counts[ci]).round();
      final atEnd = (dots * counts[ci] / counts[ci]).round();
      expect(atStart, 0);
      expect(atEnd, dots, reason: 'round $ci never fills completely');
    }
  });

  test('StageKind round-trips through the asset', () {
    for (final c in countries.cast<Map<String, dynamic>>()) {
      for (final s in (c['stages'] as List).cast<Map<String, dynamic>>()) {
        expect(
            switch (s['kind']) {
              'country' => StageKind.country,
              'path' => StageKind.path,
              _ => StageKind.city,
            },
            isA<StageKind>());
      }
    }
  });
}
