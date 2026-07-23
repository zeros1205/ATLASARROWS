import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../models/world_map.dart';
import '../game/game_screen.dart';

/// Everything the home→play dive needs to zoom the globe into one country's
/// marker: the home map's on-screen rectangle (so the dive starts pixel-matched
/// to what the player is looking at), the target country's lit cells, and their
/// centroid in grid coordinates (the point the dive falls toward).
class DiveArgs {
  DiveArgs._(this.mapRect, this.cr, this.cc, this.hot);

  /// Global rectangle the home world map occupied at the moment of the tap.
  final Rect mapRect;

  /// The beacon cell's grid (row, col) — the exact lit dot the camera dives
  /// into. Was the centroid, but for a small country the rounded centroid could
  /// land on a neighbouring *unlit* (grey) cell, so the fall targeted a grey dot
  /// next to the blue beacon instead of the beacon itself.
  final double cr, cc;

  /// Linear cell index (as a one-element list) of the destination beacon — the
  /// single dot drawn lit and dived into. It is the country's own cell nearest
  /// the centroid, not the whole country: lighting every cell made a small
  /// nation read as two or three beacons during the fall (there is no sonar
  /// ring here to unify them, unlike the home map).
  final List<int> hot;

  /// Builds the dive data for [target] (a campaign country index), or null when
  /// the map isn't loaded or the country has no cells — the caller then falls
  /// back to a plain page push.
  static DiveArgs? of(Rect mapRect, int target) {
    final wm = WorldMap.instance;
    if (!wm.isLoaded || target < 0) return null;
    final cells = <int>[];
    var sr = 0.0, sc = 0.0;
    for (var i = 0; i < wm.cells.length; i++) {
      if (wm.countryOfCell(wm.cells[i]) == target) {
        cells.add(i);
        sr += i ~/ wm.cols;
        sc += i % wm.cols;
      }
    }
    if (cells.isEmpty) return null;
    final cr = sr / cells.length, cc = sc / cells.length;
    // The one beacon cell: closest to the centroid.
    var beacon = cells.first;
    var best = double.infinity;
    for (final i in cells) {
      final dr = i ~/ wm.cols - cr, dc = i % wm.cols - cc;
      final d = dr * dr + dc * dc;
      if (d < best) {
        best = d;
        beacon = i;
      }
    }
    // Dive into the beacon cell itself, not the centroid — otherwise the
    // camera can fall toward a grey cell next to the lit blue dot.
    return DiveArgs._(mapRect, (beacon ~/ wm.cols).toDouble(),
        (beacon % wm.cols).toDouble(), [beacon]);
  }
}

/// The sky-dive's fall duration, and the fade-to-paper at the tail of it — the
/// scene fades out over the last [_diveFadeMs] of the fall before the blank.
const int _diveMs = 760;
const int _diveFadeMs = 200;

/// The route home's play button pushes: an opaque, instant swap to the game.
/// It swaps with no transition of its own because [_DiveOverlay] (mounted by
/// the game screen) reproduces the home map pixel-for-pixel on its first frame,
/// so the cut is invisible and the dive carries the motion from there.
Route<void> playDiveRoute(int stage, DiveArgs dive) => PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => GameScreen(stage: stage, dive: dive),
    );

/// Phase 2–3a of the transition: the camera falls from the sky into the target
/// marker. The whole dotted world is drawn at the home map's exact position and
/// then scaled up around the marker with accelerating speed, so far dots fly off
/// the edges while the marker swells to fill the screen. In the last stretch a
/// paper cover fades in over everything — the brief blank before the board.
class _DiveOverlay extends StatefulWidget {
  const _DiveOverlay({required this.args, required this.onDone});

  final DiveArgs args;
  final VoidCallback onDone;

  @override
  State<_DiveOverlay> createState() => _DiveOverlayState();
}

class _DiveOverlayState extends State<_DiveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _diveMs));
  bool _blank = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (!mounted) return;
      // Hold the blank paper for a beat, then hand off to the board intro.
      setState(() => _blank = true);
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_blank) return ColoredBox(color: c.bg);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _DivePainter(WorldMap.instance, widget.args, c, _c.value),
      ),
    );
  }
}

/// Contain-fit the [wm] grid into [size] — the same math the home map uses, so
/// the dive's first frame lands on the home dots exactly.
({double scale, double dx, double dy}) _fit(WorldMap wm, Size size) {
  final scale = math.min(size.width / wm.cols, size.height / wm.rows);
  return (
    scale: scale,
    dx: (size.width - wm.cols * scale) / 2,
    dy: (size.height - wm.rows * scale) / 2,
  );
}

class _DivePainter extends CustomPainter {
  _DivePainter(this.wm, this.args, this.c, this.t);
  final WorldMap wm;
  final DiveArgs args;
  final AppColors c;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.bg);
    final f = _fit(wm, args.mapRect.size);
    final r = args.mapRect;

    // Home-frame screen position of a grid cell's centre.
    Offset home(int row, int col) => Offset(
          r.left + f.dx + (col + 0.5) * f.scale,
          r.top + f.dy + (row + 0.5) * f.scale,
        );

    // The marker the camera dives into, and the zoom around it. The scale eases
    // *in* (t³) so it reads as a fall gathering speed. zMax is picked so one
    // cell grows to roughly fill the screen at touchdown.
    final marker = home(args.cr.round(), args.cc.round());
    final zMax = math.max(size.width, size.height) / f.scale * 0.9;
    final z = 1 + (zMax - 1) * (t * t * t);

    Offset screen(Offset h) => marker + (h - marker) * z;

    final hot = args.hot.toSet();
    final faint = Paint()..color = c.inkSoft.withValues(alpha: 0.82);
    final solid = Paint()..color = c.accent;
    final bounds = Offset.zero & size;
    final rFaint = f.scale * 0.30 * z, rHot = f.scale * 0.44 * z;

    // Faint land first, then the lit marker over it. Both are culled to the
    // viewport so the deep zoom only ever draws the handful of dots on screen.
    for (var i = 0; i < wm.cells.length; i++) {
      if (wm.cells[i] < 0 || hot.contains(i)) continue;
      final p = screen(home(i ~/ wm.cols, i % wm.cols));
      if (!bounds.inflate(rFaint).contains(p)) continue;
      canvas.drawCircle(p, rFaint, faint);
    }
    for (final i in hot) {
      final p = screen(home(i ~/ wm.cols, i % wm.cols));
      if (!bounds.inflate(rHot).contains(p)) continue;
      canvas.drawCircle(p, rHot, solid);
    }

    // Fade the scene out to paper over the last [_diveFadeMs] of the fall, so
    // it dissolves into the blank instead of cutting. Smooth in and out.
    const washStart = (_diveMs - _diveFadeMs) / _diveMs;
    final wash = Curves.easeInOut
        .transform(((t - washStart) / (1 - washStart)).clamp(0.0, 1.0));
    if (wash > 0) {
      canvas.drawRect(bounds, Paint()..color = c.bg.withValues(alpha: wash));
    }
  }

  @override
  bool shouldRepaint(_DivePainter old) => old.t != t || old.c != c;
}

/// Mounts the dive overlay over [child] (the game screen) until the fall
/// finishes, then removes itself and fires [onDone].
class DiveLayer extends StatelessWidget {
  const DiveLayer({super.key, required this.args, required this.onDone});
  final DiveArgs args;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: _DiveOverlay(args: args, onDone: onDone));
}
