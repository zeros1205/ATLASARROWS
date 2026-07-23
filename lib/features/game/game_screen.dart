import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

// Flame and Flutter both export a Matrix4 (vector_math vs vector_math_64); we
// only need GameWidget from Flame here, so hide its Matrix4 and let Flutter's
// (which Transform expects) win.
import 'package:country_flags/country_flags.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../game/atlas_arrows_game.dart';
import '../../models/campaign_repository.dart'
    show CampaignCountry, CampaignRepository, StageKind;
import '../../services/ads/ads.dart';
import '../../services/game_services.dart';
import '../../services/iap.dart';
import '../../services/progress.dart';
import '../../services/stamp_store.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import '../home/play_transition.dart';

/// How the campaign is traversed. World Tour walks the fixed order and advances
/// the unlock frontier; Random serves any stage, avoiding ones already played.
enum PlayMode { worldTour, random }

/// One stage of the campaign: a header (stage number centred, hearts right),
/// a translucent place chip floating under it, the board, a bottom bar
/// (fit view / hint / remove / restart) and a banner. On clear the chrome is
/// hidden and an arrival card stamps the place in; the fail sheet is a bottom
/// sheet with a top MREC banner. Heart economy grants a free refill then ads.
class GameScreen extends StatefulWidget {
  const GameScreen(
      {super.key,
      required this.stage,
      this.dive,
      this.entrance = false,
      this.mode = PlayMode.worldTour});
  final int stage;

  /// When present, the screen was opened by the home sky-dive: the entrance
  /// sequence (globe dive → name card → board dots rain in → arrows fill →
  /// chrome slides in) starts with the dive. Null on every other entry — but
  /// Random Play still plays the same sequence minus the dive itself; see
  /// [_GameScreenState._entranceSequence].
  final DiveArgs? dive;

  /// Play the entrance sequence *without* the globe dive — the name card →
  /// board reveal → chrome slide-in → quadrant zoom, starting straight at the
  /// name card. Set by the map entry (country detail → country/city), which
  /// wants the same arrival as Random Play but has no map dot to dive from.
  final bool entrance;

  /// World Tour (fixed order) or Random (lucky-dip). Drives what "next" does,
  /// and — with [dive] — whether this entry plays the entrance sequence.
  final PlayMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Result { none, cleared, failed }

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _repo = CampaignRepository.instance;
  final _rng = math.Random();
  late int _stage = widget.stage;
  late AtlasArrowsGame _game;
  final _hearts = ValueNotifier<int>(AtlasArrowsGame.maxHearts);
  _Result _result = _Result.none;

  /// Home sky-dive entrance state. [_diving] holds the globe overlay on top of
  /// the board; [_chromeIn] is the phase-5 flag that slides the top/bottom bars
  /// in. Both stay false on every non-dive entry, leaving the screen unchanged.
  bool _diving = false;
  bool _chromeIn = false;

  /// The blank beat after touchdown (phase 3): the place's name + flag hold in
  /// the centre for a moment, then fade, before the board starts assembling.
  bool _titleCard = false;

  /// True for any entry that should play the name-card → board-reveal →
  /// chrome-slide-in sequence: a World Tour sky-dive has a [dive] to fly in
  /// from, and Random Play has nowhere to dive from (no map dot to start at)
  /// but still gets the same card + reveal, just starting straight at phase 3.
  bool get _entranceSequence =>
      widget.dive != null || widget.entrance || widget.mode == PlayMode.random;

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
    if (rect != _playRect) {
      _playRect = rect;
      _game.setPlayInsets(rect.top, body.size.height - rect.bottom);
      _clampBoard();
    }
    // Independent of whether the rect itself changed this frame — a fresh
    // level load doesn't touch the chrome, so the rect is usually unchanged,
    // but [_autoZoomPending] still needs consuming once the new board's rect
    // exists.
    _maybeStartAutoZoom();
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

  // ── Auto-zoom entrance ──────────────────────────────────────────────────
  // Every fresh board opens on the whole silhouette, then the camera itself
  // dives into one of the four quadrants — the same falling-in feel as the
  // home sky-dive, but this one lands the player already zoomed in on a
  // corner of the puzzle instead of leaving them to pinch in themselves.

  /// Armed on every level (re)load; consumed the first time [_syncPlayRect]
  /// sees a real board rect afterwards, since the board's layout (and so its
  /// [AtlasArrowsGame.boardRect]) isn't available until a frame after the
  /// level loads.
  ///
  /// An entrance-sequence entry (dive or random) starts this false: the board
  /// sits behind the dive/title-card overlays for a while, and arming it
  /// immediately would fly the camera to its target unseen before the reveal
  /// even starts. [_buildGame] arms it instead once the dots/arrows reveal
  /// finishes, so the player actually sees the dive-in.
  late bool _autoZoomPending = !_entranceSequence;
  AnimationController? _autoZoomCtrl;

  void _maybeStartAutoZoom() {
    if (!_autoZoomPending) return;
    final r = _game.boardRect;
    if (r == null || _playRect.isEmpty) return;
    _autoZoomPending = false;
    _autoZoomToQuadrant(r);
  }

  /// [AtlasArrowsGame.maxZoom] is the *deepest* zoom the player can pinch to —
  /// landing the auto zoom there read as way too far in. Half of it matched a
  /// reference screenshot at a comfortable "several cells at a glance" depth,
  /// so that's the entrance target instead.
  static const double _entranceZoomFactor = 0.5;

  /// Margin left on the two edges the chosen quadrant opens toward — as a
  /// share of the play area. Not centred on the quadrant: a line escapes by
  /// sliding off the board's edge, so the corner the quadrant points at needs
  /// open space beyond it for that exit to actually be visible in frame.
  static const double _entranceMargin = 0.20;

  /// Picks which board quadrant the entrance dive falls into, as the (qx, qy)
  /// sign pair [_autoZoomToQuadrant] expects. A plain random pick flies the
  /// camera into an empty corner whenever the silhouette is diagonally long
  /// (content in quadrants II+IV leaves I+III blank), so the pick is weighted
  /// by how many silhouette cells sit in each quadrant and drops the near-empty
  /// ones. A compact board keeps all four quadrants, so the entrance still
  /// varies; only the genuinely empty corners are excluded. Falls back to a
  /// uniform random pick when the board exposes no cells.
  (double, double) _pickEntranceQuadrant() {
    final counts = _game.quadrantCellCounts();
    final maxCount = counts.values.fold(0, math.max);
    if (maxCount == 0) {
      return (_rng.nextBool() ? -1.0 : 1.0, _rng.nextBool() ? -1.0 : 1.0);
    }
    final threshold = maxCount * 0.2;
    final eligible =
        counts.entries.where((e) => e.value >= threshold).toList();
    final total = eligible.fold(0, (sum, e) => sum + e.value);
    var pick = _rng.nextInt(total);
    for (final e in eligible) {
      pick -= e.value;
      if (pick < 0) return (e.key.$1.toDouble(), e.key.$2.toDouble());
    }
    final last = eligible.last.key;
    return (last.$1.toDouble(), last.$2.toDouble());
  }

  /// Flies the view from the fit-to-screen state into one of the board's
  /// content-bearing quadrants, over 1.5s. The target is a fixed fraction of
  /// [AtlasArrowsGame.maxZoom] — the same value every other zoom control
  /// normalises by cell size — so the on-screen cell size, and so the arrow
  /// stroke width, still lands the same regardless of how many rows/columns
  /// this particular stage has; it's just shallower than the pinch limit.
  void _autoZoomToQuadrant(Rect boardRect) {
    final (qx, qy) = _pickEntranceQuadrant();
    // Aim at a corner of the quadrant's actual silhouette cells, not the grid
    // box: an irregular board (a city like Nairobi) leaves its grid-box corners
    // empty, so the old grid-corner target flew the camera onto blank space.
    // Falls back to the grid box only if the quadrant somehow exposes no cells.
    final content =
        _game.quadrantMaskRect(qx > 0 ? 1 : -1, qy < 0 ? -1 : 1) ?? boardRect;
    // The content corner this quadrant opens toward: qx>0/qy<0 is the
    // right/top corner (quadrant I), qx<0/qy<0 the left/top (II), qx<0/qy>0
    // the left/bottom (III), qx>0/qy>0 the right/bottom (IV) — canvas y grows
    // downward, so "top" is the smaller-y edge.
    final corner = Offset(
      qx > 0 ? content.right : content.left,
      qy < 0 ? content.top : content.bottom,
    );
    // Where that corner should land on screen: inset by the margin from the
    // same two edges it opens toward, leaving that fraction of the play area
    // clear beyond it.
    final vp = Offset(
      _playRect.left +
          _playRect.width * (qx > 0 ? 1 - _entranceMargin : _entranceMargin),
      _playRect.top +
          _playRect.height * (qy < 0 ? _entranceMargin : 1 - _entranceMargin),
    );
    final zoom = _game.maxZoom.value * _entranceZoomFactor;
    final end = Matrix4.identity()
      ..translate(vp.dx, vp.dy)
      ..scale(zoom)
      ..translate(-corner.dx, -corner.dy);
    _animateBoardTo(end, ms: 1500, curve: Curves.easeInCubic);
  }

  /// Pans (keeping the current zoom) so an off-screen hinted line lands in the
  /// centre of the play area. [rect] is the line's footprint in the game's
  /// canvas coordinates; the clamp keeps the board on screen afterwards. Fired
  /// only when a hint would otherwise blink on a line the player can't see.
  void _revealForHint(Rect rect) {
    if (_playRect.isEmpty) return;
    final s = _boardTc.value.getMaxScaleOnAxis();
    final target = rect.center;
    final vp = _playRect.center;
    final end = Matrix4.identity()
      ..translate(vp.dx, vp.dy)
      ..scale(s)
      ..translate(-target.dx, -target.dy);
    _animateBoardTo(end, ms: 450, curve: Curves.easeInOutCubic);
  }

  /// Runs the shared board-transform tween used by the entrance zoom and the
  /// hint pan. Snaps instead under OS reduce-motion.
  void _animateBoardTo(Matrix4 end, {required int ms, required Curve curve}) {
    if (reduceMotion(context)) {
      _boardTc.value = end;
      return;
    }
    _autoZoomCtrl?.dispose();
    final ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: ms));
    _autoZoomCtrl = ctrl;
    final tween = Matrix4Tween(begin: _boardTc.value, end: end)
        .animate(CurvedAnimation(parent: ctrl, curve: curve));
    tween.addListener(() => _boardTc.value = tween.value);
    ctrl.forward();
  }

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
      return; // the re-set fires this listener again with the clamped values
    }
    // An escaping line has to fly past the edge of the *view*, which the pan
    // and zoom move around over the canvas.
    _game.setView(s, cx, cy);
  }

  @override
  void initState() {
    super.initState();
    _diving = widget.dive != null;
    // Random Play has no map dot to dive from, but still gets the entrance
    // sequence — it just starts straight at phase 3 (the name card) instead
    // of behind the globe dive.
    _titleCard = _entranceSequence && !_diving;
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

  AtlasArrowsGame _buildGame(AppColors palette) => AtlasArrowsGame(
        initialLevel: _repo.levelAt(_stage),
        palette: palette,
        onHeartsChanged: (h) => _hearts.value = h,
        onCleared: () => setState(() => _result = _Result.cleared),
        onFailed: () => setState(() => _result = _Result.failed),
        onEscaped: _onEscaped,
        onRemoveUsed: Progress.instance.useRemove,
        onHintOffView: _revealForHint,
        introOnLoad: _entranceSequence,
        // Phase 5: the arrows have started filling — bring the chrome in.
        onIntroArrows: () {
          if (mounted) setState(() => _chromeIn = true);
        },
        // The reveal has finished and the board is fully visible — only now
        // is it worth flying the camera into a quadrant.
        onIntroDone: () {
          if (!mounted) return;
          _autoZoomPending = true;
          _maybeStartAutoZoom();
        },
      );

  /// The globe dive has touched down: drop the overlay and, on the now-blank
  /// screen, hold the place's name card for a beat.
  void _onDiveDone() {
    if (!mounted) return;
    setState(() {
      _diving = false;
      _titleCard = true;
    });
  }

  /// The name card has faded: start the board's own reveal (dots rain, then
  /// arrows fill).
  void _onTitleDone() {
    if (!mounted) return;
    setState(() => _titleCard = false);
    _game.beginIntro();
  }

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
      flawless: _hearts.value == AtlasArrowsGame.maxHearts,
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

  /// Active UI language, for place-name selection.
  String get _lang => Localizations.localeOf(context).languageCode;

  /// The country this stage belongs to.
  String get _countryName {
    if (!_repo.isLoaded) return '';
    return _repo.countries[_loc.countryIndex].nameFor(_lang);
  }

  /// The city this board depicts, or '' on the country finale — there the place
  /// chip and arrival card carry the country name alone.
  String get _cityLabel {
    final st = _repo.stageAt(_stage);
    if (st == null || st.kind != StageKind.city) return '';
    return st.nameFor(_lang);
  }

  /// The ISO 3166-1 alpha-2 code of the country this stage belongs to, used to
  /// render its flag image in the header and on clear.
  String get _flagIso =>
      !_repo.isLoaded ? '' : _repo.countries[_loc.countryIndex].iso;

  /// The campaign rank of the current stage's country — keys the visa stamp.
  int get _countryRank =>
      !_repo.isLoaded ? 0 : _repo.countries[_loc.countryIndex].rank;

  void _next() {
    if (widget.mode == PlayMode.random) {
      _nextRandom();
      return;
    }
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
      _result = _Result.none;
      _showIntro = _introEnabled && crossedIntoNewCountry;
    });
    _game.loadLevel(_repo.levelAt(_stage));
    _resetBoardView();
    _autoZoomPending = true;
  }

  /// Random play: count the clear (without touching the World Tour frontier),
  /// mark the stage served, and jump to a fresh random one. When every stage
  /// has come up the served set loops so play never dead-ends.
  void _nextRandom() {
    Progress.instance.addClear();
    Progress.instance.markPlayedRandom(_stage, _repo.totalStages);
    _reportToGameServices(countryCompleted: false);
    Ads.maybeShowInterstitial(
      totalClears: Progress.instance.totalClears.value,
      levelIndex: _stage,
    );
    final next = _repo.randomStage(Progress.instance.playedRandom, _rng) ??
        _repo.randomStage(const {}, _rng);
    if (next == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stage = next;
      _result = _Result.none;
      _showIntro = false;
    });
    _game.loadLevel(_repo.levelAt(_stage));
    _resetBoardView();
    _autoZoomPending = true;
  }

  void _restart() {
    setState(() => _result = _Result.none);
    _game.restartLevel();
    _resetBoardView();
    _autoZoomPending = true;
  }

  /// Restart throws away everything the player has freed so far and cannot be
  /// undone, so it asks first. The one on the fail sheet does not — that board
  /// is already lost.
  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      // Centre on the SCREEN. showDialog defaults to useSafeArea: true, which
      // centres inside the status-bar inset instead and drops the box low
      // enough that its title, not its middle, sits on the centre line.
      useSafeArea: false,
      builder: (dctx) {
        final l = AppLocalizations.of(dctx);
        return _ConfirmDialog(
          title: l.gameRestartTitle,
          body: l.gameRestartBody,
          confirm: l.gameRestartConfirm,
        );
      },
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
      useSafeArea: false,
      builder: (dctx) {
        final l = AppLocalizations.of(dctx);
        return _ConfirmDialog(
          title: l.gameLeaveTitle,
          body: l.gameLeaveBody,
          confirm: l.gameLeaveConfirm,
        );
      },
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  void _refill({required bool viaAd}) {
    void grant() {
      _game.refillHearts();
      setState(() => _result = _Result.none);
    }

    if (!viaAd) {
      Progress.instance.useRefillCoupon();
      grant();
    } else {
      Ads.showRewarded(onReward: grant, onUnavailable: grant);
    }
  }

  @override
  void dispose() {
    _coachTimer?.cancel();
    _hearts.dispose();
    _autoZoomCtrl?.dispose();
    _boardTc.removeListener(_clampBoard);
    _boardTc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    _game.palette = c;
    // Phase 5: on an entrance-sequence entry the top/bottom bars start
    // off-screen and slide in once [_chromeIn] flips (when the arrows begin).
    // On a plain entry they render in place, untouched.
    final diving = _entranceSequence;
    Widget chrome(Widget child, {required bool top}) => !diving
        ? child
        : AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            offset: _chromeIn ? Offset.zero : Offset(0, top ? -1 : 1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 380),
              opacity: _chromeIn ? 1 : 0,
              child: child,
            ),
          );
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
      body: Stack(
        children: [
        SafeArea(
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
                // board — see AtlasArrowsGame.maxZoom.
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
                chrome(
                  top: true,
                  ColoredBox(
                  color: c.bg,
                  child: Column(
                    children: [
                      _Header(
                        city: _cityLabel,
                        country: _countryName,
                        flagIso: _flagIso,
                        onBack: _maybeLeave,
                      ),
                      Container(height: 1, color: c.line),
                    ],
                  ),
                ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Empty probe: it measures the visible play area, which
                      // is what the board is fitted to and what the pan clamp
                      // measures against. Hit-tests through to the board.
                      SizedBox.expand(key: _playAreaKey),
                      // Dev cheat, armed from Settings. Clears the stage by
                      // the same path a real clear takes, so the reveal, the
                      // unlock and the ad cadence all behave normally.
                      if (_result == _Result.none)
                        ValueListenableBuilder<bool>(
                          valueListenable: Progress.instance.cheatOn,
                          builder: (context, on, _) => !on
                              ? const SizedBox.shrink()
                              : Positioned(
                                  right: 12,
                                  top: 8,
                                  child: Pressable(
                                    onTap: () => setState(
                                        () => _result = _Result.cleared),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: c.danger,
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                      ),
                                      child: Text('CLEAR',
                                          style: AppText.label.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                        ),
                      // Floats rather than taking a band of the Column: the
                      // translucent plate lets the board show through. The
                      // header now carries the place name + flag, so this spot
                      // holds the hearts. On a dive entry it holds until the
                      // chrome arrives, so it doesn't flash over the raining
                      // board.
                      if (_result != _Result.cleared && (!diving || _chromeIn))
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: _HeartsPlate(hearts: _hearts),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                chrome(
                  top: false,
                  ColoredBox(
                  color: c.bg,
                  child: Column(
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
                ),
              ],
            ),
            // Coach cue, above the board but below every modal surface.
            if (_coachEnabled && _result == _Result.none && !_showIntro)
              ValueListenableBuilder<bool>(
                valueListenable: Progress.instance.coachDone,
                builder: (context, done, _) => !done
                    ? _CoachCue(AppLocalizations.of(context).coachTapArrow,
                        icon: Icons.touch_app_outlined)
                    // A board too large to tap at fit scale is the one case
                    // where the player has to be told about the gesture.
                    : ValueListenableBuilder<bool>(
                        valueListenable: _game.needsZoom,
                        builder: (context, needed, _) => needed
                            ? _CoachCue(
                                AppLocalizations.of(context).coachPinchZoom,
                                icon: Icons.pinch_outlined)
                            : const SizedBox.shrink(),
                      ),
              ),
            // Clear is now the in-place reveal above; only the fail sheet
            // (hearts refill) remains a modal surface over the board.
            if (_result == _Result.failed)
              _ResultSheet(
                onRestart: _restart,
                onRefill: _refill,
              ),
            // On clear the chrome is covered by a full-screen arrival card: the
            // place's flag + name rise in, a visa stamp lands, then Continue.
            if (_result == _Result.cleared)
              _ClearArrival(
                key: ValueKey(_stage),
                city: _cityLabel,
                country: _countryName,
                flagIso: _flagIso,
                stampRank: _countryRank,
                onContinue: _next,
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
        // Phase 2–3a: the sky-dive overlay sits over everything until it lands.
        if (_diving && widget.dive != null)
          DiveLayer(args: widget.dive!, onDone: _onDiveDone),
        // Phase 3: the place's name + flag, centred on the blank screen.
        if (_titleCard)
          Positioned.fill(
            child: _IntroTitleCard(
              title: _cityLabel.isNotEmpty ? _cityLabel : _countryName,
              sub: _cityLabel.isNotEmpty ? _countryName : '',
              flagIso: _flagIso,
              onDone: _onTitleDone,
            ),
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
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Positioned.fill(
      child: Container(
        color: c.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.roundBadge(round.toString().padLeft(2, '0')),
                    style: AppText.label.copyWith(
                        color: c.accent, letterSpacing: 4)),
                const SizedBox(height: 12),
                Text(country.nameFor(lang),
                    style: AppText.display.copyWith(
                        color: c.ink, fontWeight: FontWeight.w700, height: 1.05)),
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
                          ? l.roundTeaches(country.teaches)
                          : country.cityCount > 0
                              ? l.roundCitiesIntro(
                                  country.nameFor(lang), country.cityCount)
                              : l.roundSingleIntro(country.nameFor(lang));
                      return Text(
                        blurb.isNotEmpty ? blurb : fallback,
                        style: AppText.body.copyWith(
                            color: c.inkSoft, height: 1.55),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stat(c, '${country.stageCount}', l.roundStatStages),
                    _stat(c, '${country.cityCount}', l.roundStatCities),
                    _stat(c, '1', l.roundStatCountry),
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
                    child: Text(l.roundStart,
                        style: AppText.headline.copyWith(
                            color: c.onAccent, fontWeight: FontWeight.w700)),
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
                      color: c.ink, fontWeight: FontWeight.w700, fontSize: 26)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption.copyWith(
                      color: c.inkFaint, letterSpacing: 1.5)),
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
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 1px hairline so a flag with white at its edge (Japan, etc.) still reads
    // as a distinct chip on the paper ground.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.line, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CountryFlag.fromCountryCode(
          iso,
          theme: ImageTheme(width: height * 4 / 3, height: height),
        ),
      ),
    );
  }
}

/// Back on the left; the place name centred (city over its country when the
/// board is a city, the country alone on a finale); the country flag on the
/// right where the hearts used to sit. Two lines make it taller than a bare
/// stage number, which is why the hearts moved down onto the board.
///
/// A Stack, not a Row: the name has to sit on the screen's centre line, and in
/// a Row the back button and the flag would have to weigh the same for that to
/// hold — they don't.
class _Header extends StatelessWidget {
  const _Header({
    required this.city,
    required this.country,
    required this.flagIso,
    required this.onBack,
  });

  final String city, country, flagIso;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: city.isEmpty ? 60 : 76,
      child: Stack(
        children: [
          Center(
            child: Padding(
              // Clear the back button and the flag so a long name never runs
              // under them.
              padding: const EdgeInsets.symmetric(horizontal: 58),
              child: _PlaceName(city: city, country: country),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: onBack,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Icon(Icons.arrow_back, color: c.inkFaint, size: 24),
              ),
            ),
          ),
          if (flagIso.length == 2)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _FlagImg(iso: flagIso, height: 26),
              ),
            ),
        ],
      ),
    );
  }
}

/// The centred place name. A city board reads city-over-country: the city in
/// the old stage-label style, the country under it at 90% and one weight
/// lighter, 5px apart. A finale board shows the country name alone.
class _PlaceName extends StatelessWidget {
  const _PlaceName({required this.city, required this.country});
  final String city, country;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nameStyle = AppText.headline
        .copyWith(color: c.ink, fontWeight: FontWeight.w700, height: 1.0);
    if (city.isEmpty) {
      return Text(country,
          style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(city,
            style: nameStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 5),
        Text(country,
            style: nameStyle.copyWith(
                color: c.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: (AppText.headline.fontSize ?? 18) * 0.9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
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
              padding: const EdgeInsets.symmetric(vertical: kPopupButtonPadV),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: outline ? Border.all(color: c.line, width: 1.5) : null,
              ),
              child: Text(label, style: kButtonText.copyWith(color: fg)),
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
                style: AppText.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: 20),
            Row(
              children: [
                button(AppLocalizations.of(context).cancel,
                    Colors.transparent, c.inkSoft, false,
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

/// The hearts, sized to sit inside the header rather than on a strip of their
/// own. Rebuilds on its own notifier so spending one doesn't rebuild the board.
class _Hearts extends StatelessWidget {
  const _Hearts({required this.hearts});
  final ValueNotifier<int> hearts;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: hearts,
      builder: (context, h, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < AtlasArrowsGame.maxHearts; i++)
            Padding(
              padding: const EdgeInsets.only(left: 5),
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
    );
  }

  static const _grayscale = <double>[
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// The hearts, floating just under the header on a translucent plate so the
/// board reads through it. They used to sit in the header, but the place name
/// and flag took that room, so they moved onto the board here.
class _HeartsPlate extends StatelessWidget {
  const _HeartsPlate({required this.hearts});
  final ValueNotifier<int> hearts;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.line.withValues(alpha: 0.6)),
      ),
      child: _Hearts(hearts: hearts),
    );
  }
}

/// Phase 3 of the dive-in: on the blank screen right after touchdown, the
/// place's name and flag hold in the centre for a beat, then fade — a title
/// card before the board assembles. Rises in on an ease-out, holds ~1.3s, then
/// fades out and hands off to the board reveal.
class _IntroTitleCard extends StatefulWidget {
  const _IntroTitleCard({
    required this.title,
    required this.sub,
    required this.flagIso,
    required this.onDone,
  });
  final String title, sub, flagIso;
  final VoidCallback onDone;

  @override
  State<_IntroTitleCard> createState() => _IntroTitleCardState();
}

class _IntroTitleCardState extends State<_IntroTitleCard>
    with SingleTickerProviderStateMixin {
  static const int _inMs = 260, _holdMs = 1300, _outMs = 360;
  static const int _total = _inMs + _holdMs + _outMs;

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _total));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _opacity {
    final ms = _c.value * _total;
    if (ms < _inMs) return Curves.easeOut.transform(ms / _inMs);
    if (ms < _inMs + _holdMs) return 1;
    return 1 - Curves.easeIn.transform((ms - _inMs - _holdMs) / _outMs);
  }

  /// A few px of upward travel on entry only — the exit is a pure fade.
  double get _rise {
    final ms = _c.value * _total;
    return ms < _inMs ? 10 * (1 - Curves.easeOut.transform(ms / _inMs)) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
          opacity: _opacity,
          child: Transform.translate(offset: Offset(0, _rise), child: child),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.flagIso.length == 2) ...[
                  _FlagImg(iso: widget.flagIso, height: 40),
                  const SizedBox(height: 16),
                ],
                Text(widget.title,
                    textAlign: TextAlign.center,
                    style: AppText.display.copyWith(
                        color: c.ink, fontWeight: FontWeight.w700, height: 1.05)),
                if (widget.sub.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.sub,
                      textAlign: TextAlign.center,
                      style: AppText.label.copyWith(color: c.inkSoft)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four play controls — fit-view, hint, remove, restart — spread evenly
/// across the width, each centred in its own equal quarter.
class _BoosterBar extends StatelessWidget {
  const _BoosterBar(
      {required this.game, required this.onResetView, required this.onRestart});
  final AtlasArrowsGame game;
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
    final l = AppLocalizations.of(context);
    return Padding(
      // Bottom padding is the gap to the ad banner: three times the top, so
      // the controls read as part of the board rather than as part of the ad.
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      // Four controls spread evenly across the width: each takes an equal
      // quarter and centres its tile inside it, so they read as one balanced
      // row regardless of the tiles' differing widths or the counters.
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: _UtilButton(
                icon: Icons.center_focus_strong_outlined,
                label: l.barFit,
                onTap: onResetView,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: Progress.instance.hints,
                builder: (context, n, _) => _BoosterButton(
                  icon: 'assets/images/icons/hint.png',
                  label: l.barHint,
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
            ),
          ),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: game.removeArmed,
                builder: (context, armed, _) => ValueListenableBuilder<int>(
                  valueListenable: Progress.instance.removes,
                  builder: (context, n, _) => _BoosterButton(
                    icon: 'assets/images/icons/remove.png',
                    label: l.barRemove,
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
            ),
          ),
          Expanded(
            child: Center(
              child: _UtilButton(
                icon: Icons.refresh,
                label: l.barRestart,
                onTap: onRestart,
              ),
            ),
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
        width: 60,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: c.inkSoft),
            const SizedBox(height: 2),
            // One line, scaled to fit — a translated label (e.g. German "fit
            // view") is far wider than this compact tile and must not wrap.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.caption.copyWith(
                      color: c.inkSoft,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      fontSize: 16)),
            ),
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
        width: 69,
        height: 60,
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
                  Image.asset(icon, width: 29, height: 29),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        softWrap: false,
                        style: AppText.caption.copyWith(
                            color: c.inkSoft,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            fontSize: 16)),
                  ),
                ],
              ),
            ),
            // Sized off the digit inside it, not the other way round.
            Positioned(
              top: -9,
              right: -9,
              child: Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  // Two different jobs, so two different weights: a stock count
                  // is metadata and stays quiet, while '+' is an offer to buy
                  // and earns the accent. Full-strength ink here would outrank
                  // the item icon it belongs to.
                  color: count > 0 ? c.inkSoft : c.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Text(count > 0 ? '$count' : '+',
                    style: AppText.caption.copyWith(
                        color: c.bg, fontWeight: FontWeight.w700, height: 1)),
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
/// The out-of-hearts sheet: a top MREC over a bottom card offering a refill
/// (free coupon, then ads) or a restart. Clear no longer uses this — see
/// [_ClearArrival].
class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.onRestart,
    required this.onRefill,
  });
  final VoidCallback onRestart;
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
    final sheet = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: _fail(c),
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

  Widget _fail(AppColors c) => ValueListenableBuilder<int>(
        valueListenable: Progress.instance.refillCoupons,
        builder: (context, coupons, _) {
          final free = coupons > 0;
          final l = AppLocalizations.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.heartsOutTitle,
                  style: AppText.title.copyWith(
                      color: c.ink, fontWeight: FontWeight.w700, fontSize: 22)),
              const SizedBox(height: 12),
              Text(free ? l.heartsOutFree : l.heartsOutAd,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: c.inkSoft)),
              const SizedBox(height: 16),
              // Both states are the primary action on this sheet, so both get
              // the full accent. Accent-soft made the ad path look like the
              // secondary option when by then it is the only one.
              _bigButton(
                c,
                free ? l.refillCoupon(coupons) : l.refillViaAd,
                c.accent,
                c.onAccent,
                () => widget.onRefill(viaAd: !free),
                icon: free ? 'assets/images/icons/heart.png' : null,
              ),
              const SizedBox(height: 10),
              _bigButton(c, l.gameRestartConfirm, Colors.transparent,
                  c.inkFaint, widget.onRestart,
                  outline: true),
            ],
          );
        },
      );

  Widget _bigButton(AppColors c, String label, Color bg, Color fg,
          VoidCallback onTap,
          {bool outline = false, String? icon}) =>
      Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: kPopupButtonPadV),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: outline ? Border.all(color: c.line, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Image.asset(icon, width: 22, height: 22),
                const SizedBox(width: 8),
              ],
              Text(label, style: kButtonText.copyWith(color: fg)),
            ],
          ),
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
          ..showSnackBar(SnackBar(
              content:
                  Text(AppLocalizations.of(context).toastNoAdAvailable)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
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
          Text(widget.forHint ? l.itemSheetNoHints : l.itemSheetNoRemoves,
              style: AppText.title.copyWith(
                  color: c.ink, fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: 4),
          Text(l.itemSheetRefill,
              style: AppText.body.copyWith(color: c.inkSoft)),
          const SizedBox(height: 18),
          // Prices and disabled states track the store, so rebuild on both.
          ValueListenableBuilder<List<ProductDetails>>(
            valueListenable: _iap.products,
            builder: (context, _, _) => ValueListenableBuilder<bool>(
              valueListenable: _iap.busy,
              builder: (context, busy, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: _rows(c, busy, l),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(AppColors c, bool busy, AppLocalizations l) {
    // The free ad only ever grants a hint, so it travels with the hint bundles.
    final ad = _row(
      c,
      icon: 'assets/images/icons/hint.png',
      label: l.shopWatchAdForHint,
      trailing: _watchingAd ? l.adPlaying : l.free,
      tint: c.success,
      enabled: !_watchingAd,
      onTap: _watchAdForHint,
    );
    final hints = [
      ad,
      for (final id in IapService.hintProducts.keys)
        _productRow(c, id, 'assets/images/icons/hint.png',
            l.hintsBundle(IapService.hintProducts[id]!), busy, l),
    ];
    final removes = [
      for (final id in IapService.removeProducts.keys)
        _productRow(c, id, 'assets/images/icons/remove.png',
            l.removesBundle(IapService.removeProducts[id]!), busy, l),
    ];
    // Lead with whichever item ran out.
    return widget.forHint ? [...hints, ...removes] : [...removes, ...hints];
  }

  Widget _productRow(AppColors c, String id, String icon, String label,
      bool busy, AppLocalizations l) {
    final product = _iap.productFor(id);
    return _row(
      c,
      icon: icon,
      label: label,
      // Store's localized price when registered, coming-soon until then.
      trailing: product?.price ?? l.comingSoon,
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
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.55, child: tile);
    }
    return Pressable(onTap: onTap, child: tile);
  }
}

/// The clear moment, covering the chrome like a passport page: the place's
/// flag and name rise in one by one, its visa stamp thumps down, then a
/// Continue button. Freezes to the finished frame under OS reduce-motion.
class _ClearArrival extends StatefulWidget {
  const _ClearArrival({
    super.key,
    required this.city,
    required this.country,
    required this.flagIso,
    required this.stampRank,
    required this.onContinue,
  });
  final String city;
  final String country;
  final String flagIso;
  final int stampRank;
  final VoidCallback onContinue;

  @override
  State<_ClearArrival> createState() => _ClearArrivalState();
}

class _ClearArrivalState extends State<_ClearArrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2100));
  bool _thumped = false;

  // The stamp's slot in the timeline; the impact haptic fires partway into it.
  static const _stampAt = 0.50, _stampDur = 0.22;

  @override
  void initState() {
    super.initState();
    // Fetch this country's stamp art for next time if it isn't on disk yet.
    if (StampStore.instance.fileFor(widget.stampRank) == null) {
      StampStore.instance.ensurePackFor(widget.stampRank);
    }
    _c.addListener(_maybeThump);
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

  void _maybeThump() {
    if (!_thumped && _c.value >= _stampAt + _stampDur * 0.5) {
      _thumped = true;
      if (Progress.instance.hapticsOn.value) HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_maybeThump);
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b) =>
      Curves.easeOut.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final hasCity = widget.city.isNotEmpty;

    return Positioned.fill(
      child: ColoredBox(
        color: c.bg,
        // top inset is already handled by the play screen's SafeArea; keep the
        // bottom one so Continue clears the gesture bar.
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final flagT = _seg(0.0, 0.18);
              final cityT = hasCity ? _seg(0.18, 0.34) : 1.0;
              final countryT = _seg(hasCity ? 0.30 : 0.18, 0.46);
              final stampP =
                  ((_c.value - _stampAt) / _stampDur).clamp(0.0, 1.0);
              final contT = _seg(0.78, 1.0);
              // Stamp reads at 336 on a 390pt-wide reference phone; scale
              // proportionally to screen width elsewhere so it can't outgrow
              // the space this card actually has, clamped so it neither
              // vanishes on tiny screens nor dominates on tablets.
              final stampSize =
                  (MediaQuery.sizeOf(context).width * 336 / 390)
                      .clamp(200.0, 340.0);
              return Column(
                children: [
                  // Top half: the place's flag over its city + country, centred.
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: flagT.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.5 +
                                  0.5 * Curves.easeOutBack.transform(flagT),
                              child: _FlagImg(iso: widget.flagIso, height: 96),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (hasCity) ...[
                            _rising(widget.city, cityT,
                                AppText.display.copyWith(
                                    color: c.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40,
                                    height: 1.05)),
                            const SizedBox(height: 8),
                            _rising(widget.country, countryT,
                                AppText.title.copyWith(
                                    color: c.inkSoft,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22)),
                          ] else
                            _rising(widget.country, countryT,
                                AppText.display.copyWith(
                                    color: c.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 40,
                                    height: 1.05)),
                        ],
                      ),
                    ),
                  ),
                  // Bottom half: the visa stamp thumps down in the free space
                  // above the Continue button, which is pinned to the bottom.
                  // Clipped to this half so the stamp's scale-up bounce can
                  // never paint over the flag/city/country half above it.
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRect(
                            child: Center(
                              child: stampP <= 0
                                  ? const SizedBox.shrink()
                                  : Transform.rotate(
                                      angle: -0.05,
                                      child: Opacity(
                                        opacity:
                                            (stampP * 2.5).clamp(0.0, 1.0),
                                        child: Transform.scale(
                                          scale: 1.45 -
                                              0.45 *
                                                  Curves.easeOutBack
                                                      .transform(stampP),
                                          child: _StampMark(
                                              rank: widget.stampRank,
                                              size: stampSize),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: contT,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - contT)),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: IgnorePointer(
                                ignoring: contT < 1,
                                child: Pressable(
                                  onTap: widget.onContinue,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: kButtonPadV),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: c.accent,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill),
                                    ),
                                    child: Text(l.clearContinue,
                                        style: kButtonText.copyWith(
                                            color: c.onAccent)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _rising(String text, double t, TextStyle style) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  Text(text, textAlign: TextAlign.center, style: style),
            ),
          ),
        ),
      );
}

/// The country's visa stamp (date-less by design). Shows the fetched art when
/// it is on disk; until then a plain "VISITED" ring stands in, and it swaps to
/// the real stamp the moment its continent pack lands.
class _StampMark extends StatelessWidget {
  const _StampMark({required this.rank, required this.size});
  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: StampStore.instance.revision,
      builder: (context, _, _) {
        final File? file = StampStore.instance.fileFor(rank);
        if (file != null) {
          return Image.file(file, width: size, height: size, fit: BoxFit.contain);
        }
        return Container(
          width: size * 0.82,
          height: size * 0.82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.accent.withValues(alpha: 0.85), width: 3),
          ),
          child: Text('VISITED',
              style: AppText.label.copyWith(
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        );
      },
    );
  }
}
