import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/z_arrows_game.dart';
import '../models/levels.dart';
import '../services/ads/ads.dart';
import '../services/progress.dart';
import '../theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ZArrowsGame game = ZArrowsGame(
    levels: bundledLevels,
    startAt: widget.initialIndex,
    onCleared: (index) {
      final progress = Progress.instance;
      progress.markCleared(index);
      Ads.maybeShowInterstitial(
        totalClears: progress.totalClears.value,
        levelIndex: index,
      );
    },
  );

  void _onHintPressed() {
    final progress = Progress.instance;
    if (progress.hints.value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('힌트가 없습니다 — 충전은 다음 업데이트에서!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (game.showHint()) progress.useHint();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: ZTheme.inkSoft),
                  ),
                  SizedBox(
                    width: 84,
                    child: ValueListenableBuilder<int>(
                      valueListenable: game.levelIndex,
                      builder: (context, index, _) => Text(
                        'LEVEL ${index + 1}',
                        style: const TextStyle(
                          color: ZTheme.inkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: game.hearts,
                      builder: (context, hearts, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < ZArrowsGame.maxHearts; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Icon(
                                i < hearts
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    i < hearts ? ZTheme.danger : ZTheme.dot,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: Progress.instance.hints,
                    builder: (context, hints, _) => TextButton.icon(
                      onPressed: _onHintPressed,
                      icon: const Icon(Icons.lightbulb_outline,
                          color: ZTheme.accent),
                      label: Text(
                        '$hints',
                        style: const TextStyle(
                          color: ZTheme.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: game.restartLevel,
                    icon: const Icon(Icons.refresh, color: ZTheme.inkSoft),
                    tooltip: 'Restart',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: ZTheme.dot),
          Expanded(
            child: GameWidget(
              game: game,
              overlayBuilderMap: {
                ZArrowsGame.clearedOverlayKey: (context, _) => _ResultOverlay(
                      game: game,
                      title: 'CLEAR!',
                      accent: ZTheme.accent,
                      buttonLabel:
                          game.isLastLevel ? 'ALL DONE — HOME' : 'NEXT LEVEL',
                      onPressed: game.isLastLevel
                          ? () => Navigator.of(context).pop()
                          : game.nextLevel,
                    ),
                ZArrowsGame.failedOverlayKey: (context, _) => _ResultOverlay(
                      game: game,
                      title: 'OUT OF HEARTS',
                      accent: ZTheme.danger,
                      buttonLabel: 'TRY AGAIN',
                      onPressed: game.restartLevel,
                    ),
              },
            ),
          ),
          const AdsBanner(),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.game,
    required this.title,
    required this.accent,
    required this.buttonLabel,
    required this.onPressed,
  });

  final ZArrowsGame game;
  final String title;
  final Color accent;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB3F7F6F2),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        decoration: BoxDecoration(
          color: ZTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.levelIndex,
              builder: (context, index, _) => Text(
                'LEVEL ${index + 1}',
                style: const TextStyle(
                  color: ZTheme.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: ZTheme.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: ZTheme.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
