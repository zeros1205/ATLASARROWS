import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../game/z_arrows_game.dart';
import '../../models/campaign_repository.dart';
import '../../services/ads/ads.dart';
import '../../services/progress.dart';
import '../../shared/pressable.dart';

/// One stage of the campaign, with the new chrome: 2-line header
/// (STAGE / country), a hearts strip, the board, a booster bar (hint /
/// remove) and a bottom banner. Results come up as a bottom sheet with a
/// top MREC banner; the heart economy grants a free refill then ad refills.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.stage});
  final int stage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Result { none, cleared, failed }

class _GameScreenState extends State<GameScreen> {
  final _repo = CampaignRepository.instance;
  late int _stage = widget.stage;
  late ZArrowsGame _game;
  final _hearts = ValueNotifier<int>(ZArrowsGame.maxHearts);
  _Result _result = _Result.none;
  bool _freeRefillUsed = false;

  @override
  void initState() {
    super.initState();
    _game = _buildGame(AppColors.light);
  }

  ZArrowsGame _buildGame(AppColors palette) => ZArrowsGame(
        initialLevel: _repo.levelAt(_stage),
        palette: palette,
        onHeartsChanged: (h) => _hearts.value = h,
        onCleared: () => setState(() => _result = _Result.cleared),
        onFailed: () => setState(() => _result = _Result.failed),
      );

  ({int countryIndex, int local}) get _loc {
    final (ci, local) = _repo.locate(_stage);
    return (countryIndex: ci, local: local);
  }

  String get _placeName {
    if (!_repo.isLoaded) return '';
    return _repo.countries[_loc.countryIndex].displayName;
  }

  void _next() {
    Progress.instance.markCleared(_stage);
    if (_stage + 1 >= _repo.totalStages) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _stage++;
      _freeRefillUsed = false;
      _result = _Result.none;
    });
    _game.loadLevel(_repo.levelAt(_stage));
  }

  void _restart() {
    setState(() {
      _freeRefillUsed = false;
      _result = _Result.none;
    });
    _game.restartLevel();
  }

  void _refill({required bool viaAd}) {
    void grant() {
      _game.refillHearts();
      setState(() => _result = _Result.none);
    }

    if (!viaAd) {
      _freeRefillUsed = true;
      grant();
    } else {
      Ads.showRewarded(onReward: grant, onUnavailable: grant);
    }
  }

  @override
  void dispose() {
    _hearts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    _game.palette = c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _Header(
                  stage: _stage + 1,
                  place: _placeName,
                  onBack: () => Navigator.of(context).maybePop(),
                  onRestart: _restart,
                ),
                Container(height: 1, color: c.line),
                _HeartsStrip(hearts: _hearts),
                Expanded(
                  child: GameWidget(game: _game),
                ),
                _BoosterBar(game: _game),
                const AdsBanner(),
              ],
            ),
            if (_result != _Result.none)
              _ResultSheet(
                result: _result,
                stage: _stage + 1,
                place: _placeName,
                freeRefillUsed: _freeRefillUsed,
                onNext: _next,
                onRestart: _restart,
                onRefill: _refill,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.stage,
      required this.place,
      required this.onBack,
      required this.onRestart});
  final int stage;
  final String place;
  final VoidCallback onBack, onRestart;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _iconBtn(c, Icons.arrow_back, onBack),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('STAGE $stage',
                    style: AppText.label.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        fontSize: 15)),
                if (place.isNotEmpty)
                  Text(place,
                      style: AppText.caption.copyWith(
                          color: c.inkFaint, height: 1.05, fontSize: 11)),
              ],
            ),
          ),
          _iconBtn(c, Icons.refresh, onRestart),
        ],
      ),
    );
  }

  Widget _iconBtn(AppColors c, IconData icon, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: c.inkFaint, size: 24),
        ),
      );
}

class _HeartsStrip extends StatelessWidget {
  const _HeartsStrip({required this.hearts});
  final ValueNotifier<int> hearts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ValueListenableBuilder<int>(
            valueListenable: hearts,
            builder: (context, h, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < ZArrowsGame.maxHearts; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Opacity(
                      opacity: i < h ? 1 : 0.28,
                      child: ColorFiltered(
                        colorFilter: i < h
                            ? const ColorFilter.mode(
                                Colors.transparent, BlendMode.dst)
                            : const ColorFilter.matrix(_grayscale),
                        child: Image.asset('assets/images/icons/heart.png',
                            width: 22, height: 22),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _grayscale = <double>[
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class _BoosterBar extends StatelessWidget {
  const _BoosterBar({required this.game});
  final ZArrowsGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: Progress.instance.hints,
            builder: (context, n, _) => _BoosterButton(
              icon: 'assets/images/icons/hint.png',
              label: '힌트',
              count: n,
              onTap: () {
                if (n <= 0) return;
                if (game.showHint()) Progress.instance.useHint();
              },
            ),
          ),
          const SizedBox(width: 16),
          ValueListenableBuilder<bool>(
            valueListenable: game.removeArmed,
            builder: (context, armed, _) =>
                ValueListenableBuilder<int>(
              valueListenable: Progress.instance.removes,
              builder: (context, n, _) => _BoosterButton(
                icon: 'assets/images/icons/remove.png',
                label: '제거',
                count: n,
                armed: armed,
                onTap: () {
                  if (n <= 0) return;
                  game.armRemove();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.armed = false,
  });
  final String icon, label;
  final int count;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 58,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: armed ? c.accent : c.line, width: armed ? 2 : 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(icon, width: 28, height: 28),
                  Text(label,
                      style: AppText.caption.copyWith(
                          fontSize: 9, color: c.inkFaint, letterSpacing: 0.5)),
                ],
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 21),
                height: 21,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: count > 0 ? c.ink : c.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Text(count > 0 ? '$count' : '+',
                    style: AppText.caption.copyWith(
                        color: c.bg, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.result,
    required this.stage,
    required this.place,
    required this.freeRefillUsed,
    required this.onNext,
    required this.onRestart,
    required this.onRefill,
  });
  final _Result result;
  final int stage;
  final String place;
  final bool freeRefillUsed;
  final VoidCallback onNext, onRestart;
  final void Function({required bool viaAd}) onRefill;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cleared = result == _Result.cleared;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Column(
          children: [
            // MREC pinned to the very top of the screen
            Container(
              height: 160,
              color: c.dot,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('중간 배너 광고',
                      style: AppText.label.copyWith(
                          color: c.inkFaint, letterSpacing: 3)),
                  Text('300 × 250',
                      style: AppText.caption.copyWith(color: c.inkFaint)),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: cleared ? _clear(c) : _fail(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clear(AppColors c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('STAGE $stage${place.isEmpty ? '' : ' · $place'}',
              style: AppText.caption.copyWith(color: c.inkFaint, letterSpacing: 3)),
          const SizedBox(height: 6),
          Text('클리어!',
              style: AppText.title.copyWith(
                  color: c.accent, fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 18),
          _bigButton(c, '다음 스테이지', c.accent, c.onAccent, onNext),
        ],
      );

  Widget _fail(AppColors c) {
    final free = !freeRefillUsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('하트 소진',
            style: AppText.title.copyWith(
                color: c.ink, fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Image.asset('assets/images/icons/heart.png',
                    width: 30, height: 30),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(free ? '풀던 판은 그대로! 이번 리필은 무료예요.' : '광고 한 편 보면 하트가 가득 차요.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: c.inkSoft, fontSize: 13.5)),
        const SizedBox(height: 16),
        _bigButton(
          c,
          free ? '무료 충전' : '광고 보고 충전',
          free ? c.success : c.accentSoft,
          free ? Colors.white : c.accent,
          () => onRefill(viaAd: !free),
        ),
        const SizedBox(height: 10),
        _bigButton(c, '다시 시작', Colors.transparent, c.inkFaint, onRestart,
            outline: true),
      ],
    );
  }

  Widget _bigButton(AppColors c, String label, Color bg, Color fg,
          VoidCallback onTap,
          {bool outline = false}) =>
      Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: outline ? Border.all(color: c.line, width: 1.5) : null,
          ),
          child: Text(label,
              style: AppText.headline
                  .copyWith(color: fg, fontWeight: FontWeight.w900)),
        ),
      );
}
