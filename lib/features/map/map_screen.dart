import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import 'round_intro_screen.dart';

/// The map tab: a full-screen dotted world map. Land dots are coloured by
/// campaign progress — in-progress country in accent blue, cleared countries
/// dark grey, locked/other land grey. The map fills the screen height and
/// scrolls left/right only (no zoom, no vertical pan); the header and the
/// shell's tab bar float over it. Opens scrolled to the current country; tap a
/// country to open its round intro.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _wm = WorldMap.instance;
  final _repo = CampaignRepository.instance;
  final _hc = ScrollController();
  bool _ready = false;
  bool _centered = false;

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
  void dispose() {
    _hc.dispose();
    super.dispose();
  }

  int get _currentCountry {
    if (!_repo.isLoaded) return 0;
    final u = Progress.instance.unlocked.value
        .clamp(0, (_repo.totalStages - 1).clamp(0, 1 << 30));
    return _repo.locate(u).$1;
  }

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

  /// Scrolls horizontally so the current country sits in the middle of the
  /// viewport. Leaves the map at the start if that country isn't on the map.
  void _centerOnCurrent(double mapWidth, double viewport) {
    final ci = _currentCountry;
    var minC = 1 << 30, maxC = -1;
    for (var r = 0; r < _wm.rows; r++) {
      for (var c = 0; c < _wm.cols; c++) {
        if (_wm.countryOfCell(_wm.cellAt(r, c)) == ci) {
          minC = math.min(minC, c);
          maxC = math.max(maxC, c);
        }
      }
    }
    if (maxC < 0) return;
    final centerCol = (minC + maxC) / 2 + 0.5;
    final target = centerCol / _wm.cols * mapWidth - viewport / 2;
    _hc.jumpTo(target.clamp(0.0, math.max(0.0, mapWidth - viewport)));
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
    return Stack(
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
                        return ValueListenableBuilder<int>(
                          valueListenable: Progress.instance.unlocked,
                          builder: (context, _, _) => SingleChildScrollView(
                            controller: _hc,
                            scrollDirection: Axis.horizontal,
                            child: GestureDetector(
                              onTapUp: (d) => _onTapUp(d, Size(w, h)),
                              child: CustomPaint(
                                size: Size(w, h),
                                painter: _WorldPainter(_wm, _currentCountry,
                                    _currentFilled, col),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Header floats over the map with a transparent background.
        SafeArea(
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
          p = done; // finished rounds stay lit
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
