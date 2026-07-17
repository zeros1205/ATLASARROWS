import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/level_repository.dart';
import '../theme.dart';
import 'board_component.dart';
import 'board_logic.dart';
import 'line_component.dart';
import 'sfx.dart';

class ZArrowsGame extends FlameGame {
  ZArrowsGame({required this.repository, this.startAt = 0, this.onCleared});

  static const clearedOverlayKey = 'cleared';
  static const failedOverlayKey = 'failed';
  static const int maxHearts = 3;

  /// Escapes within this window chain into a combo (rising pop pitch).
  static const comboWindow = Duration(seconds: 5);

  final LevelRepository repository;
  final int startAt;

  /// Fired once per clear, before the overlay shows — progress/ads hook.
  final void Function(int levelIndex)? onCleared;

  final ValueNotifier<int> levelIndex = ValueNotifier(0);
  final ValueNotifier<int> hearts = ValueNotifier(maxHearts);

  late BoardLogic logic;
  BoardComponent? _board;
  bool _inputLocked = false;
  int _combo = 0;
  DateTime _lastEscapeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Color backgroundColor() => ZTheme.bg;

  @override
  Future<void> onLoad() async {
    await Sfx.preload();
    startLevel(startAt);
  }

  /// Highlights one currently-free line. Returns false when none exists
  /// (only possible mid-animation) or input is locked.
  bool showHint() {
    if (_inputLocked) return false;
    for (final id in logic.lines.keys) {
      if (logic.tap(id) is MoveEscaped) {
        final lineComponent = _board?.lineById(id);
        if (lineComponent != null && !lineComponent.animating) {
          lineComponent.flashHint();
          return true;
        }
      }
    }
    return false;
  }

  void startLevel(int index) {
    levelIndex.value = index;
    hearts.value = maxHearts;
    _inputLocked = false;
    _combo = 0;
    final level = repository.levelAt(index);
    logic = BoardLogic.fromLevel(level);
    _board?.removeFromParent();
    final board = BoardComponent(level: level)..anchor = Anchor.center;
    _board = board;
    add(board);
    _layoutBoard(size);
  }

  void restartLevel() {
    overlays.remove(clearedOverlayKey);
    overlays.remove(failedOverlayKey);
    startLevel(levelIndex.value);
  }

  bool get isLastLevel => levelIndex.value >= repository.length - 1;

  void nextLevel() {
    overlays.remove(clearedOverlayKey);
    final next = levelIndex.value + 1;
    if (next < repository.length) startLevel(next);
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
      canvas.y * 0.9 / board.size.y,
    );
    board.scale = Vector2.all(s);
    board.position = Vector2(canvas.x / 2, canvas.y / 2);
  }

  void handleTap(LineComponent lineComponent) {
    if (_inputLocked || lineComponent.animating) return;
    switch (logic.tap(lineComponent.line.id)) {
      case MoveEscaped():
        _onEscape(lineComponent);
      case MoveBlocked(:final freeSteps, :final blockerId):
        _onBlocked(lineComponent, freeSteps, blockerId);
    }
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
    lineComponent.escape(onGone: () {
      if (logic.isCleared) {
        Sfx.clear();
        onCleared?.call(levelIndex.value);
        add(
          TimerComponent(
            period: 0.35,
            removeOnFinish: true,
            onTick: () => overlays.add(clearedOverlayKey),
          ),
        );
      }
    });
  }

  void _onBlocked(LineComponent lineComponent, int freeSteps, int blockerId) {
    _combo = 0;
    lineComponent.bump(freeSteps, onImpact: () {
      Sfx.block();
      _board?.lineById(blockerId)?.flashRed();
      _shake();
      hearts.value = math.max(0, hearts.value - 1);
      if (hearts.value == 0) {
        _inputLocked = true;
        Sfx.fail();
        add(
          TimerComponent(
            period: 0.6,
            removeOnFinish: true,
            onTick: () => overlays.add(failedOverlayKey),
          ),
        );
      }
    });
  }

  void _zoomPunch() {
    _board?.add(
      ScaleEffect.by(
        Vector2.all(1.02),
        EffectController(
          duration: 0.06,
          reverseDuration: 0.14,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  void _shake() {
    // Deltas sum to zero so the board lands exactly back in place.
    _board?.add(
      SequenceEffect([
        MoveByEffect(Vector2(10, 0), EffectController(duration: 0.04)),
        MoveByEffect(Vector2(-16, 0), EffectController(duration: 0.05)),
        MoveByEffect(Vector2(8, 0), EffectController(duration: 0.05)),
        MoveByEffect(Vector2(-2, 0), EffectController(duration: 0.06)),
      ]),
    );
  }

  void _showComboText(LineComponent lineComponent) {
    final board = _board;
    if (board == null) return;
    final (r, c) = lineComponent.line.head;
    final text = TextComponent(
      text: 'x$_combo',
      position: Vector2(
        c * BoardComponent.cell + BoardComponent.cell / 2,
        r * BoardComponent.cell - 8,
      ),
      anchor: Anchor.bottomCenter,
      priority: 200,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: ZTheme.accent,
          fontSize: 52,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
    );
    board.add(text);
    text.add(
      MoveByEffect(
        Vector2(0, -70),
        EffectController(duration: 0.75, curve: Curves.easeOutCubic),
      ),
    );
    text.add(RemoveEffect(delay: 0.75));
  }
}
