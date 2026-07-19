import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import 'round_intro_screen.dart';

/// The map tab: a dotted world map. Land dots are coloured by campaign
/// progress — in-progress country in accent blue, cleared countries dark
/// grey, locked/other land grey, sea faint. Opens zoomed to the current
/// country; pinch/pan to explore, tap a country to open its round intro.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _wm = WorldMap.instance;
  final _repo = CampaignRepository.instance;
  final _tc = TransformationController();
  bool _ready = false;
  bool _zoomed = false;

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
    _tc.dispose();
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

  void _zoomToCurrent(Size world, Size viewport) {
    final ci = _currentCountry;
    var minR = 1 << 30, minC = 1 << 30, maxR = -1, maxC = -1;
    for (var r = 0; r < _wm.rows; r++) {
      for (var c = 0; c < _wm.cols; c++) {
        if (_wm.countryOfCell(_wm.cellAt(r, c)) == ci) {
          minR = math.min(minR, r);
          maxR = math.max(maxR, r);
          minC = math.min(minC, c);
          maxC = math.max(maxC, c);
        }
      }
    }
    if (maxR < 0) {
      // current country isn't on the map — show the whole world, centred.
      final s = (viewport.width / world.width).clamp(0.1, 8.0);
      final ty = math.max(0.0, (viewport.height - world.height * s) / 2);
      _tc.value = Matrix4(
        s, 0, 0, 0, //
        0, s, 0, 0, //
        0, 0, 1, 0, //
        0, ty, 0, 1, //
      );
      return;
    }
    final cw = world.width / _wm.cols, ch = world.height / _wm.rows;
    final rect = Rect.fromLTRB(
        (minC - 1) * cw, (minR - 1) * ch, (maxC + 2) * cw, (maxR + 2) * ch);
    final scale = math
        .min(viewport.width / rect.width, viewport.height / rect.height)
        .clamp(1.0, 8.0);
    final tx = viewport.width / 2 - rect.center.dx * scale;
    final ty = viewport.height / 2 - rect.center.dy * scale;
    // column-major scale + translate (p' = S·p + T)
    _tc.value = Matrix4(
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      tx, ty, 0, 1, //
    );
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
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('맵'),
          // The campaign runs smallest territory first, so the opening rounds
          // colour a handful of dots that are easy to miss on a world map.
          // A plain count makes the progress legible until the countries get
          // big enough to see.
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
          Expanded(
            child: !_ready
                ? Center(child: CircularProgressIndicator(color: col.accent))
                : !_wm.isLoaded
                    ? Center(
                        child: Text('지도를 불러올 수 없습니다.',
                            style: TextStyle(color: col.inkFaint)))
                    : LayoutBuilder(
                        builder: (context, cons) {
                          final world = Size(
                              cons.maxWidth, cons.maxWidth * _wm.rows / _wm.cols);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!_zoomed && mounted) {
                              _zoomed = true;
                              _zoomToCurrent(
                                  world, Size(cons.maxWidth, cons.maxHeight));
                              setState(() {});
                            }
                          });
                          return ValueListenableBuilder<int>(
                            valueListenable: Progress.instance.unlocked,
                            builder: (context, _, _) => InteractiveViewer(
                              transformationController: _tc,
                              minScale: 1,
                              maxScale: 8,
                              constrained: false,
                              boundaryMargin: const EdgeInsets.all(120),
                              child: GestureDetector(
                                onTapUp: (d) => _onTapUp(d, world),
                                child: CustomPaint(
                                  size: world,
                                  painter: _WorldPainter(_wm, _currentCountry,
                                      _currentFilled, col),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
    final rLand = math.min(cw, ch) * 0.36, rSea = math.min(cw, ch) * 0.15;
    final sea = Paint()..color = c.dot;
    final done = Paint()..color = c.accent;
    final locked = Paint()..color = c.inkFaint.withValues(alpha: 0.55);
    for (var r = 0; r < wm.rows; r++) {
      for (var col = 0; col < wm.cols; col++) {
        final i = r * wm.cols + col;
        final v = wm.cells[i];
        final o = Offset(col * cw + cw / 2, r * ch + ch / 2);
        if (v < 0) {
          canvas.drawCircle(o, rSea, sea);
          continue;
        }
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
