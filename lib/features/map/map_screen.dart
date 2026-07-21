import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import '../../shared/motion.dart';
import 'round_intro_screen.dart';

/// The map tab: a full-screen dotted world map. Land dots are coloured by
/// campaign progress — the in-progress country in accent, cleared countries a
/// brighter accent, locked/other land faint grey. The map fills the screen
/// height and scrolls left/right only (no zoom, no vertical pan); the header
/// and the shell's tab bar float over it. Opens scrolled to the next-stage
/// beacon; tap a country to open its round intro.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _wm = WorldMap.instance;
  final _repo = CampaignRepository.instance;
  final _hc = ScrollController();
  late final AnimationController _radar = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1900));
  bool _ready = false;
  bool _centered = false;

  /// Where the next-stage radar sits, in (row, col) grid coords — the stage's
  /// own city pin where it has one, otherwise its country's dot centroid.
  /// Memoized against the stage it was computed for so the pulsing layer never
  /// rescans per frame. [_hasHot] is false when there's nowhere to mark.
  int _hotFor = -1;
  double _hotR = 0, _hotC = 0;
  bool _hasHot = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _wm.load();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour OS reduce-motion: hold the rings static instead of sweeping.
    if (reduceMotion(context)) {
      _radar.stop();
    } else if (!_radar.isAnimating) {
      _radar.repeat();
    }
  }

  @override
  void dispose() {
    _radar.dispose();
    _hc.dispose();
    super.dispose();
  }

  /// Recomputes where the radar sits when the next stage changes: the stage's
  /// city pin if it has one, else the current country's dot centroid.
  void _ensureHot() {
    final stage = _currentStage;
    if (_hotFor == stage) return;
    _hotFor = stage;
    final pin = _wm.pinAt(stage);
    if (pin != null) {
      _hotC = pin.$1;
      _hotR = pin.$2;
      _hasHot = true;
      return;
    }
    final ci = _currentCountry;
    var sr = 0.0, sc = 0.0, n = 0;
    for (var r = 0; r < _wm.rows; r++) {
      for (var c = 0; c < _wm.cols; c++) {
        if (_wm.countryOfCell(_wm.cellAt(r, c)) == ci) {
          sr += r;
          sc += c;
          n++;
        }
      }
    }
    _hasHot = n > 0;
    if (_hasHot) {
      _hotR = sr / n;
      _hotC = sc / n;
    }
  }

  /// The next stage to play — the one the radar marks.
  int get _currentStage => !_repo.isLoaded
      ? 0
      : Progress.instance.unlocked.value
          .clamp(0, (_repo.totalStages - 1).clamp(0, 1 << 30));

  int get _currentCountry =>
      _repo.isLoaded ? _repo.locate(_currentStage).$1 : 0;

  /// How many of the current country's dots are coloured in — its cleared
  /// stages as a share of its round.
  int get _currentFilled {
    if (!_repo.isLoaded) return 0;
    final u = Progress.instance.unlocked.value
        .clamp(0, (_repo.totalStages - 1).clamp(0, 1 << 30));
    final (ci, local) = _repo.locate(u);
    final total = _repo.countries[ci].stageCount;
    if (total == 0) return 0;
    return (_wm.dotsOf(ci) * local / total).round();
  }

  /// Scrolls horizontally so the next-stage beacon sits in the middle of the
  /// viewport. Leaves the map at the start if there's nowhere to mark.
  void _centerOnCurrent(double mapWidth, double viewport) {
    _ensureHot();
    if (!_hasHot) return;
    final centerX = (_hotC + 0.5) / _wm.cols * mapWidth;
    _hc.jumpTo((centerX - viewport / 2).clamp(0.0, math.max(0.0, mapWidth - viewport)));
  }

  void _onTapUp(TapUpDetails d, Size world) {
    final cw = world.width / _wm.cols, ch = world.height / _wm.rows;
    final c = (d.localPosition.dx / cw).floor();
    final r = (d.localPosition.dy / ch).floor();
    if (r < 0 || r >= _wm.rows || c < 0 || c >= _wm.cols) return;
    final ci = _wm.countryOfCell(_wm.cellAt(r, c));
    if (ci == null) return; // sea or non-campaign land
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RoundIntroScreen(countryIndex: ci)));
  }

  @override
  Widget build(BuildContext context) {
    final col = AppColors.of(context);
    // StackFit.expand ties the map to the full screen. Without it the Stack
    // would shrink-wrap its only non-positioned child — the min-height header —
    // and the map would collapse to a thin band at the top.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: !_ready
              ? Center(child: CircularProgressIndicator(color: col.accent))
              : !_wm.isLoaded
                  ? Center(
                      child: Text('지도를 불러올 수 없습니다.',
                          style: TextStyle(color: col.inkFaint)))
                  : LayoutBuilder(
                      builder: (context, cons) {
                        // Fill the screen height; the width follows the map's
                        // aspect ratio, so it overflows sideways and the only
                        // gesture left is a horizontal scroll.
                        final h = cons.maxHeight;
                        final w = h * _wm.cols / _wm.rows;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_centered && mounted && _hc.hasClients) {
                            _centered = true;
                            _centerOnCurrent(w, cons.maxWidth);
                          }
                        });
                        final reduce = reduceMotion(context);
                        return ValueListenableBuilder<int>(
                          valueListenable: Progress.instance.unlocked,
                          builder: (context, _, _) {
                            _ensureHot();
                            return SingleChildScrollView(
                              controller: _hc,
                              scrollDirection: Axis.horizontal,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) => _onTapUp(d, Size(w, h)),
                                child: SizedBox(
                                  width: w,
                                  height: h,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(w, h),
                                        painter: _WorldPainter(_wm,
                                            _currentCountry, _currentFilled, col),
                                      ),
                                      // Next-stage beacon: a radar pulse on the
                                      // stage's city pin (or its country centre).
                                      if (_hasHot)
                                        Positioned.fill(
                                          child: reduce
                                              ? CustomPaint(
                                                  painter: _RadarMapPainter(_wm,
                                                      _hotR, _hotC, col, 0,
                                                      reduce: true))
                                              : AnimatedBuilder(
                                                  animation: _radar,
                                                  builder: (_, __) => CustomPaint(
                                                      painter: _RadarMapPainter(
                                                          _wm,
                                                          _hotR,
                                                          _hotC,
                                                          col,
                                                          _radar.value,
                                                          reduce: false)),
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
        // Header floats over the map with a transparent background. Pinned to
        // the top (not stretched) so StackFit.expand doesn't force it full-height.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MetaHeader('맵'),
                // The campaign runs smallest territory first, so the opening
                // rounds colour a handful of dots that are easy to miss on a
                // world map. A plain count makes the progress legible until the
                // countries get big enough to see.
                ValueListenableBuilder<int>(
                  valueListenable: Progress.instance.unlocked,
                  builder: (context, _, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _repo.isLoaded
                          ? '$_currentCountry개국 완료 · ${_repo.countries.length}개국 중'
                          : '',
                      style: AppText.caption.copyWith(color: col.inkFaint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the dotted world, coloured by campaign progress.
///
/// The map is the game's reward surface, so it has to move every single stage,
/// not once per country: the country in play is filled in proportion to the
/// stages cleared inside it.
class _WorldPainter extends CustomPainter {
  _WorldPainter(this.wm, this.current, this.currentFilled, this.c);
  final WorldMap wm;
  final int current;

  /// Dots of the current country that are already coloured in.
  final int currentFilled;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / wm.cols, ch = size.height / wm.rows;
    final rLand = math.min(cw, ch) * 0.36;
    final done = Paint()..color = c.accent;
    // Cleared rounds read as "beyond" the active accent, so lift the accent
    // toward white — brighter than the country currently in play.
    final cleared = Paint()
      ..color = Color.lerp(c.accent, Colors.white, 0.45)!;
    final locked = Paint()..color = c.inkFaint.withValues(alpha: 0.55);
    for (var r = 0; r < wm.rows; r++) {
      for (var col = 0; col < wm.cols; col++) {
        final i = r * wm.cols + col;
        final v = wm.cells[i];
        final o = Offset(col * cw + cw / 2, r * ch + ch / 2);
        if (v < 0) continue; // sea — dots only on land
        final ci = wm.countryOfCell(v);
        final Paint p;
        if (ci == null || ci > current) {
          p = locked;
        } else if (ci < current) {
          p = cleared; // finished rounds — brighter than the active accent
        } else {
          p = wm.ordinalAt(i) < currentFilled ? done : locked;
        }
        canvas.drawCircle(o, rLand, p);
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.current != current ||
      old.currentFilled != currentFilled ||
      old.c != c;
}

/// The next-stage beacon: sonar rings and a centre pulse over the stage's map
/// pin ([cr], [cc] in grid coords). [t] is the controller value in [0,1); under
/// reduce-motion the rings hold static. A fixed minimum ring radius keeps the
/// beacon legible even when a single dot marks a micro-nation.
class _RadarMapPainter extends CustomPainter {
  _RadarMapPainter(this.wm, this.cr, this.cc, this.c, this.t,
      {required this.reduce});
  final WorldMap wm;
  final double cr, cc, t;
  final AppColors c;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / wm.cols; // cells are square (see build())
    final cx = (cc + 0.5) * cell, cy = (cr + 0.5) * cell;
    final rDot = cell * 0.36;
    final ringMax = math.max(cell * 4.0, 30.0);

    void ring(double rad, double alpha) {
      canvas.drawCircle(
          Offset(cx, cy),
          rad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c.accent.withValues(alpha: alpha.clamp(0, 1)));
    }

    if (reduce) {
      ring(ringMax * 0.62, 0.5);
      ring(ringMax * 0.34, 0.8);
    } else {
      for (var k = 0; k < 2; k++) {
        final ph = (t + k / 2) % 1;
        ring(rDot + (ringMax - rDot) * ph, (1 - ph) * 0.85);
      }
    }

    final pulse =
        reduce ? 1.0 : 0.78 + 0.22 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3));
    canvas.drawCircle(
        Offset(cx, cy), rDot * 1.05 * pulse, Paint()..color = c.accent);
  }

  @override
  bool shouldRepaint(_RadarMapPainter old) =>
      old.t != t || old.c != c || old.cr != cr || old.cc != cc;
}
