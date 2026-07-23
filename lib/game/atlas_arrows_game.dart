import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../app/tokens/colors.dart';
import '../models/level.dart';
import 'board_component.dart';
import 'board_logic.dart';
import 'line_component.dart';
import 'sfx.dart';

/// The Flame game for one stage. Level-agnostic: it plays whatever [Level]
/// it is given and reports outcomes via callbacks; the surrounding Flutter
/// screen owns stage progression, hearts UI and result sheets.
class AtlasArrowsGame extends FlameGame {
  AtlasArrowsGame({
    required this.initialLevel,
    required this.palette,
    this.onCleared,
    this.onHeartsChanged,
    this.onFailed,
    this.onEscaped,
    this.onRemoveUsed,
    this.onIntroArrows,
    this.onIntroDone,
    this.introOnLoad = false,
  });

  static const int maxHearts = 3;
  static const comboWindow = Duration(seconds: 5);

  Level initialLevel;
  AppColors palette;

  final VoidCallback? onCleared;
  final VoidCallback? onFailed;

  /// Fired the moment a line successfully leaves the board. The screen uses it
  /// to retire the first-stage coach once the player has done it themselves.
  final VoidCallback? onEscaped;

  /// Fired when an armed remove actually strikes a line — the screen debits
  /// the player's inventory here, not when the item is armed (arming is
  /// free and cancellable).
  final VoidCallback? onRemoveUsed;
  final void Function(int hearts)? onHeartsChanged;

  /// Fired the moment the board intro moves from raining dots to filling in the
  /// arrows — the screen slides its top/bottom chrome in on this. And when the
  /// whole intro finishes and input unlocks.
  final VoidCallback? onIntroArrows;
  final VoidCallback? onIntroDone;

  /// When true, the first level plays the entrance intro (dots rain in, then
  /// arrows fill) instead of appearing whole. Later levels always appear whole.
  final bool introOnLoad;

  // Intro reveal progress, both 0 (nothing shown) → 1 (fully shown). Default 1
  // so a normal load draws the finished board; [beginIntro] drives them from 0.
  // The board dots stagger on [introDots]; the arrows on [introArrows].
  double introDots = 1, introArrows = 1;
  bool _introActive = false;
  bool _arrowsFired = false;
  double _introClock = 0;

  int hearts = maxHearts;

  /// True while the remove item is armed — the next tapped line is vaporized.
  final ValueNotifier<bool> removeArmed = ValueNotifier(false);

  late BoardLogic logic;
  late Level _current;
  BoardComponent? _board;
  bool _inputLocked = false;
  int _combo = 0;
  DateTime _lastEscapeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Heart used by the "-1" float on a blocked tap; loaded once in [onLoad].
  Sprite? _heartSprite;

  @override
  Color backgroundColor() => palette.bg;

  @override
  Future<void> onLoad() async {
    await Sfx.preload();
    _heartSprite = await Sprite.load('icons/heart.png');
    loadLevel(initialLevel, intro: introOnLoad);
  }

  void loadLevel(Level level, {bool intro = false}) {
    _current = level;
    hearts = maxHearts;
    // An intro keeps the board hidden and input locked until [beginIntro] runs;
    // a normal load shows it whole and plays immediately.
    introDots = intro ? 0 : 1;
    introArrows = intro ? 0 : 1;
    _introActive = false;
    _arrowsFired = false;
    _inputLocked = intro;
    _combo = 0;
    Sfx.pickStageVoice();
    removeArmed.value = false;
    logic = BoardLogic.fromLevel(level);
    _board?.removeFromParent();
    final board = BoardComponent(level: level)..anchor = Anchor.center;
    _board = board;
    add(board);
    if (size.x > 0) _layoutBoard(size);
    onHeartsChanged?.call(hearts);
  }

  void restartLevel() => loadLevel(_current);

  /// Starts the entrance reveal: the board dots rain in, then the arrows fill
  /// over them, then input unlocks. Called by the screen once the sky-dive
  /// overlay has touched down. No-op unless the level was loaded with intro on.
  void beginIntro() {
    if (introDots >= 1) return;
    _introActive = true;
    _arrowsFired = false;
    _introClock = 0;
  }

  // Reveal timing (seconds): dots rain over [_dotsDur]; the arrows start a hair
  // before the last dots land ([_arrowsAt]) and fill over [_arrowsDur].
  static const double _dotsDur = 0.72;
  static const double _arrowsAt = 0.58;
  static const double _arrowsDur = 0.62;

  /// Refills hearts to full and unlocks input (heart-economy continue).
  void refillHearts() {
    hearts = maxHearts;
    _inputLocked = false;
    onHeartsChanged?.call(hearts);
  }

  /// Highlights one currently-escapable line (hint item). Returns false when
  /// none exists or input is locked.
  bool showHint() {
    if (_inputLocked) return false;
    for (final id in logic.lines.keys) {
      if (logic.tap(id) is MoveEscaped) {
        final lc = _board?.lineById(id);
        if (lc != null && !lc.animating) {
          lc.flashHint();
          return true;
        }
      }
    }
    return false;
  }

  void armRemove() {
    if (_inputLocked) return;
    removeArmed.value = !removeArmed.value;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_introActive) return;
    _introClock += dt;
    introDots = (_introClock / _dotsDur).clamp(0.0, 1.0);
    introArrows = ((_introClock - _arrowsAt) / _arrowsDur).clamp(0.0, 1.0);
    if (!_arrowsFired && _introClock >= _arrowsAt) {
      _arrowsFired = true;
      onIntroArrows?.call();
    }
    if (introDots >= 1 && introArrows >= 1) {
      _introActive = false;
      _inputLocked = false;
      onIntroDone?.call();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_board != null) _layoutBoard(size);
  }

  /// Scale at which the whole board is visible.
  double _fitScale = 1;

  /// Breathing room around the board, in logical pixels — a fixed margin
  /// rather than a share of the screen, so the board doesn't lose more room
  /// the bigger the phone gets. Only the tighter of the two binds: whichever
  /// axis runs out first sets the scale, and the other one keeps its leftover
  /// as letterbox.
  ///
  /// Note the arrows stop short of the board rectangle by roughly a stroke
  /// width, so the margin the player *sees* runs ~8 device px wider than this
  /// on a 3.75x phone. Sized so the board opens at ~0.9 of the width it would
  /// fill edge to edge — a board pressed against the screen sides reads as
  /// cramped, and the zoom is there for anyone who wants it bigger.
  static const double _marginX = 22, _marginY = 27;

  /// Smallest on-screen cell we consider tappable, in logical pixels. Well
  /// under the 44pt guideline — a full-screen country silhouette simply cannot
  /// reach that — but far enough above the ~3px a 138-column board would get
  /// that zooming in stays a choice rather than a requirement.
  static const double _minTappableCell = 26;

  /// True when the board is too large to be both fully visible and tappable,
  /// so the player has to zoom. A notifier rather than a getter because it is
  /// only known once the board has been laid out, which happens after the
  /// surrounding widget first builds — reading it directly always said false.
  final ValueNotifier<bool> needsZoom = ValueNotifier(false);

  /// On-screen cell size the deepest zoom aims for, in logical pixels. Just
  /// over the 44pt tap guideline, which puts ~8 columns on a phone — past that
  /// you are reading one arrow at a time and lose the shape entirely.
  static const double _zoomedCell = 48;

  /// Never less than this, so a board that already fits comfortably can still
  /// be zoomed a little, and never more, so the 138-column boards don't turn
  /// into a 30-pinch expedition.
  static const double _minMaxZoom = 2;
  static const double _maxMaxZoom = 16;

  /// How far past fit this board may be zoomed. Derived from the board rather
  /// than fixed: fit puts a cell anywhere from ~2.6dp (138 columns) to ~9.8dp
  /// (27 columns) on screen, so one constant is either too tight to reach a
  /// tappable cell on the big boards or absurdly deep on the small ones.
  final ValueNotifier<double> maxZoom = ValueNotifier(_maxMaxZoom);

  /// Height of the chrome painted over the top and bottom of the canvas. The
  /// canvas is the whole screen so an escaping arrow can fly right off it and
  /// slide under the header, but the board must still be fitted and centred in
  /// the gap the player can actually see.
  double _insetTop = 0, _insetBottom = 0;

  void setPlayInsets(double top, double bottom) {
    if (top == _insetTop && bottom == _insetBottom) return;
    _insetTop = top;
    _insetBottom = bottom;
    if (_board != null) _layoutBoard(size);
  }

  void _layoutBoard(Vector2 canvas) {
    final board = _board!;
    final playHeight =
        math.max(canvas.y - _insetTop - _insetBottom, canvas.y * 0.2);
    _fitScale = math.min(
      math.max(canvas.x - _marginX * 2, canvas.x * 0.5) / board.size.x,
      math.max(playHeight - _marginY * 2, playHeight * 0.5) / board.size.y,
    );
    final fitCell = _fitScale * BoardComponent.cell;
    needsZoom.value = fitCell < _minTappableCell;
    maxZoom.value =
        (_zoomedCell / fitCell).clamp(_minMaxZoom, _maxMaxZoom).toDouble();
    // Open on the whole silhouette: recognising the country is the point of
    // the board, and zoom is one pinch away.
    board.scale = Vector2.all(_fitScale);
    board.position =
        Vector2(canvas.x / 2, _insetTop + playHeight / 2);
  }

  /// The pan/zoom the Flutter layer applies on top of this canvas. Needed
  /// because an escaping line has to leave the *screen*, and once the board is
  /// panned the canvas edge is no longer the screen edge — it can sit right in
  /// the middle of the view, which is where arrows appeared to vanish.
  double _viewScale = 1, _viewTx = 0, _viewTy = 0;

  void setView(double scale, double tx, double ty) {
    _viewScale = scale;
    _viewTx = tx;
    _viewTy = ty;
  }

  /// The part of the canvas the player can actually see, in canvas coordinates.
  Rect get visibleRect => Rect.fromLTRB(
        -_viewTx / _viewScale,
        -_viewTy / _viewScale,
        (size.x - _viewTx) / _viewScale,
        (size.y - _viewTy) / _viewScale,
      );

  /// The grid's footprint in canvas coordinates (GameWidget-local), i.e. the
  /// board's intrinsic size under the fit scale, centred. Null until the board
  /// has been laid out. The pan clamp needs this rather than the canvas: the
  /// 0.94 margin and the letterbox on the shorter axis inset the grid well
  /// inside the canvas, so clamping on canvas edges lets the grid slide far
  /// past the centre line.
  Rect? get boardRect {
    final board = _board;
    if (board == null) return null;
    return Rect.fromCenter(
      center: Offset(board.position.x, board.position.y),
      width: board.size.x * _fitScale,
      height: board.size.y * _fitScale,
    );
  }

  /// Silhouette-cell counts per board quadrant, keyed by the (signX, signY) the
  /// entrance dive uses: signX +1 = right half, -1 = left; signY -1 = top half
  /// (smaller row), +1 = bottom. Lets the entrance zoom weight its target by
  /// where the country actually is, so a diagonally-long silhouette never dives
  /// into an empty off-diagonal corner. Empty until a board is laid out.
  Map<(int, int), int> quadrantCellCounts() {
    final board = _board;
    if (board == null) return const {};
    final level = board.level;
    final cx = level.cols / 2, cy = level.rows / 2;
    final counts = <(int, int), int>{};
    for (final (r, c) in level.mask) {
      final key = (c >= cx ? 1 : -1, r < cy ? -1 : 1);
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Fire the line under a point given in this game's canvas coordinates
  /// (GameWidget-local, i.e. after the pan/zoom transform has been undone but
  /// before the board's own centre-anchored fit scale). Tap detection lives in
  /// the Flutter layer now — it hands us the point and we pick the nearest line.
  void tapAtScene(double sx, double sy) {
    final board = _board;
    if (board == null || _inputLocked) return;
    final local = (Vector2(sx, sy) - board.position) / _fitScale + board.size / 2;
    LineComponent? nearest;
    var bestD = double.infinity;
    for (final lc in board.children.whereType<LineComponent>()) {
      final d = lc.distanceToPoint(local);
      if (d < bestD) {
        bestD = d;
        nearest = lc;
      }
    }
    // A generous tap band (~half a cell) — the visible shaft is only 0.2 cell,
    // so aim tolerance, not the ink, defines what is tappable.
    if (nearest != null && bestD < BoardComponent.cell * 0.5) {
      handleTap(nearest);
    }
  }

  void handleTap(LineComponent lineComponent) {
    if (_inputLocked || lineComponent.animating) return;
    if (removeArmed.value) {
      _removeStrike(lineComponent);
      return;
    }
    switch (logic.tap(lineComponent.line.id)) {
      case MoveEscaped():
        _onEscape(lineComponent);
      case MoveBlocked(:final freeSteps, :final blockerId):
        _onBlocked(lineComponent, freeSteps, blockerId);
    }
  }

  /// Remove item: strike the line with lightning — it vanishes regardless of
  /// whether it was blocked.
  void _removeStrike(LineComponent lineComponent) {
    removeArmed.value = false;
    Sfx.pop(0);
    onRemoveUsed?.call();
    logic.removeLine(lineComponent.line.id);
    lineComponent.vaporize(onGone: _checkCleared);
  }

  void _onEscape(LineComponent lineComponent) {
    final now = DateTime.now();
    if (now.difference(_lastEscapeAt) > comboWindow) _combo = 0;
    _lastEscapeAt = now;
    _combo++;
    Sfx.pop(_combo - 1);
    logic.removeLine(lineComponent.line.id);
    lineComponent.escape(onGone: _checkCleared);
    onEscaped?.call();
  }

  void _checkCleared() {
    if (!logic.isCleared) return;
    Sfx.clear();
    _inputLocked = true;
    add(TimerComponent(
      period: 0.3,
      removeOnFinish: true,
      onTick: () => onCleared?.call(),
    ));
  }

  void _onBlocked(LineComponent lineComponent, int freeSteps, int blockerId) {
    _combo = 0;
    // Where the arrowhead bumped into the blocker — the float starts here.
    final (hr, hc) = lineComponent.line.head;
    final dir = lineComponent.line.headDir;
    final impact = Vector2(
      (hc + 0.5 + dir.dx * (freeSteps + 0.3)) * BoardComponent.cell,
      (hr + 0.5 + dir.dy * (freeSteps + 0.3)) * BoardComponent.cell,
    );
    lineComponent.bump(freeSteps, onImpact: () {
      Sfx.block();
      _board?.lineById(blockerId)?.flashRed();
      _shake();
      hearts = math.max(0, hearts - 1);
      onHeartsChanged?.call(hearts);
      _showHeartLoss(impact);
      if (hearts == 0) {
        _inputLocked = true;
        Sfx.fail();
        add(TimerComponent(
          period: 0.5,
          removeOnFinish: true,
          onTick: () => onFailed?.call(),
        ));
      }
    });
  }

  void _shake() {
    _board?.add(SequenceEffect([
      MoveByEffect(Vector2(10, 0), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(-16, 0), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(8, 0), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(-2, 0), EffectController(duration: 0.06)),
    ]));
  }

  /// A "-1" and a heart lifting off the collision point and fading, so the lost
  /// heart is felt where the mistake happened, not only in the top strip.
  void _showHeartLoss(Vector2 at) {
    final board = _board;
    final sprite = _heartSprite;
    if (board == null || sprite == null) return;
    final group = PositionComponent(position: at, priority: 210);
    final heart = SpriteComponent(
      sprite: sprite,
      size: Vector2.all(BoardComponent.cell * 0.52),
      anchor: Anchor.center,
      position: Vector2(BoardComponent.cell * 0.30, 0),
    );
    final minus = TextComponent(
      text: '-1',
      anchor: Anchor.center,
      position: Vector2(-BoardComponent.cell * 0.18, 0),
      textRenderer: TextPaint(
        style: TextStyle(
          color: palette.danger,
          fontSize: 46,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
      ),
    );
    group.addAll([minus, heart]);
    board.add(group);
    group.add(MoveByEffect(Vector2(0, -BoardComponent.cell * 0.8),
        EffectController(duration: 0.7, curve: Curves.easeOutCubic)));
    heart.add(OpacityEffect.fadeOut(EffectController(duration: 0.7)));
    group.add(RemoveEffect(delay: 0.7));
  }
}
