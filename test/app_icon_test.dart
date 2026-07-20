import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// `assets/icon/icon_fg.png` is the Android adaptive foreground, and it is the
/// easiest asset in the repo to regenerate wrongly because launchers apply
/// OEM-specific masks to a 108dp adaptive-icon layer.
///
/// Only the middle 66dp of that 108dp canvas is guaranteed visible. The source
/// foreground is therefore authored directly in the full 108dp coordinate
/// space, with the important artwork fitted inside the central 66dp safe zone.
///
/// Neither overfilling nor shrinking too far is obvious on a square preview, so
/// both cases are asserted here.
void main() {
  final icon = File('assets/icon/icon.png');
  final foreground = File('assets/icon/icon_fg.png');
  const rebuild = 'run: python tools/icon/build_icon.py';

  test('both icon plates ship', () {
    expect(icon.existsSync(), isTrue, reason: rebuild);
    expect(foreground.existsSync(), isTrue, reason: rebuild);
  });

  if (!icon.existsSync() || !foreground.existsSync()) return;

  test('the store plate is 1024 square', () {
    final head = ByteData.sublistView(
        Uint8List.fromList(icon.readAsBytesSync().sublist(0, 26)));
    expect(head.getUint32(16), 1024);
    expect(head.getUint32(20), 1024);
  });

  test('the adaptive foreground fits the official safe zone', () {
    final plate = img.decodePng(foreground.readAsBytesSync())!;
    final safeSide = plate.width * (66 / 108);
    final safeMin = (plate.width - safeSide) / 2;
    final safeMax = safeMin + safeSide;

    var minX = plate.width;
    var minY = plate.height;
    var maxX = 0;
    var maxY = 0;
    for (var y = 0; y < plate.height; y++) {
      for (var x = 0; x < plate.width; x++) {
        if (plate.getPixel(x, y).a <= 8) continue;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
    final width = maxX - minX + 1;
    final height = maxY - minY + 1;

    expect(minX, greaterThanOrEqualTo(safeMin.floor() - 1),
        reason: 'foreground starts at x=$minX, outside the '
            '${safeSide.round()}px safe zone. $rebuild');
    expect(minY, greaterThanOrEqualTo(safeMin.floor() - 1),
        reason: 'foreground starts at y=$minY, outside the '
            '${safeSide.round()}px safe zone. $rebuild');
    expect(maxX, lessThanOrEqualTo(safeMax.ceil() + 1),
        reason: 'foreground ends at x=$maxX, outside the '
            '${safeSide.round()}px safe zone. $rebuild');
    expect(maxY, lessThanOrEqualTo(safeMax.ceil() + 1),
        reason: 'foreground ends at y=$maxY, outside the '
            '${safeSide.round()}px safe zone. $rebuild');
    expect(math.max(width, height), greaterThan(safeSide * 0.9),
        reason: 'foreground bbox is only ${width}x$height inside a '
            '${safeSide.round()}px safe zone; it will render undersized. '
            '$rebuild');
  });
}
