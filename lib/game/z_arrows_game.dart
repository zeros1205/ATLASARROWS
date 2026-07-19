import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
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
class ZArrowsGame extends FlameGame {
  ZArrowsGame({
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

  @override
  Color backgroundColor() => palette.bg;

  @override
  Future<void> onLoad() async {
    await Sfx.preload();
    loadLevel(initialLevel);
  }

  void loadLevel(Level level) {
    _current = level;
    hearts = maxHearts;
    _inputLocked = false;
    _combo = 0;
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

  void _layoutBoard(Vector2 canvas) {
    final board = _board!;
    final s = math.min(
      canvas.x * 0.94 / board.size.x,
      canvas.y * 0.94 / board.size.y,
    );
    board.scale = Vector2.all(s);
    board.position = Vector2(canvas.x / 2, canvas.y / 2);
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
    if (_combo >= 2) _showComboText(lineComponent);
    if (_combo >= 3) _zoomPunch();
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
    lineComponent.bump(freeSteps, onImpact: () {
      Sfx.block();
      _board?.lineById(blockerId)?.flashRed();
      _shake();
      hearts = math.max(0, hearts - 1);
      onHeartsChanged?.call(hearts);
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

  void _zoomPunch() {
    _board?.add(ScaleEffect.by(
      Vector2.all(1.02),
      EffectController(duration: 0.06, reverseDuration: 0.14, curve: Curves.easeOut),
    ));
  }

  void _shake() {
    _board?.add(SequenceEffect([
      MoveByEffect(Vector2(10, 0), EffectController(duration: 0.04)),
      MoveByEffect(Vector2(-16, 0), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(8, 0), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(-2, 0), EffectController(duration: 0.06)),
    ]));
  }

  void _showComboText(LineComponent lineComponent) {
    final board = _board;
    if (board == null) return;
    final (r, c) = lineComponent.line.head;
    final text = TextComponent(
      text: 'x$_combo',
      position: Vector2(c * BoardComponent.cell + BoardComponent.cell / 2,
          r * BoardComponent.cell - 8),
      anchor: Anchor.bottomCenter,
      priority: 200,
      textRenderer: TextPaint(
        style: TextStyle(
          color: palette.accent,
          fontSize: 52,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
        ),
      ),
    );
    board.add(text);
    text.add(MoveByEffect(Vector2(0, -70),
        EffectController(duration: 0.75, curve: Curves.easeOutCubic)));
    text.add(RemoveEffect(delay: 0.75));
  }
}
