import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The cold-start loading plate places the lockup with
/// `FractionallySizedBox(widthFactor: 0.61)` — measured against the viewport,
/// not the ink. So a lockup that is too small, or padded with transparent
/// margin, silently draws smaller than designed and sits wrong against the
/// caption. The kit's rules (APP_WORDMARK_AND_LOADING.md §2) are checked here
/// because the asset is generated and could be regenerated wrong.
void main() {
  final file = File('assets/images/brand/atlas_arrows_wordmark.png');

  test('the wordmark ships', () {
    expect(file.existsSync(), isTrue,
        reason: 'run: python tools/atlas/build_wordmark.py');
  });

  if (!file.existsSync()) return;

  // PNG: 8-byte signature, then the IHDR chunk — width, height, depth, colour.
  final bytes = file.readAsBytesSync();
  final head = ByteData.sublistView(Uint8List.fromList(bytes));
  final width = head.getUint32(16);
  final height = head.getUint32(20);
  final colourType = head.getUint8(25);

  test('it is a truecolour-with-alpha PNG', () {
    // Type 6 = RGBA. A flattened lockup would paint its own background over
    // the cream plate.
    expect(colourType, 6);
  });

  test('it is wide enough and in proportion', () {
    expect(width, greaterThanOrEqualTo(592));
    final ratio = width / height;
    expect(ratio, inInclusiveRange(2.5, 3.0),
        reason: 'two-line lockup should sit near 2.7:1, got '
            '${ratio.toStringAsFixed(2)}:1');
  });
}
