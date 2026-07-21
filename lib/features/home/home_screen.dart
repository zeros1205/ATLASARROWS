import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../app/shell.dart';
import '../../models/campaign_repository.dart';
import '../../models/world_map.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import '../../shared/theme_toggle_button.dart';
import '../game/game_screen.dart';

/// Home: centred game logo, then the play CTAs. A brand-new player sees a
/// single '시작하기'; a returning player sees '이어서 플레이' + '맵에서 플레이'.
/// No hearts/gem in the header (hearts live in-play; gem is unused).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void play() {
      final stage = Progress.instance.unlocked.value
          .clamp(0, (CampaignRepository.instance.totalStages - 1).clamp(0, 1 << 30));
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GameScreen(stage: stage)));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ValueListenableBuilder<int>(
          valueListenable: Progress.instance.unlocked,
          builder: (context, unlocked, _) {
            final isNew = unlocked <= 0;
            // The country the play button will open into — its dots get lit and
            // pulsed on the map below, tying the CTA to a place on the globe.
            final target = _targetCountry(unlocked);
            // Stacked top-to-bottom now, no overlap: wordmark, then the map as
            // the hero, then the CTA. The old "SHIFT THE ARROWS" tagline is
            // dropped — it just repeated the wordmark and cost the map height.
            return Column(
              children: [
                const SizedBox(height: 24),
                EnterFade(
                  rise: 12,
                  // The wordmark holds to ~40% of the width so the map below is
                  // the hero, not the type. Fixed height gives the FittedBox a
                  // bounded box to scale into inside the Column.
                  child: SizedBox(
                    height: 86,
                    child: FractionallySizedBox(
                      widthFactor: 0.40,
                      child: FittedBox(
                          fit: BoxFit.contain, child: const _Wordmark()),
                    ),
                  ),
                ),
                const SizedBox(height: AppGap.xl),
                Expanded(
                  child: EnterFade(
                    delay: const Duration(milliseconds: 120),
                    child: _RadarWorldMap(target: target),
                  ),
                ),
                const SizedBox(height: AppGap.xl),
                EnterFade(
                  delay: const Duration(milliseconds: 200),
                  rise: 14,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: isNew
                        ? _PrimaryButton(label: '시작하기', onTap: play)
                        : Column(
                            children: [
                              _PrimaryButton(
                                  label: '이어서 플레이',
                                  sub: _resumeLabel(),
                                  onTap: play),
                              const SizedBox(height: AppGap.md),
                              _SecondaryButton(
                                  label: '맵에서 플레이',
                                  icon: Icons.public_outlined,
                                  onTap: () => appTab.value = 1),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppGap.lg),
              ],
            );
          },
            ),
            const Positioned(
              top: 4,
              right: 12,
              child: ThemeToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}

String _resumeLabel() {
  final repo = CampaignRepository.instance;
  if (!repo.isLoaded) return '스테이지 1';
  final stage =
      Progress.instance.unlocked.value.clamp(0, repo.totalStages - 1);
  final (ci, local) = repo.locate(stage);
  final country = repo.countries[ci];
  // Position inside the round, not the global index: "stage 641" tells a
  // player nothing, and the round is the unit they are actually working on.
  return '${country.displayName} · ${local + 1} / ${country.stageCount}';
}

/// The campaign country the play button will drop into — the round that owns
/// the resume stage. Its dots are lit and pulsed on the home map. -1 before the
/// campaign is loaded.
int _targetCountry(int unlocked) {
  final repo = CampaignRepository.instance;
  if (!repo.isLoaded) return -1;
  final stage = unlocked.clamp(0, (repo.totalStages - 1).clamp(0, 1 << 30));
  return repo.locate(stage).$1;
}

/// The two-line lockup from the Figma feature graphic: mint "ATLAS" spread
/// wide over teal-gray "ARROWS" set tight. ATLAS is nudged right by half its
/// letter-spacing so the trailing gap doesn't push the glyphs off-centre.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  static const double _atlasSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(_atlasSpacing / 2, 0),
          child: Text('ATLAS',
              style: AppText.display.copyWith(
                  color: c.accent,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: _atlasSpacing,
                  height: 1.0)),
        ),
        Text('ARROWS',
            style: AppText.display.copyWith(
                color: c.ink,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.05)),
      ],
    );
  }
}

/// The home hero: the campaign's baked dot map, with the [target] country's
/// dots lit in accent and a sonar ring pulsing over them — a "next destination"
/// beacon tied to the play button. Land dots only, fitted and centred.
///
/// The static dots and the animating radar are separate layers: the dot layer
/// only repaints when the target or theme changes, so the per-frame cost is
/// just the two rings and the beacon. Under OS reduce-motion the ring freezes.
class _RadarWorldMap extends StatefulWidget {
  const _RadarWorldMap({required this.target});

  /// Campaign country index to spotlight, or -1 for none.
  final int target;

  @override
  State<_RadarWorldMap> createState() => _RadarWorldMapState();
}

class _RadarWorldMapState extends State<_RadarWorldMap>
    with SingleTickerProviderStateMixin {
  final WorldMap _wm = WorldMap.instance;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1900));

  /// The target country's cell indices, and their centroid in grid coords —
  /// computed once per target so the animating layer never rescans the map.
  List<int> _hot = const [];
  double _cr = 0, _cc = 0;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No sweep to run under reduce-motion — hold the ring static instead.
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating && _hot.isNotEmpty) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(_RadarWorldMap old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _recompute();
      if (_hot.isEmpty) {
        _c.stop();
      } else if (!reduceMotion(context) && !_c.isAnimating) {
        _c.repeat();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _recompute() {
    final hot = <int>[];
    var sr = 0.0, sc = 0.0;
    if (_wm.isLoaded && widget.target >= 0) {
      for (var i = 0; i < _wm.cells.length; i++) {
        if (_wm.countryOfCell(_wm.cells[i]) == widget.target) {
          hot.add(i);
          sr += i ~/ _wm.cols;
          sc += i % _wm.cols;
        }
      }
    }
    _hot = hot;
    if (hot.isNotEmpty) {
      _cr = sr / hot.length;
      _cc = sc / hot.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_wm.isLoaded) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final reduce = reduceMotion(context);
    // expand pins a definite width (a Stack of only-positioned children would
    // otherwise collapse under the Column's loose cross-axis); ClipRect keeps
    // the sonar ring from bleeding onto the tagline / button.
    return SizedBox.expand(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DotsPainter(_wm, _hot, c)),
            ),
            if (_hot.isNotEmpty)
              Positioned.fill(
                child: reduce
                    ? CustomPaint(
                        painter:
                            _RadarPainter(_wm, _cr, _cc, c, 0, reduce: true))
                    : AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => CustomPaint(
                            painter: _RadarPainter(_wm, _cr, _cc, c, _c.value,
                                reduce: false)),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contain-fit the [wm] grid into [size]: scale + offsets shared by both layers.
({double scale, double dx, double dy}) _mapFit(WorldMap wm, Size size) {
  final scale = math.min(size.width / wm.cols, size.height / wm.rows);
  return (
    scale: scale,
    dx: (size.width - wm.cols * scale) / 2,
    dy: (size.height - wm.rows * scale) / 2,
  );
}

/// Static layer: faint land dots, plus the target country's dots in accent
/// (with a soft glow underlay). Repaints only on target / theme change.
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.wm, this.hot, this.c) : _hotSet = hot.toSet();
  final WorldMap wm;
  final List<int> hot;
  final AppColors c;
  final Set<int> _hotSet;

  @override
  void paint(Canvas canvas, Size size) {
    final f = _mapFit(wm, size);
    final rBase = f.scale * 0.30, rHot = f.scale * 0.44;
    final faint = Paint()..color = c.inkFaint.withValues(alpha: 0.45);
    for (var i = 0; i < wm.cells.length; i++) {
      if (wm.cells[i] < 0 || _hotSet.contains(i)) continue;
      final row = i ~/ wm.cols, col = i % wm.cols;
      canvas.drawCircle(
          Offset(f.dx + col * f.scale + f.scale / 2,
              f.dy + row * f.scale + f.scale / 2),
          rBase,
          faint);
    }
    if (hot.isEmpty) return;
    final glow = Paint()
      ..color = c.accent.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final solid = Paint()..color = c.accent;
    for (final i in hot) {
      final row = i ~/ wm.cols, col = i % wm.cols;
      final o = Offset(f.dx + col * f.scale + f.scale / 2,
          f.dy + row * f.scale + f.scale / 2);
      canvas.drawCircle(o, rHot * 1.3, glow);
      canvas.drawCircle(o, rHot, solid);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.c != c || !identical(old.hot, hot);
}

/// Animating layer: the sonar rings and centre beacon over the target centroid.
/// [t] is the controller value in [0,1); a fixed minimum radius keeps a
/// one-dot micro-nation locatable instead of vanishing into the ocean.
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.wm, this.cr, this.cc, this.c, this.t,
      {required this.reduce});
  final WorldMap wm;
  final double cr, cc, t;
  final AppColors c;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final f = _mapFit(wm, size);
    final cx = f.dx + (cc + 0.5) * f.scale, cy = f.dy + (cr + 0.5) * f.scale;
    final rHot = f.scale * 0.44;
    final ringMax = math.max(f.scale * 3.4, 34.0);

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
        ring(rHot + (ringMax - rHot) * ph, (1 - ph) * 0.85);
      }
    }

    final pulse =
        reduce ? 1.0 : 0.78 + 0.22 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3));
    canvas.drawCircle(
        Offset(cx, cy), rHot * 0.9 * pulse, Paint()..color = c.accent);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.t != t || old.c != c || old.cr != cr || old.cc != cc;
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.sub, required this.onTap});
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppText.headline
                    .copyWith(color: c.onAccent, fontWeight: FontWeight.w900)),
            if (sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: AppText.caption.copyWith(
                      color: c.onAccent.withValues(alpha: 0.8),
                      letterSpacing: 1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c.ink),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.label
                    .copyWith(color: c.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
