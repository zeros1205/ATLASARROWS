import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../game/z_arrows_game.dart';
import '../../models/campaign_repository.dart' show CampaignCountry, CampaignRepository, StageKind;
import '../../services/ads/ads.dart';
import '../../services/game_services.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';

/// One stage of the campaign: a header naming the place, a hearts strip, the
/// board, a bottom bar (fit view / hint / remove / restart) and a banner.
/// Results come up as a bottom sheet with a top MREC banner; the heart
/// economy grants a free refill then ad refills.
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

  // Feature flags — both surfaces are kept but held off for now; flip to true
  // to bring them back. Runtime fields (not const) so the gated code stays
  // live for the analyzer.
  //
  //  _introEnabled — the per-country round-intro screen on a country's first
  //                  stage.
  //  _coachEnabled — the first-play help toast (and its hint-pulse timer).
  final bool _introEnabled = false;
  final bool _coachEnabled = false;

  // Show the round-intro when we land on a country's first stage.
  late bool _showIntro = _introEnabled && _loc.local == 0;

  /// Pulses a free line every few seconds while the coach is up, so a stuck
  /// first-time player is shown a legal move instead of being told about one.
  Timer? _coachTimer;

  @override
  void initState() {
    super.initState();
    _game = _buildGame(AppColors.light);
    if (_coachEnabled && !Progress.instance.coachDone.value) {
      _coachTimer = Timer.periodic(const Duration(seconds: 3), (t) {
        if (Progress.instance.coachDone.value) {
          t.cancel();
          return;
        }
        if (_result == _Result.none && !_showIntro) _game.showHint();
      });
    }
  }

  ZArrowsGame _buildGame(AppColors palette) => ZArrowsGame(
        initialLevel: _repo.levelAt(_stage),
        palette: palette,
        onHeartsChanged: (h) => _hearts.value = h,
        onCleared: () => setState(() => _result = _Result.cleared),
        onFailed: () => setState(() => _result = _Result.failed),
        onEscaped: _onEscaped,
        onRemoveUsed: Progress.instance.useRemove,
      );

  /// The coach retires itself the first time the player frees a line on their
  /// own — the rule is learned by doing it, not by reading it twice.
  void _onEscaped() {
    if (!Progress.instance.coachDone.value) {
      Progress.instance.setCoachDone(true);
    }
  }

  /// Pushes the clear to Play Games / Game Center. Fire-and-forget: the call
  /// no-ops when the player isn't signed in, and never blocks stage advance.
  void _reportToGameServices({required bool countryCompleted}) {
    final countriesDone =
        _repo.isLoaded ? _loc.countryIndex + (countryCompleted ? 1 : 0) : 0;
    unawaited(GameServices.submitProgress(
      stagesCleared: Progress.instance.totalClears.value,
      countriesCompleted: countriesDone,
    ));
    unawaited(GameServices.reportClear(
      totalClears: Progress.instance.totalClears.value,
      countryCompleted: countryCompleted,
      // No heart lost on this stage — the strict-play achievement.
      flawless: _hearts.value == ZArrowsGame.maxHearts,
    ));
  }

  ({int countryIndex, int local}) get _loc {
    final (ci, local) = _repo.locate(_stage);
    return (countryIndex: ci, local: local);
  }

  /// The country this stage belongs to.
  String get _countryName {
    if (!_repo.isLoaded) return '';
    return _repo.countries[_loc.countryIndex].displayName;
  }

  /// What this particular board depicts — a city, or the country itself on the
  /// round's last stage. This is the label worth showing while playing; the
  /// country is already established by the round intro.
  String get _placeName => _repo.stageAt(_stage)?.displayName ?? _countryName;

  /// The two header lines: city over country. A country board — the round's
  /// finale, and the only stage a country without cities ever has — would
  /// otherwise repeat its own name twice, so it stands alone on one line.
  (String, String?) get _headerLines {
    final stage = _repo.isLoaded ? _repo.stageAt(_stage) : null;
    if (stage == null || stage.kind == StageKind.country) {
      return (_countryName, null);
    }
    return (stage.displayName, _countryName);
  }

  /// "3 / 12" — position inside the round. A global stage number would read as
  /// "stage 641 of 775", which says nothing a player cares about.
  String get _localStageLabel {
    if (!_repo.isLoaded) return '${_stage + 1}';
    final loc = _loc;
    final total = _repo.countries[loc.countryIndex].stageCount;
    return '${loc.local + 1} / $total';
  }

  void _next() {
    Progress.instance.markCleared(_stage);
    final atCampaignEnd = _stage + 1 >= _repo.totalStages;
    // A country is finished when the next stage starts a new one (or the
    // campaign has run out of stages entirely).
    final crossedIntoNewCountry =
        atCampaignEnd || _repo.locate(_stage + 1).$2 == 0;
    _reportToGameServices(countryCompleted: crossedIntoNewCountry);
    // Interstitial cadence lives in Ads (never before level 10, then every
    // 3rd clear); it no-ops for remove-ads owners and on web.
    Ads.maybeShowInterstitial(
      totalClears: Progress.instance.totalClears.value,
      levelIndex: _stage,
    );
    if (atCampaignEnd) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _stage++;
      _freeRefillUsed = false;
      _result = _Result.none;
      _showIntro = _introEnabled && crossedIntoNewCountry;
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

  /// Restart throws away everything the player has freed so far and cannot be
  /// undone, so it asks first. The one on the fail sheet does not — that board
  /// is already lost.
  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '다시 시작할까요?',
        body: '지금까지 뺀 화살표가 모두 처음 상태로 돌아갑니다.',
        confirm: '다시 시작',
      ),
    );
    if (ok == true && mounted) _restart();
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
    _coachTimer?.cancel();
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
                  lines: _headerLines,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Container(height: 1, color: c.line),
                _HeartsStrip(hearts: _hearts),
                Expanded(
                  child: Stack(
                    children: [
                      // Flame paints the board wherever it sits, so a zoomed
                      // board would otherwise spill over the header and the
                      // hearts above it.
                      Positioned.fill(
                        child: ClipRect(child: GameWidget(game: _game)),
                      ),
                    ],
                  ),
                ),
                _BoosterBar(
                  game: _game,
                  onResetView: _game.resetView,
                  onRestart: _confirmRestart,
                ),
                const AdsBanner(),
              ],
            ),
            // Coach cue, above the board but below every modal surface.
            if (_coachEnabled && _result == _Result.none && !_showIntro)
              ValueListenableBuilder<bool>(
                valueListenable: Progress.instance.coachDone,
                builder: (context, done, _) => !done
                    ? const _CoachCue('빛나는 화살표를 탭해 보세요',
                        icon: Icons.touch_app_outlined)
                    // A board too large to tap at fit scale is the one case
                    // where the player has to be told about the gesture.
                    : ValueListenableBuilder<bool>(
                        valueListenable: _game.needsZoom,
                        builder: (context, needed, _) => needed
                            ? const _CoachCue('두 손가락으로 확대해 보세요',
                                icon: Icons.pinch_outlined)
                            : const SizedBox.shrink(),
                      ),
              ),
            if (_result != _Result.none)
              _ResultSheet(
                result: _result,
                stage: _localStageLabel,
                place: _placeName,
                freeRefillUsed: _freeRefillUsed,
                onNext: _next,
                onRestart: _restart,
                onRefill: _refill,
              ),
            if (_showIntro && _repo.isLoaded)
              _RoundIntro(
                round: _loc.countryIndex + 1,
                country: _repo.countries[_loc.countryIndex],
                onStart: () => setState(() => _showIntro = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// First-play coach: a single non-blocking line of guidance pinned above the
/// booster bar. It never covers the board and never needs dismissing — the
/// screen retires it as soon as the player frees their first arrow.
class _CoachCue extends StatelessWidget {
  const _CoachCue(this.label, {required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 132,
      child: IgnorePointer(
        child: EnterFade(
          delay: const Duration(milliseconds: 500),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.ink.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: c.bg),
                  const SizedBox(width: 7),
                  Text(label,
                      style: AppText.label.copyWith(
                          color: c.bg, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round-intro page, shown when entering a new country: round number,
/// country name, a short blurb, and the round's stage / city / path makeup.
class _RoundIntro extends StatelessWidget {
  const _RoundIntro({
    required this.round,
    required this.country,
    required this.onStart,
  });
  final int round;
  final CampaignCountry country;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Positioned.fill(
      child: Container(
        color: c.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROUND ${round.toString().padLeft(2, '0')}',
                    style: AppText.label.copyWith(
                        color: c.accent, letterSpacing: 4, fontSize: 13)),
                const SizedBox(height: 12),
                Text(country.displayName,
                    style: AppText.display.copyWith(
                        color: c.ink, fontWeight: FontWeight.w900, height: 1.05)),
                if (country.ko.isNotEmpty && country.name != country.ko)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(country.name,
                        style: AppText.body.copyWith(color: c.inkFaint)),
                  ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Builder(builder: (context) {
                      final lang = Localizations.localeOf(context).languageCode;
                      final blurb = country.introFor(lang);
                      // The fallback has to match the round it describes: a
                      // one-board round has no cities to "connect".
                      final fallback = country.teaches.isNotEmpty
                          ? '이번 라운드에서 배울 것 — ${country.teaches}'
                          : country.cityCount > 0
                              ? '${country.displayName}의 도시 ${country.cityCount}곳을 지나 '
                                  '마지막에 나라 전체를 풀어냅니다.'
                              : '${country.displayName}의 영토를 한 판으로 풀어냅니다.';
                      return Text(
                        blurb.isNotEmpty ? blurb : fallback,
                        style: AppText.body.copyWith(
                            color: c.inkSoft, height: 1.55, fontSize: 15),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stat(c, '${country.stageCount}', '스테이지'),
                    _stat(c, '${country.cityCount}', '도시'),
                    _stat(c, '1', '국가'),
                  ],
                ),
                const SizedBox(height: 22),
                Pressable(
                  onTap: onStart,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('라운드 시작',
                        style: AppText.headline.copyWith(
                            color: c.onAccent, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Column(
            children: [
              Text(value,
                  style: AppText.title.copyWith(
                      color: c.ink, fontWeight: FontWeight.w900, fontSize: 26)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption.copyWith(
                      color: c.inkFaint, letterSpacing: 1.5, fontSize: 11)),
            ],
          ),
        ),
      );
}

/// Place name, centred on the screen's own axis. The back button is laid over
/// the top rather than beside the text, so the name does not drift off-centre
/// with whatever chrome happens to sit next to it.
class _Header extends StatelessWidget {
  const _Header({required this.lines, required this.onBack});

  /// (city, country) on a city board; (country, null) on a country board.
  final (String, String?) lines;
  final VoidCallback onBack;

  static const _sideInset = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (title, subtitle) = lines;
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              // Equal on both sides, so a single line sits dead centre and a
              // two-line block is centred as a block.
              padding: const EdgeInsets.symmetric(horizontal: _sideInset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                          color: c.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.25)),
                  if (subtitle != null)
                    Text(subtitle,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                            color: c.inkSoft,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.25)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Pressable(
                onTap: onBack,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back, color: c.inkFaint, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yes/no over the board. Restart is the only thing in the game that discards
/// work, so it is the only thing that asks.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog(
      {required this.title, required this.body, required this.confirm});
  final String title, body, confirm;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget button(String label, Color bg, Color fg, bool value,
            {bool outline = false}) =>
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).pop(value),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: outline ? Border.all(color: c.line, width: 1.5) : null,
              ),
              child: Text(label,
                  style: AppText.label
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ),
        );

    return Dialog(
      backgroundColor: c.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(
                    color: c.ink, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.inkSoft, fontSize: 13.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                button('취소', Colors.transparent, c.inkSoft, false,
                    outline: true),
                const SizedBox(width: 10),
                button(confirm, c.accent, c.onAccent, true),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

/// Fit-view and restart flank the two boosters. Both booster tiles are the
/// same width and both utility tiles are the same width, so the pair stays on
/// the screen's centre line no matter what the counters read.
class _BoosterBar extends StatelessWidget {
  const _BoosterBar(
      {required this.game, required this.onResetView, required this.onRestart});
  final ZArrowsGame game;
  final VoidCallback onResetView, onRestart;

  /// Running dry is the moment the shop is most relevant — the '+' badge takes
  /// the player straight there instead of doing nothing.
  void _toShop(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    appTab.value = 2;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _UtilButton(
            icon: Icons.center_focus_strong_outlined,
            label: '화면맞춤',
            onTap: onResetView,
          ),
          // The two consumables read as one group; the utilities do not sit
          // inside it.
          Row(mainAxisSize: MainAxisSize.min, children: [
          ValueListenableBuilder<int>(
            valueListenable: Progress.instance.hints,
            builder: (context, n, _) => _BoosterButton(
              icon: 'assets/images/icons/hint.png',
              label: '힌트',
              count: n,
              onTap: () {
                if (n <= 0) {
                  _toShop(context);
                  return;
                }
                // Only debit when a hint was actually shown.
                if (game.showHint()) Progress.instance.useHint();
              },
            ),
          ),
          const SizedBox(width: 14),
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
                  if (n <= 0) {
                    _toShop(context);
                    return;
                  }
                  // Arming is free; the strike itself debits via onRemoveUsed.
                  game.armRemove();
                },
              ),
            ),
          ),
          ]),
          _UtilButton(
            icon: Icons.refresh,
            label: '재시작',
            onTap: onRestart,
          ),
        ],
      ),
    );
  }
}

/// Same anatomy as a booster tile — icon over a caption, same height — but no
/// frame and no counter, because these two cost nothing and never run out.
class _UtilButton extends StatelessWidget {
  const _UtilButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: c.inkSoft),
            const SizedBox(height: 3),
            Text(label,
                style: AppText.caption.copyWith(
                    fontSize: 9, color: c.inkFaint, letterSpacing: 0.5)),
          ],
        ),
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
  final String stage;
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
            const SafeArea(bottom: false, child: AdsMrec()),
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
          Text('${place.isEmpty ? '' : '$place · '}$stage',
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
