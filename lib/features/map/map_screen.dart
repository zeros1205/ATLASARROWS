import 'dart:async';
import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';

/// The map tab: a full-screen dotted world map. Land dots are coloured by
/// campaign progress — the in-progress country in accent, cleared countries a
/// brighter accent, locked/other land faint grey. The map fills the screen
/// height and scrolls left/right only (no zoom, no vertical pan); the header
/// and the shell's tab bar float over it. Opens scrolled to the next-stage
/// beacon, with a recentre button to come back to it. Each country carries a
/// pin; tapping one names it. Bare land is not tappable — it used to open the
/// round intro, which no player could have guessed was there.
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
    // The shell keeps every tab mounted in an IndexedStack, so this screen's
    // initState (and the one-time postFrame centering below) only ever fires
    // once for the whole app session — not each time the player actually
    // switches to this tab. Recentre explicitly on every switch instead, so
    // "open the map" always shows the current next-stage beacon, not wherever
    // the last visit happened to leave the scroll position.
    appTab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (appTab.value != 1 || _copyW <= 0 || !_hc.hasClients) return;
    _centerOnCurrent(_copyW, _hc.position.viewportDimension);
  }

  Future<void> _load() async {
    _hc.addListener(_wrapScroll);
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
    _popupTimer?.cancel();
    _radar.dispose();
    _hc.removeListener(_wrapScroll);
    _hc.dispose();
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

  /// Breathing room above and below the map. There is no horizontal inset any
  /// more: with the map looping there is no edge for one to sit against.
  static const double _padV = 30;

  /// How many copies of the world sit side by side. Three is the minimum that
  /// lets the offset be wrapped onto the middle one from either direction.
  static const int _copies = 3;

  /// Width of one copy, captured at layout so the scroll wrap can use it.
  double _copyW = 0;

  /// Which copy the open popup was tapped on, so the bubble lands on the pin
  /// the player actually pressed.
  int _popupCopy = 1;

  /// Scroll offset that puts grid column [col] in the middle of the viewport,
  /// on the middle copy.
  double _offsetFor(double col, double mapWidth, double viewport) =>
      mapWidth + (col + 0.5) / _wm.cols * mapWidth - viewport / 2;

  /// Slides the offset back onto the middle copy whenever it drifts onto a
  /// neighbour. The copies are identical, so the jump is invisible.
  void _wrapScroll() {
    final w = _copyW;
    if (w <= 0 || !_hc.hasClients) return;
    final o = _hc.offset;
    if (o < w * 0.5) {
      _hc.jumpTo(o + w);
    } else if (o > w * 1.5) {
      _hc.jumpTo(o - w);
    }
  }

  /// Scrolls horizontally so the next-stage beacon sits in the middle of the
  /// viewport. Leaves the map at the start if there's nowhere to mark.
  void _centerOnCurrent(double mapWidth, double viewport) {
    _ensureHot();
    if (!_hasHot) return;
    _hc.jumpTo(_offsetFor(_hotC, mapWidth, viewport));
  }

  /// The 'my location' button: glide back to the next-stage beacon.
  void _goToCurrent(double mapWidth, double viewport) {
    _ensureHot();
    if (!_hasHot || !_hc.hasClients) return;
    _hc.animateTo(_offsetFor(_hotC, mapWidth, viewport),
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
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

  void _onTapUp(TapUpDetails d, Size world) {
    final cw = world.width / _wm.cols, ch = world.height / _wm.rows;
    // The world repeats; fold the tap onto one copy, remembering which.
    final copy = (d.localPosition.dx / world.width).floor();
    final localX = d.localPosition.dx - copy * world.width;
    // Nearest marker within a finger's reach, in map pixels.
    ({int ci, double r, double c})? best;
    var bestD = double.infinity;
    for (final m in _markers) {
      final dx = (m.c + 0.5) * cw - localX;
      final dy = (m.r + 0.5) * ch - d.localPosition.dy;
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
    _popupTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _popup = null);
    });
  }

  static const double _tapRadius = 22;

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
                        // Fill the screen height less the inset; the width
                        // follows the map's aspect ratio, so it overflows
                        // sideways and the only gesture left is a horizontal
                        // scroll.
                        // The tab bar floats over this screen (extendBody), so
                        // the map insets past it — plus _padV again, so the
                        // south pole clears the bar by the same margin it has
                        // at the top rather than sitting flush against it.
                        final padBottom = _padV +
                            kTabBarSlot +
                            MediaQuery.viewPaddingOf(context).bottom;
                        final h = math.max(
                            cons.maxHeight - _padV - padBottom, 1.0);
                        final w = h * _wm.cols / _wm.rows;
                        _ensureMarkers();
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
                            _copyW = w;
                            return SingleChildScrollView(
                              controller: _hc,
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.only(
                                  top: _padV, bottom: padBottom),
                              // Three copies of the world side by side, with the
                              // offset wrapped back onto the middle one — the map
                              // has no left or right edge to fall off, so the
                              // Pacific can be read whole.
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) => _onTapUp(d, Size(w, h)),
                                child: SizedBox(
                                  width: w * _copies,
                                  height: h,
                                  child: Stack(
                                    children: [
                                      Row(
                                        children: [
                                          for (var i = 0; i < _copies; i++)
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
                                      // Markers first, then the beacon: the radar
                                      // marks where to play next, so on the
                                      // country it sits on it has to be the thing
                                      // you see, not a pin over the top of it.
                                      Row(
                                        children: [
                                          for (var i = 0; i < _copies; i++)
                                            CustomPaint(
                                              size: Size(w, h),
                                              painter: _MarkerPainter(
                                                  _wm, _markers, col),
                                            ),
                                        ],
                                      ),
                                      if (_hasHot)
                                        Row(
                                          children: [
                                            for (var i = 0; i < _copies; i++)
                                              reduce
                                                  ? CustomPaint(
                                                      size: Size(w, h),
                                                      painter: _RadarMapPainter(
                                                          _wm, _hotR, _hotC, col,
                                                          0,
                                                          reduce: true))
                                                  : AnimatedBuilder(
                                                      animation: _radar,
                                                      builder: (_, __) =>
                                                          CustomPaint(
                                                        size: Size(w, h),
                                                        painter:
                                                            _RadarMapPainter(
                                                                _wm,
                                                                _hotR,
                                                                _hotC,
                                                                col,
                                                                _radar.value,
                                                                reduce: false),
                                                      ),
                                                    ),
                                          ],
                                        ),
                                      if (_popup != null)
                                        _CountryBubble(
                                          country: _repo.countries[_popup!.ci],
                                          at: Offset(
                                              _popupCopy * w +
                                                  (_popup!.c + 0.5) * w / _wm.cols,
                                              (_popup!.r + 0.5) * h / _wm.rows),
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
        // Back to the next stage, the way a maps app recentres on you. Sits
        // clear of the floating tab bar.
        if (_ready && _wm.isLoaded)
          Positioned(
            right: 16,
            bottom: 96,
            child: _MyLocationButton(onTap: () {
              // Reuse the copy width captured at layout ([_copyW]) rather than
              // recomputing it here: an independent recompute drifted from the
              // real render size (it missed the tab-bar slot and bottom safe
              // area baked into the map's actual height), so the target column
              // landed off-centre.
              if (!_hc.hasClients || _copyW <= 0) return;
              _goToCurrent(_copyW, _hc.position.viewportDimension);
            }),
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
                    // A chip, not bare text: the line sits over the dot map,
                    // and dots running through the glyphs made it unreadable.
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: col.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _repo.isLoaded
                            ? '$_currentCountry개국 완료 · ${_repo.countries.length}개국 중'
                            : '',
                        style: AppText.caption.copyWith(color: col.inkSoft),
                      ),
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

/// Flag + name in a rounded plate, pointing at the marker that opened it.
/// Positioned by its bottom edge so it always sits above the pin.
class _CountryBubble extends StatelessWidget {
  const _CountryBubble({required this.country, required this.at});
  final CampaignCountry country;
  final Offset at;

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
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                Text(country.displayName,
                    softWrap: false,
                    style: AppText.label.copyWith(color: c.ink)),
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
