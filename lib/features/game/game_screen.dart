import 'dart:async';
import 'dart:math' as math;

// Flame and Flutter both export a Matrix4 (vector_math vs vector_math_64); we
// only need GameWidget from Flame here, so hide its Matrix4 and let Flutter's
// (which Transform expects) win.
import 'package:country_flags/country_flags.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../game/z_arrows_game.dart';
import '../../models/campaign_repository.dart'
    show CampaignCountry, CampaignRepository, CampaignStage, StageKind;
import '../../services/ads/ads.dart';
import '../../services/game_services.dart';
import '../../services/iap.dart';
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

  // ── Board pan/zoom ──────────────────────────────────────────────────────
  // Pinch to zoom, drag to pan — handled by an InteractiveViewer over the
  // GameWidget. Tapping an arrow, though, is NOT left to Flame: with one-finger
  // pan enabled everywhere (boundaryMargin: infinity), the InteractiveViewer's
  // pan recogniser would claim any press with the slightest travel and swallow
  // the tap. So a Listener above it watches raw pointers — a single pointer that
  // lifts near where it landed is routed straight to the game as a tap; anything
  // with real travel falls through to the InteractiveViewer as a pan/zoom.
  final TransformationController _boardTc = TransformationController();

  /// The visible play area — the gap between the chrome — in body coordinates.
  /// The game surface itself is the whole body (so an escaping arrow can leave
  /// the screen), but the board is fitted to this and the pan clamp measures
  /// its centre line against it. Measured after layout rather than assumed,
  /// because the bottom chrome swaps between the booster bar and the clear bar
  /// and the ad slot disappears for remove-ads owners.
  Rect _playRect = Rect.zero;
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _playAreaKey = GlobalKey();

  void _syncPlayRect() {
    final area = _playAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (area == null || body == null || !area.hasSize || !body.hasSize) return;
    final rect = area.localToGlobal(Offset.zero, ancestor: body) & area.size;
    if (rect == _playRect) return;
    _playRect = rect;
    _game.setPlayInsets(rect.top, body.size.height - rect.bottom);
    _clampBoard();
  }

  Offset? _pointerDownAt;
  int _activePointers = 0;
  bool _tapCandidate = false;

  /// Travel (logical px) a press may drift and still count as a tap, not a pan.
  /// Under the InteractiveViewer's own ~18px pan threshold, so a tap never also
  /// nudges the board.
  static const double _tapMoveSlop = 16;

  void _onBoardPointerDown(PointerDownEvent e) {
    _activePointers++;
    if (_activePointers == 1) {
      _pointerDownAt = e.localPosition;
      _tapCandidate = true;
    } else {
      _tapCandidate = false; // second finger = pinch/zoom, never a tap
    }
  }

  void _onBoardPointerUp(PointerUpEvent e) {
    final wasSingle = _activePointers == 1;
    _activePointers = (_activePointers - 1).clamp(0, 100);
    final down = _pointerDownAt;
    if (!wasSingle || !_tapCandidate || down == null) return;
    _tapCandidate = false;
    if ((e.localPosition - down).distance > _tapMoveSlop) return;
    // Viewport point -> Flame scene point (undo the pan/zoom matrix).
    final scene = MatrixUtils.transformPoint(
        Matrix4.inverted(_boardTc.value), e.localPosition);
    _game.tapAtScene(scene.dx, scene.dy);
  }

  void _onBoardPointerCancel(PointerCancelEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 100);
    _tapCandidate = false;
  }

  /// Back to the whole silhouette (the 화면맞춤 button, and every new board).
  void _resetBoardView() => _boardTc.value = Matrix4.identity();

  /// Keep the board on screen: no edge of the *grid* may be dragged past the
  /// viewport's centre line, so at least half the puzzle always shows (and it
  /// can never hide behind the header). Clamping on the child's edges instead
  /// would be too loose — the grid is inset inside the GameWidget by the fit
  /// margin and the letterbox, so on the shorter axis it could travel 20-30%
  /// past centre. Runs on every controller change; the clamp is idempotent, so
  /// re-setting the value here doesn't loop.
  void _clampBoard() {
    final v = _playRect;
    if (v.isEmpty) return;
    // Before the first board layout, fall back to the whole play area.
    final r = _game.boardRect ?? v;
    final m = _boardTc.value;
    final s = m.getMaxScaleOnAxis();
    final tx = m.storage[12], ty = m.storage[13];
    // Grid edges in body coords: left = tx + s*r.left, right = tx + s*r.right.
    // Keeping left ≤ centre and right ≥ centre bounds the translation to
    // [centre - s*right, centre - s*left].
    final cx = tx.clamp(v.center.dx - s * r.right, v.center.dx - s * r.left);
    final cy = ty.clamp(v.center.dy - s * r.bottom, v.center.dy - s * r.top);
    if (cx != tx || cy != ty) {
      _boardTc.value = m.clone()
        ..storage[12] = cx
        ..storage[13] = cy;
    }
  }

  @override
  void initState() {
    super.initState();
    _game = _buildGame(AppColors.light);
    _boardTc.addListener(_clampBoard);
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
    // Finishing a country can complete its continent (the last country of that
    // continent in area order). Idempotent, so pass every completed continent.
    if (countryCompleted && _repo.isLoaded) {
      unawaited(GameServices.unlockContinents(
          _repo.completedContinents(_loc.countryIndex)));
    }
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

  /// True when the current board is a travel interlude, not a place.
  bool get _isPath => _repo.stageAt(_stage)?.kind == StageKind.path;

  /// What this particular board depicts — a city, the country itself on the
  /// round's last stage, or (on a travel leg) the country the round is heading
  /// to. This is the label revealed on clear.
  String get _placeName {
    // A travel leg announces the round's destination country ("Next Atlas").
    if (_isPath) return _countryName;
    return _repo.stageAt(_stage)?.displayName ?? _countryName;
  }

  /// The city this board depicts, or '' on the country finale and on a travel
  /// leg — in both cases the place chip carries the country name alone (a path
  /// heads toward the round's country; the finale is the country).
  String get _cityLabel {
    final st = _repo.stageAt(_stage);
    if (st == null || st.kind != StageKind.city) return '';
    return st.displayName;
  }

  /// The ISO 3166-1 alpha-2 code of the country this stage belongs to, used to
  /// render its flag image in the header and on clear. A travel leg is not a
  /// country, so it carries no flag.
  String get _flagIso => _isPath || !_repo.isLoaded
      ? ''
      : _repo.countries[_loc.countryIndex].iso;

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
      // Direct pop: the PopScope guard below blocks maybePop while playing.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stage++;
      _freeRefillUsed = false;
      _result = _Result.none;
      _showIntro = _introEnabled && crossedIntoNewCountry;
    });
    _game.loadLevel(_repo.levelAt(_stage));
    _resetBoardView();
  }

  void _restart() {
    setState(() {
      _freeRefillUsed = false;
      _result = _Result.none;
    });
    _game.restartLevel();
    _resetBoardView();
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

  /// Leaving mid-stage throws away the board in progress, so — like restart —
  /// it asks first. Once a result sheet is up the board is already resolved,
  /// so backing out there is immediate. Uses a direct pop because the PopScope
  /// guard blocks maybePop while the player is still on the board.
  Future<void> _maybeLeave() async {
    if (_result != _Result.none) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '게임을 나갈까요?',
        body: '지금 풀던 판은 저장되지 않아요.',
        confirm: '나가기',
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
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
    _boardTc.removeListener(_clampBoard);
    _boardTc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    _game.palette = c;
    // The play area can only be measured once this frame is laid out; the
    // chrome around it changes with the result state and the ad slot.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPlayRect());
    return PopScope(
      // Guard the system back gesture the same way as the header button —
      // confirm before discarding an in-progress board.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave();
      },
      child: Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          key: _bodyKey,
          children: [
            // The board surface is the whole body, not the gap between the
            // chrome: an escaping arrow has to be able to fly off the screen
            // and slide under the header, the way the reference games do.
            // The chrome is painted over it below, opaque, so it does.
            Positioned.fill(
              // Clipped to the body, not to the play area: by the time a line
              // reaches this edge it is already behind the header or the
              // booster bar, so the clip is invisible — it only stops a panned
              // board from painting up into the status bar.
              child: ClipRect(
                child: Listener(
                onPointerDown: _onBoardPointerDown,
                onPointerUp: _onBoardPointerUp,
                onPointerCancel: _onBoardPointerCancel,
                // Zoom-out stops at fit (minScale 1); zoom-in stops where a
                // cell reaches a comfortable tap size, which depends on the
                // board — see ZArrowsGame.maxZoom.
                child: ValueListenableBuilder<double>(
                  valueListenable: _game.maxZoom,
                  child: GameWidget(game: _game),
                  builder: (context, maxZoom, child) => InteractiveViewer(
                    transformationController: _boardTc,
                    minScale: 1,
                    maxScale: maxZoom,
                    // One-finger pan stays enabled everywhere; the reach is
                    // bounded by _clampBoard (no edge past the play area's
                    // centre) rather than by boundaryMargin, so this stays
                    // infinite.
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    clipBehavior: Clip.none,
                    child: child!,
                  ),
                ),
                ),
              ),
            ),
            Column(
              children: [
                ColoredBox(
                  color: c.bg,
                  child: Column(
                    children: [
                      _Header(
                        stageLabel: 'STAGE ${_stage + 1}',
                        city: _cityLabel,
                        country: _countryName,
                        flagIso: _flagIso,
                        onBack: _maybeLeave,
                      ),
                      Container(height: 1, color: c.line),
                      // Clearing hands the board over to the reveal, so the
                      // hearts and the booster bar step aside; the fail path
                      // keeps them.
                      if (_result != _Result.cleared)
                        _HeartsStrip(hearts: _hearts),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Empty probe: it measures the visible play area, which
                      // is what the board is fitted to and what the pan clamp
                      // measures against. Hit-tests through to the board.
                      SizedBox.expand(key: _playAreaKey),
                      // On clear, the solved board gives way in place to the
                      // territory silhouette: grey dots rise, then accent
                      // sweeps out from the centre.
                      if (_result == _Result.cleared &&
                          _repo.stageAt(_stage) != null)
                        Positioned.fill(
                          child: _ClearReveal(stage: _repo.stageAt(_stage)!),
                        ),
                    ],
                  ),
                ),
                ColoredBox(
                  color: c.bg,
                  child: _result == _Result.cleared
                      ? _ClearNextBar(onNext: _next)
                      : Column(
                          children: [
                            _BoosterBar(
                              game: _game,
                              onResetView: _resetBoardView,
                              onRestart: _confirmRestart,
                            ),
                            const AdsBanner(),
                          ],
                        ),
                ),
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
            // Clear is now the in-place reveal above; only the fail sheet
            // (hearts refill) remains a modal surface over the board.
            if (_result == _Result.failed)
              _ResultSheet(
                result: _result,
                stage: _localStageLabel,
                place: _placeName,
                flagIso: _flagIso,
                isPath: _isPath,
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

/// A country's flag as a real image (offline SVG by ISO code), rounded to sit
/// beside a place name. Replaces the flag emoji, which Android has no glyphs
/// for and would render as bare country letters.
class _FlagImg extends StatelessWidget {
  const _FlagImg({required this.iso, required this.height});
  final String iso;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CountryFlag.fromCountryCode(
          iso,
          theme: ImageTheme(width: height * 4 / 3, height: height),
        ),
      );
}

/// Back + stage number on the left; a small place chip (flag over city ·
/// country) pinned to the top-right, so the player always knows where on the
/// globe this board sits. On the country finale the city drops out and the
/// chip carries the country alone.
class _Header extends StatelessWidget {
  const _Header({
    required this.stageLabel,
    required this.city,
    required this.country,
    required this.flagIso,
    required this.onBack,
  });

  final String stageLabel, city, country, flagIso;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Pressable(
              onTap: onBack,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back, color: c.inkFaint, size: 24),
              ),
            ),
            Text(stageLabel,
                style: AppText.label.copyWith(
                    color: c.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (country.isNotEmpty) _placeChip(c),
          ],
        ),
      ),
    );
  }

  Widget _placeChip(AppColors c) {
    final primary = city.isNotEmpty ? city : country;
    final secondary = city.isNotEmpty ? country : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 172),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flagIso.isNotEmpty) ...[
            _FlagImg(iso: flagIso, height: 15),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                        color: c.ink, fontSize: 13, fontWeight: FontWeight.w800)),
                if (secondary != null)
                  Text(secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption
                          .copyWith(color: c.inkFaint, fontSize: 10.5)),
              ],
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

  /// Running dry mid-board is the moment a top-up is most relevant, but sending
  /// the player to the shop tab would tear down the board being solved. So the
  /// '+' badge raises a sheet in place — buy bundles or watch an ad for a hint —
  /// and the board stays live underneath.
  void _openItemSheet(BuildContext context, {required bool forHint}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(forHint: forHint),
    );
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
                  _openItemSheet(context, forHint: true);
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
                    _openItemSheet(context, forHint: false);
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

/// The clear / fail sheet. It is the most-repeated modal in the game, so it
/// arrives instead of snapping: the scrim fades in and the sheet rises from
/// the bottom on an ease-out curve. Collapses to a static frame under
/// OS reduce-motion.
class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.result,
    required this.stage,
    required this.place,
    required this.flagIso,
    required this.isPath,
    required this.freeRefillUsed,
    required this.onNext,
    required this.onRestart,
    required this.onRefill,
  });
  final _Result result;
  final String stage;
  final String place;
  final String flagIso;
  final bool isPath;
  final bool freeRefillUsed;
  final VoidCallback onNext, onRestart;
  final void Function({required bool viaAd}) onRefill;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppDur.slow);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: AppCurve.gentle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Enter once. Under reduce-motion the sheet is already fully in place, so
    // there is nothing to play.
    if (_c.status == AnimationStatus.dismissed) {
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cleared = widget.result == _Result.cleared;
    final sheet = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: cleared ? _clear(c) : _fail(c),
    );
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => Container(
          color: Colors.black.withValues(alpha: 0.35 * _t.value),
          child: Column(
            children: [
              // MREC pinned to the very top of the screen
              const SafeArea(bottom: false, child: AdsMrec()),
              const Spacer(),
              // Slide up by the sheet's own height — no measured value needed.
              FractionalTranslation(
                translation: Offset(0, 1 - _t.value),
                child: sheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clear(AppColors c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.stage,
              style: AppText.caption.copyWith(color: c.inkFaint, letterSpacing: 3)),
          const SizedBox(height: 10),
          // A travel leg points ahead to the round's destination country
          // ("Next Atlas" over the country name, no flag); a place board
          // reveals the place name + flag it held back from the header.
          if (widget.isPath) ...[
            Text('NEXT ATLAS',
                style: AppText.caption.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 6),
            if (widget.place.isNotEmpty)
              Text(widget.place,
                  textAlign: TextAlign.center,
                  style: AppText.title.copyWith(
                      color: c.ink, fontWeight: FontWeight.w800, fontSize: 22)),
          ] else ...[
            if (widget.place.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.flagIso.isNotEmpty) ...[
                    _FlagImg(iso: widget.flagIso, height: 22),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(widget.place,
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 22)),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text('클리어!',
                style: AppText.headline.copyWith(
                    color: c.accent, fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 18),
          _bigButton(c, '다음 스테이지', c.accent, c.onAccent, widget.onNext),
        ],
      );

  Widget _fail(AppColors c) {
    final free = !widget.freeRefillUsed;
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
          () => widget.onRefill(viaAd: !free),
        ),
        const SizedBox(height: 10),
        _bigButton(c, '다시 시작', Colors.transparent, c.inkFaint, widget.onRestart,
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

/// In-play top-up sheet, raised when a booster hits zero. Lists every refill
/// path — a free rewarded-ad hint plus the store bundles — as buttons, so the
/// player restocks without leaving the board, which keeps playing underneath.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.forHint});

  /// Which booster ran out — sets the heading and which bundle leads.
  final bool forHint;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _iap = IapService.instance;

  /// Guards the ad row against a double tap while the ad opens.
  bool _watchingAd = false;

  void _watchAdForHint() {
    if (_watchingAd) return;
    setState(() => _watchingAd = true);
    Ads.showRewarded(
      onReward: () {
        Progress.instance.grantHints(1);
        // Got what they came for — close the sheet and let them play on.
        if (mounted) Navigator.of(context).pop();
      },
      onUnavailable: () {
        if (!mounted) return;
        setState(() => _watchingAd = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('지금은 볼 수 있는 광고가 없어요. 잠시 후 다시 시도해 주세요.')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
          const SizedBox(height: 16),
          Text(widget.forHint ? '힌트가 없어요' : '제거가 없어요',
              style: AppText.title.copyWith(
                  color: c.ink, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          Text('채우고 이어서 풀 수 있어요.',
              style: AppText.body.copyWith(color: c.inkSoft, fontSize: 13.5)),
          const SizedBox(height: 18),
          // Prices and disabled states track the store, so rebuild on both.
          ValueListenableBuilder<List<ProductDetails>>(
            valueListenable: _iap.products,
            builder: (context, _, _) => ValueListenableBuilder<bool>(
              valueListenable: _iap.busy,
              builder: (context, busy, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: _rows(c, busy),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(AppColors c, bool busy) {
    // The free ad only ever grants a hint, so it travels with the hint bundles.
    final ad = _row(
      c,
      icon: 'assets/images/icons/hint.png',
      label: '광고 보고 힌트 +1',
      trailing: _watchingAd ? '재생 중…' : '무료',
      tint: c.success,
      enabled: !_watchingAd,
      onTap: _watchAdForHint,
    );
    final hints = [
      ad,
      for (final id in IapService.hintProducts.keys)
        _productRow(c, id, 'assets/images/icons/hint.png',
            '힌트 ${IapService.hintProducts[id]}개', busy),
    ];
    final removes = [
      for (final id in IapService.removeProducts.keys)
        _productRow(c, id, 'assets/images/icons/remove.png',
            '제거 ${IapService.removeProducts[id]}개', busy),
    ];
    // Lead with whichever item ran out.
    return widget.forHint ? [...hints, ...removes] : [...removes, ...hints];
  }

  Widget _productRow(
      AppColors c, String id, String icon, String label, bool busy) {
    final product = _iap.productFor(id);
    return _row(
      c,
      icon: icon,
      label: label,
      // Store's localized price when registered, 준비중 until then.
      trailing: product?.price ?? '준비중',
      tint: c.accent,
      enabled: product != null && !busy,
      onTap: product != null ? () => _iap.buy(product) : null,
    );
  }

  Widget _row(
    AppColors c, {
    required String icon,
    required String label,
    required String trailing,
    required Color tint,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: c.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Image.asset(icon, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppText.label
                    .copyWith(color: c.ink, fontWeight: FontWeight.w800)),
          ),
          Text(trailing,
              style: AppText.label.copyWith(
                  color: enabled ? tint : c.inkFaint,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.55, child: tile);
    }
    return Pressable(onTap: onTap, child: tile);
  }
}

/// The clear moment, in place of a bottom sheet: the solved board dissolves
/// into the territory it depicted. Grey silhouette dots rise, then accent
/// sweeps out from the centroid to the edges. Freezes to the finished frame
/// under OS reduce-motion.
class _ClearReveal extends StatefulWidget {
  const _ClearReveal({required this.stage});
  final CampaignStage stage;

  @override
  State<_ClearReveal> createState() => _ClearRevealState();
}

class _ClearRevealState extends State<_ClearReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));

  late final List<(int, int)> _cells = widget.stage.mask.toList();
  late final double _cr, _cc, _maxDist;

  @override
  void initState() {
    super.initState();
    var sr = 0.0, sc = 0.0;
    for (final (r, cc) in _cells) {
      sr += r;
      sc += cc;
    }
    final n = _cells.isEmpty ? 1 : _cells.length;
    _cr = sr / n;
    _cc = sc / n;
    var md = 0.0;
    for (final (r, cc) in _cells) {
      final dr = r - _cr, dc = cc - _cc;
      final d = math.sqrt(dr * dr + dc * dc);
      if (d > md) md = d;
    }
    _maxDist = md <= 0 ? 1 : md;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _RevealPainter(
            widget.stage, _cells, _cr, _cc, _maxDist, c, _c.value),
      ),
    );
  }
}

double _smoothstep(double x, double a, double b) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Stable pseudo-random [0,1) per grid cell, so the reveal's grainy edge is
/// jittered the same way on every frame (not shimmering).
double _cellHash(int r, int c) {
  var h = (r * 73856093) ^ (c * 19349663);
  h &= 0x7fffffff;
  return (h % 1000) / 1000.0;
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(
      this.stage, this.cells, this.cr, this.cc, this.maxDist, this.c, this.t);
  final CampaignStage stage;
  final List<(int, int)> cells;
  final double cr, cc, maxDist, t;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    // Opaque ground hides the emptied board underneath.
    canvas.drawRect(Offset.zero & size, Paint()..color = c.bg);
    final cols = stage.cols, rows = stage.rows;
    final scale = math.min(size.width / cols, size.height / rows);
    final dx = (size.width - cols * scale) / 2;
    final dy = (size.height - rows * scale) / 2;
    final r = scale * 0.44;

    final grayA = (t / 0.20).clamp(0.0, 1.0); // silhouette fades in first
    // Irregular wavefront: a low-frequency angular wobble bends the front into
    // lobes, and a per-cell hash jitter grains the edge so it dissolves outward
    // instead of sweeping as a clean ring. All in grid units.
    const jitter = 1.4, edge = 1.8;
    final reach = maxDist * 1.34 + jitter + edge;
    final spread = _smoothstep(t, 0.16, 0.90) * reach;
    final phaseA = (cells.length % 17) * 0.37;
    final phaseB = (cells.length % 11) * 0.53;
    final p = Paint();
    for (final (rr, ccc) in cells) {
      final x = dx + ccc * scale + scale / 2;
      final y = dy + rr * scale + scale / 2;
      final dr = rr - cr, dc = ccc - cc;
      final dist = math.sqrt(dr * dr + dc * dc);
      final ang = math.atan2(dr, dc);
      final wob = 1 +
          0.20 * math.sin(3 * ang + phaseA) +
          0.12 * math.sin(5 * ang + phaseB);
      final eff = dist * wob + (_cellHash(rr, ccc) - 0.5) * 2 * jitter;
      final a = ((spread - eff) / edge).clamp(0.0, 1.0);
      p.color = Color.lerp(c.inkFaint, c.accent, a)!.withValues(alpha: grayA);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.t != t || old.c != c || !identical(old.cells, cells);
}

/// The single action after a clear: advance. It rises in after the reveal has
/// swept, so the territory reads first and the button second.
class _ClearNextBar extends StatelessWidget {
  const _ClearNextBar({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: EnterFade(
        delay: const Duration(milliseconds: 1450),
        rise: 12,
        child: Pressable(
          onTap: onNext,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('다음 스테이지',
                style: AppText.headline
                    .copyWith(color: c.onAccent, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
