import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../services/progress.dart';
import '../../shared/pressable.dart';
import '../game/game_screen.dart';

/// The world campaign map. One country = one round, ordered by area so the
/// atlas rises in difficulty; its stages sit as pins on the country
/// silhouette, and a visa stamp lands in the corner once the whole country
/// is cleared. Locked rounds/stages read faint; the current stage pulses.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _repo = CampaignRepository.instance;
  late int _ci;

  @override
  void initState() {
    super.initState();
    final (ci, _) = _repo.isLoaded
        ? _repo.locate(Progress.instance.unlocked.value
            .clamp(0, (_repo.totalStages - 1).clamp(0, 1 << 30)))
        : (0, 0);
    _ci = ci;
  }

  void _step(int delta) {
    setState(() => _ci = (_ci + delta).clamp(0, _repo.countries.length - 1));
  }

  Future<void> _openStage(int globalStage) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(stage: globalStage)),
    );
    if (mounted) setState(() {}); // refresh unlock states on return
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!_repo.isLoaded) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: Text('캠페인을 불러오지 못했어요',
              style: AppText.body.copyWith(color: c.inkFaint)),
        ),
      );
    }

    final country = _repo.countries[_ci];
    final first = _repo.firstStageOf(_ci);
    final unlocked = Progress.instance.unlocked.value;
    final countryCleared = unlocked >= first + country.stageCount;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _RoundSelector(
            country: country,
            index: _ci,
            total: _repo.countries.length,
            cleared: (unlocked - first).clamp(0, country.stageCount),
            canPrev: _ci > 0,
            canNext: _ci < _repo.countries.length - 1,
            onPrev: () => _step(-1),
            onNext: () => _step(1),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: _CountryBoard(
                country: country,
                firstStage: first,
                unlocked: unlocked,
                cleared: countryCleared,
                onTapStage: _openStage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundSelector extends StatelessWidget {
  const _RoundSelector({
    required this.country,
    required this.index,
    required this.total,
    required this.cleared,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  final CampaignCountry country;
  final int index, total, cleared;
  final bool canPrev, canNext;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          _Arrow(icon: Icons.chevron_left, enabled: canPrev, onTap: onPrev),
          Expanded(
            child: Column(
              children: [
                Text(country.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline.copyWith(
                        color: c.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('${index + 1} / $total · $cleared/${country.stageCount} 클리어',
                    style: AppText.caption
                        .copyWith(color: c.inkFaint, letterSpacing: 0.5)),
              ],
            ),
          ),
          _Arrow(icon: Icons.chevron_right, enabled: canNext, onTap: onNext),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(
      {required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final child = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.line),
      ),
      child: Icon(icon,
          color: enabled ? c.ink : c.inkFaint.withValues(alpha: 0.4)),
    );
    return enabled ? Pressable(onTap: onTap, child: child) : Opacity(opacity: 0.5, child: child);
  }
}

/// The country silhouette (faint dots) with stage pins placed on it, plus a
/// corner visa stamp once every stage in the country is cleared.
class _CountryBoard extends StatelessWidget {
  const _CountryBoard({
    required this.country,
    required this.firstStage,
    required this.unlocked,
    required this.cleared,
    required this.onTapStage,
  });

  final CampaignCountry country;
  final int firstStage;
  final int unlocked;
  final bool cleared;
  final void Function(int globalStage) onTapStage;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final scale = _fitScale(box.maxWidth, box.maxHeight);
        final drawnW = country.cols * scale;
        final drawnH = country.rows * scale;
        final ox = (box.maxWidth - drawnW) / 2;
        final oy = (box.maxHeight - drawnH) / 2;

        final pins = <Widget>[];
        for (var i = 0; i < country.pins.length; i++) {
          final (u, v) = country.pins[i];
          final global = firstStage + i;
          final state = global < unlocked
              ? _Pin.done
              : global == unlocked
                  ? _Pin.current
                  : _Pin.locked;
          const r = 22.0;
          pins.add(Positioned(
            left: ox + u * drawnW - r,
            top: oy + v * drawnH - r,
            child: _StageNode(
              number: i + 1,
              state: state,
              onTap: state == _Pin.locked ? null : () => onTapStage(global),
            ),
          ));
        }

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SilhouettePainter(
                  mask: country.mask,
                  scale: scale,
                  ox: ox,
                  oy: oy,
                  dot: c.dot,
                ),
              ),
            ),
            ...pins,
            if (cleared)
              Positioned(
                right: 4,
                top: 4,
                child: _VisaStamp(label: country.name.toUpperCase()),
              ),
          ],
        );
      },
    );
  }

  double _fitScale(double w, double h) {
    final s = (w / country.cols) < (h / country.rows)
        ? w / country.cols
        : h / country.rows;
    return s;
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({
    required this.mask,
    required this.scale,
    required this.ox,
    required this.oy,
    required this.dot,
  });

  final Set<(int, int)> mask;
  final double scale, ox, oy;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dot;
    final radius = (scale * 0.12).clamp(1.5, 5.0);
    for (final (r, c) in mask) {
      canvas.drawCircle(
        Offset(ox + (c + 0.5) * scale, oy + (r + 0.5) * scale),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.scale != scale || old.ox != ox || old.oy != oy || old.dot != dot;
}

enum _Pin { done, current, locked }

class _StageNode extends StatelessWidget {
  const _StageNode(
      {required this.number, required this.state, required this.onTap});
  final int number;
  final _Pin state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    late final Widget dot;
    switch (state) {
      case _Pin.done:
        dot = _circle(
          color: c.accent,
          border: null,
          child: Icon(Icons.check_rounded, size: 22, color: c.onAccent),
        );
      case _Pin.current:
        dot = _circle(
          color: c.surface,
          border: Border.all(color: c.accent, width: 3),
          child: Text('$number',
              style: AppText.label.copyWith(
                  color: c.accent, fontWeight: FontWeight.w900)),
        );
      case _Pin.locked:
        dot = _circle(
          color: c.surfaceMuted,
          border: Border.all(color: c.line),
          child: Icon(Icons.lock_outline_rounded,
              size: 18, color: c.inkFaint.withValues(alpha: 0.6)),
        );
    }
    if (onTap == null) return dot;
    return Pressable(onTap: onTap, child: dot);
  }

  Widget _circle({required Color color, Border? border, required Widget child}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
      ),
      child: child,
    );
  }
}

/// A passport-style "cleared" visa stamp for a finished country, rotated a
/// touch and set in the map's top-right corner.
class _VisaStamp extends StatelessWidget {
  const _VisaStamp({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: c.danger, width: 2),
        ),
        child: Column(
          children: [
            Text('CLEARED',
                style: AppText.caption.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                    color: c.danger.withValues(alpha: 0.8),
                    fontSize: 9,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
