import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/level.dart';
import '../theme.dart';
import 'board_component.dart';
import 'board_logic.dart';
import 'line_component.dart';

class ZArrowsGame extends FlameGame {
  ZArrowsGame({required this.levels});

  static const clearedOverlayKey = 'cleared';
  static const failedOverlayKey = 'failed';
  static const int maxHearts = 3;

  final List<Level> levels;
  final ValueNotifier<int> levelIndex = ValueNotifier(0);
  final ValueNotifier<int> hearts = ValueNotifier(maxHearts);

  late BoardLogic logic;
  BoardComponent? _board;
  bool _inputLocked = false;

  @override
  Color backgroundColor() => ZTheme.bg;

  @override
  Future<void> onLoad() async {
    startLevel(0);
  }

  void startLevel(int index) {
    levelIndex.value = index;
    hearts.value = maxHearts;
    _inputLocked = false;
    logic = BoardLogic.fromLevel(levels[index]);
    _board?.removeFromParent();
    final board = BoardComponent(level: levels[index]);
    _board = board;
    add(board);
    _layoutBoard(size);
  }

  void restartLevel() {
    overlays.remove(clearedOverlayKey);
    overlays.remove(failedOverlayKey);
    startLevel(levelIndex.value);
  }

  void nextLevel() {
    overlays.remove(clearedOverlayKey);
    startLevel((levelIndex.value + 1) % levels.length);
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
      canvas.y * 0.74 / board.size.y,
    );
    board.scale = Vector2.all(s);
    board.position = Vector2(
      (canvas.x - board.size.x * s) / 2,
      (canvas.y - board.size.y * s) / 2,
    );
  }

  void handleTap(LineComponent lineComponent) {
    if (_inputLocked || lineComponent.animating) return;
    switch (logic.tap(lineComponent.line.id)) {
      case MoveEscaped():
        logic.removeLine(lineComponent.line.id);
        lineComponent.escape(onGone: () {
          if (logic.isCleared) {
            add(
              TimerComponent(
                period: 0.25,
                removeOnFinish: true,
                onTick: () => overlays.add(clearedOverlayKey),
              ),
            );
          }
        });
      case MoveBlocked(:final freeSteps):
        lineComponent.bump(freeSteps, onImpact: () {
          hearts.value = math.max(0, hearts.value - 1);
          if (hearts.value == 0) {
            _inputLocked = true;
            add(
              TimerComponent(
                period: 0.5,
                removeOnFinish: true,
                onTick: () => overlays.add(failedOverlayKey),
              ),
            );
          }
        });
    }
  }
}
