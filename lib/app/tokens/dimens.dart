import 'package:flutter/animation.dart';

/// Corner radii (px).
abstract final class AppRadius {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 28;
  static const double pill = 999;
}

/// 4-pt spacing grid (px). [md] is the default gap.
abstract final class AppGap {
  static const double xxs = 2, xs = 4, sm = 8, md = 12, lg = 16, xl = 24,
      xxl = 32, xxxl = 48;
}

/// Motion durations. Everything degrades under OS reduce-motion.
abstract final class AppDur {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 400);
  static const celebrate = Duration(milliseconds: 900);
}

/// Motion curves.
abstract final class AppCurve {
  static const gentle = Curves.easeOutCubic;
  static const snap = Curves.easeOutQuint;
  static const smooth = Curves.easeInOutCubic;
  /// The universal press signature: down 0.96, release overshoots.
  static const overshoot = Curves.easeOutBack;
}
