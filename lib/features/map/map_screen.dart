import 'dart:async';
import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import 'country_detail_screen.dart';

/// The map tab: a full-screen dotted world map. Land dots are coloured by
/// campaign progress — the in-progress country in accent, cleared countries a
/// brighter accent, locked/other land faint grey. The map fills the screen
/// height; at the 1x default it pans left/right only (endless loop), and pinch
/// zooms in to 2x, where the extra height can be panned too. Pinching back to 1x
/// or the my-location button restore the default, centred on the next-stage
/// beacon.
/// The dot band runs from just below the title header down to the top line of
/// the shell's floating tab bar. Each country carries a pin; tapping one names
/// it. Bare land is not tappable — it used to open the round intro, which no
/// player could have guessed was there.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _wm = WorldMap.instance;
  final _repo = CampaignRepository.instance;
  // Pan + pinch-zoom (1x..2x) live in one matrix; the map has no separate
  // scroll controller any more.
  final _tc = TransformationController();

  /// Viewport size, captured at layout for the recentre + wrap/clamp maths.
  double _viewportW = 0, _viewportH = 0;

  /// Guards the wrap listener from recursing when it (or a recentre) writes the
  /// controller.
  bool _wrapping = false;
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
    // The shell keeps every tab mounted in an IndexedStack, so this screen's
    // initState (and the one-time postFrame centering below) only ever fires
    // once for the whole app session — not each time the player actually
    // switches to this tab. Recentre explicitly on every switch instead, so
    // "open the map" always shows the current next-stage beacon, not wherever
    // the last visit happened to leave the scroll position.
    appTab.addListener(_onTabChanged);
    _tc.addListener(_wrapMatrix);
  }

  void _onTabChanged() {
    _updateRadar();
    if (appTab.value == 1) _recenter();
  }

  /// The radar only sweeps while the map is the visible tab — the shell keeps
  /// this screen mounted in an IndexedStack, so without this the animation would
  /// burn a frame every tick on home/shop/settings too. Also honours OS
  /// reduce-motion.
  void _updateRadar() {
    if (!mounted) return;
    final shouldRun = appTab.value == 1 && !reduceMotion(context);
    if (shouldRun) {
      if (!_radar.isAnimating) _radar.repeat();
    } else if (_radar.isAnimating) {
      _radar.stop();
    }
  }

  Future<void> _load() async {
    await _wm.load();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRadar();
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _radar.dispose();
    _tc.removeListener(_wrapMatrix);
    _tc.dispose();
    appTab.removeListener(_onTabChanged);
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

  /// Symmetric breathing room inside the map band, above and below the dots, so
  /// the northern edge (Greenland) and the southern edge don't sit flush against
  /// the header or the tab bar. The whole latitude range is always fitted into
  /// the remaining height, so nothing is cropped or squashed — only smaller.
  static const double _padV = 22;

  /// How many copies of the world sit side by side. Three is the minimum that
  /// lets the offset be wrapped onto the middle one from either direction.
  static const int _copies = 3;

  /// Width of one copy, captured at layout so the scroll wrap can use it.
  double _copyW = 0;

  /// Which copy the open popup was tapped on, so the bubble lands on the pin
  /// the player actually pressed.
  int _popupCopy = 1;

  /// Content-x (unscaled) of grid column [col] on the middle copy.
  double _beaconChildX(double col) =>
      _copyW + (col + 0.5) / _wm.cols * _copyW;

  /// Restore-to-default: scale 1 with the beacon column horizontally centred and
  /// the map at its top inset (ty 0). The my-location button and opening the map
  /// both call this — so "open the map" always shows the current next-stage
  /// beacon at 1x, not wherever the last pinch/pan left it.
  void _recenter() {
    _ensureHot();
    if (!_hasHot || _copyW <= 0 || _viewportW <= 0) return;
    _wrapping = true;
    _tc.value = Matrix4.identity()
      ..storage[12] = _viewportW / 2 - _beaconChildX(_hotC);
    _wrapping = false;
  }

  /// Runs on every controller change (the viewer uses an infinite boundary, so
  /// we bound it ourselves, the way the board does in game_screen):
  ///  - horizontal: keep the pan on the middle copy so the world reads as an
  ///    endless loop. The copies are identical, so a whole-copy shift is unseen.
  ///  - vertical: no slack at 1x (left/right only); zoomed in, keep the content
  ///    covering the viewport instead of drifting off the top or bottom.
  void _wrapMatrix() {
    if (_wrapping || _copyW <= 0 || _viewportW <= 0) return;
    final m = _tc.value;
    final s = m.getMaxScaleOnAxis();
    final tx = m.storage[12], ty = m.storage[13];
    final centerX = (_viewportW / 2 - tx) / s; // content-x under the centre
    var newTx = tx;
    if (centerX < _copyW * 0.5) {
      newTx = tx - s * _copyW;
    } else if (centerX > _copyW * 1.5) {
      newTx = tx + s * _copyW;
    }
    // content height == viewport height, so at scale s the vertical travel is
    // [_viewportH*(1-s), 0]; at s==1 that pins ty to 0.
    final newTy = ty.clamp(_viewportH * (1 - s), 0.0);
    if (newTx == tx && newTy == ty) return;
    _wrapping = true;
    _tc.value = m.clone()
      ..storage[12] = newTx
      ..storage[13] = newTy;
    _wrapping = false;
  }

  // ── Country markers ─────────────────────────────────────────────────────
  // Tapping bare land used to open the round intro, which gave the player no
  // way to know a country was tappable at all. Only these markers are hot now.

  /// One tappable marker per campaign country, at its dot centroid in grid
  /// coordinates. Built once, the first time the map paints.
  List<({int ci, double r, double c})> _markers = const [];

  /// The marker whose name bubble is showing, or null. Cleared by [_popupTimer]
  /// 1.2s after it opens.
  ({int ci, double r, double c})? _popup;
  Timer? _popupTimer;

  void _ensureMarkers() {
    if (_markers.isNotEmpty || !_wm.isLoaded || !_repo.isLoaded) return;
    final sr = <int, double>{}, sc = <int, double>{}, n = <int, int>{};
    for (var i = 0; i < _wm.cells.length; i++) {
      final ci = _wm.countryOfCell(_wm.cells[i]);
      if (ci == null) continue;
      sr[ci] = (sr[ci] ?? 0) + i ~/ _wm.cols;
      sc[ci] = (sc[ci] ?? 0) + i % _wm.cols;
      n[ci] = (n[ci] ?? 0) + 1;
    }
    _markers = [
      for (final ci in n.keys)
        (ci: ci, r: sr[ci]! / n[ci]!, c: sc[ci]! / n[ci]!),
    ];
  }

  void _onTapUp(TapUpDetails d, double w, double h) {
    // The map is drawn _padV below the content top; ignore taps in that margin
    // or in the empty band below (behind the tab bar).
    final localY = d.localPosition.dy - _padV;
    if (localY < 0 || localY > h) return;
    final cw = w / _wm.cols, ch = h / _wm.rows;
    // The world repeats; fold the tap onto one copy, remembering which.
    final copy = (d.localPosition.dx / w).floor();
    final localX = d.localPosition.dx - copy * w;
    // Nearest marker within a finger's reach, in map pixels.
    ({int ci, double r, double c})? best;
    var bestD = double.infinity;
    for (final m in _markers) {
      final dx = (m.c + 0.5) * cw - localX;
      final dy = (m.r + 0.5) * ch - localY;
      final dist = dx * dx + dy * dy;
      if (dist < bestD) {
        bestD = dist;
        best = m;
      }
    }
    if (best == null || bestD > _tapRadius * _tapRadius) return;
    _popupTimer?.cancel();
    setState(() {
      _popup = best;
      _popupCopy = copy;
    });
    // The bubble is tappable now, so hold it long enough to reach for the
    // chevron before it clears itself.
    _popupTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _popup = null);
    });
  }

  /// Opens the country sheet from a tapped name bubble.
  void _openCountry(int ci) {
    _popupTimer?.cancel();
    setState(() => _popup = null);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CountryDetailScreen(countryIndex: ci)));
  }

  static const double _tapRadius = 22;

  @override
  Widget build(BuildContext context) {
    final col = AppColors.of(context);
    final l = AppLocalizations.of(context);
    // Header on top, map below it. The map area then runs from the header's
    // bottom edge (this column's split) down to the top line of the floating
    // tab bar — no measuring, the Expanded gives exactly that band.
    return Column(
      children: [
        SafeArea(bottom: false, child: MetaHeader(l.tabMap)),
        Expanded(
          child: !_ready
              ? Center(child: CircularProgressIndicator(color: col.accent))
              : !_wm.isLoaded
                  ? Center(
                      child: Text(l.mapLoadError,
                          style: TextStyle(color: col.inkFaint)))
                  : LayoutBuilder(
                      builder: (context, cons) {
                        // The tab bar floats over this screen (extendBody), so
                        // the map's content is the full area height but its dots
                        // stop [botInset] short — the tab bar's top line. A _padV
                        // margin is left above and below the dots (below the
                        // header, above the bar) for visual stability.
                        final botInset = kTabBarSlot +
                            MediaQuery.viewPaddingOf(context).bottom;
                        final vpH = cons.maxHeight;
                        final h = math.max(vpH - botInset - 2 * _padV, 1.0);
                        final w = h * _wm.cols / _wm.rows;
                        _viewportW = cons.maxWidth;
                        _viewportH = vpH;
                        _copyW = w;
                        _ensureMarkers();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_centered && mounted && _viewportW > 0) {
                            _centered = true;
                            _recenter();
                          }
                        });
                        final reduce = reduceMotion(context);
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ValueListenableBuilder<int>(
                                valueListenable: Progress.instance.unlocked,
                                builder: (context, _, _) {
                                  _ensureHot();
                                  // Pan (endless-loop wrap) + pinch-zoom to 2x.
                                  // Content is the full area height with the map
                                  // at the top, so scale 1 has no vertical slack
                                  // (left/right only); zoomed in, the extra
                                  // height can be panned.
                                  return InteractiveViewer(
                                    transformationController: _tc,
                                    constrained: false,
                                    minScale: 1,
                                    maxScale: 2,
                                    // Infinite margin = the viewer never clamps;
                                    // we bound pan ourselves in [_wrapMatrix].
                                    boundaryMargin:
                                        const EdgeInsets.all(double.infinity),
                                    child: SizedBox(
                                      width: w * _copies,
                                      height: vpH,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapUp: (d) => _onTapUp(d, w, h),
                                        child: Stack(
                                          children: [
                                            // Three copies side by side, the pan
                                            // wrapped onto the middle one so the
                                            // Pacific can be read whole. Inset by
                                            // _padV so the dots keep a top margin.
                                            Positioned(
                                              top: _padV,
                                              left: 0,
                                              child: Row(
                                                children: [
                                                  for (var i = 0;
                                                      i < _copies;
                                                      i++)
                                                    CustomPaint(
                                                      size: Size(w, h),
                                                      painter: _WorldPainter(
                                                          _wm,
                                                          _currentCountry,
                                                          _currentFilled,
                                                          col),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Markers, then the beacon on top.
                                            Positioned(
                                              top: _padV,
                                              left: 0,
                                              child: Row(
                                                children: [
                                                  for (var i = 0;
                                                      i < _copies;
                                                      i++)
                                                    CustomPaint(
                                                      size: Size(w, h),
                                                      painter: _MarkerPainter(
                                                          _wm, _markers, col),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (_hasHot)
                                              Positioned(
                                                top: _padV,
                                                left: 0,
                                                // Own layer: the per-frame pulse
                                                // must not re-raster the static
                                                // dots beneath it.
                                                child: RepaintBoundary(
                                                  child: Row(
                                                  children: [
                                                    for (var i = 0;
                                                        i < _copies;
                                                        i++)
                                                      reduce
                                                          ? CustomPaint(
                                                              size: Size(w, h),
                                                              painter:
                                                                  _RadarMapPainter(
                                                                      _wm,
                                                                      _hotR,
                                                                      _hotC,
                                                                      col,
                                                                      0,
                                                                      reduce:
                                                                          true))
                                                          : AnimatedBuilder(
                                                              animation: _radar,
                                                              builder: (_, __) =>
                                                                  CustomPaint(
                                                                size:
                                                                    Size(w, h),
                                                                painter:
                                                                    _RadarMapPainter(
                                                                        _wm,
                                                                        _hotR,
                                                                        _hotC,
                                                                        col,
                                                                        _radar
                                                                            .value,
                                                                        reduce:
                                                                            false),
                                                              ),
                                                            ),
                                                  ],
                                                )),
                                              ),
                                            if (_popup != null)
                                              _CountryBubble(
                                                country: _repo
                                                    .countries[_popup!.ci],
                                                onTap: () =>
                                                    _openCountry(_popup!.ci),
                                                at: Offset(
                                                    _popupCopy * w +
                                                        (_popup!.c + 0.5) *
                                                            w /
                                                            _wm.cols,
                                                    _padV +
                                                        (_popup!.r + 0.5) *
                                                            h /
                                                            _wm.rows),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Back to the next stage, the way a maps app
                            // recentres on you. Just above the floating tab bar.
                            Positioned(
                              right: 16,
                              bottom: botInset + 12,
                              child: _MyLocationButton(onTap: _recenter),
                            ),
                          ],
                        );
                      },
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

/// A tappable pin per campaign country, at its dot centroid. Without these the
/// map gave no clue that anything on it could be opened.
class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.wm, this.markers, this.c);
  final WorldMap wm;
  final List<({int ci, double r, double c})> markers;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / wm.cols, ch = size.height / wm.rows;
    final fill = Paint()..color = c.ink.withValues(alpha: 0.72);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = c.bg.withValues(alpha: 0.9);
    for (final m in markers) {
      final o = Offset((m.c + 0.5) * cw, (m.r + 0.5) * ch);
      canvas.drawCircle(o, 4.5, fill);
      canvas.drawCircle(o, 4.5, rim);
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.c != c || !identical(old.markers, markers);
}

/// Flag + name + chevron in a rounded plate, pointing at the marker that opened
/// it. Tapping it opens the country sheet. Positioned by its bottom edge so it
/// always sits above the pin.
class _CountryBubble extends StatelessWidget {
  const _CountryBubble(
      {required this.country, required this.at, required this.onTap});
  final CampaignCountry country;
  final Offset at;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // No fixed width: the plate grows with the name. A box sized to fit the
    // average country clips the long ones, and a clipped country name is the
    // one thing this popup exists to show.
    //
    // FractionalTranslation centres it on the pin and lifts it clear without
    // anyone having to know how wide the name turned out to be.
    return Positioned(
      left: at.dx,
      top: at.dy - 12,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1),
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.line),
              boxShadow: [
                BoxShadow(color: c.shadow, blurRadius: 16, spreadRadius: -6,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (country.iso.length == 2) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c.line, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CountryFlag.fromCountryCode(country.iso,
                          theme: const ImageTheme(width: 24, height: 18)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(country.nameFor(Localizations.localeOf(context).languageCode),
                    softWrap: false,
                    style: AppText.label.copyWith(color: c.ink)),
                // Chevron: this bubble opens the country sheet.
                Icon(Icons.chevron_right_rounded, size: 20, color: c.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The recentre control every maps app has, bottom-right, semi-transparent so
/// the map reads through it.
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(color: c.line.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(color: c.shadow, blurRadius: 18, spreadRadius: -8,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Icon(Icons.my_location, size: 24, color: c.ink),
      ),
    );
  }
}
