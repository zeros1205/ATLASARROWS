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
    loadLevel(initialLevel);
  }

  void loadLevel(Level level) {
    _current = level;
    hearts = maxHearts;
    _inputLocked = false;
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
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_board != null) _layoutBoard(size);
  }

  /// Scale at which the whole board is visible.
  double _fitScale = 1;

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

  void _layoutBoard(Vector2 canvas) {
    final board = _board!;
    _fitScale = math.min(
      canvas.x * 0.94 / board.size.x,
      canvas.y * 0.94 / board.size.y,
    );
    needsZoom.value = _fitScale * BoardComponent.cell < _minTappableCell;
    // Open on the whole silhouette: recognising the country is the point of
    // the board, and zoom is one pinch away.
    board.scale = Vector2.all(_fitScale);
    board.position = Vector2(canvas.x / 2, canvas.y / 2);
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
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
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
