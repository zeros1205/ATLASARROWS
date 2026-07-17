import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../game/z_arrows_game.dart';
import '../models/level_repository.dart';
import '../services/ads/ads.dart';
import '../services/iap.dart';
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
    repository: LevelRepository.instance,
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
    if (progress.hints.value > 0) {
      if (game.showHint()) progress.useHint();
      return;
    }
    _openHintShop();
  }

  void _openHintShop() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _HintShopSheet(
        onWatchAd: () {
          Navigator.of(sheetContext).pop();
          Ads.showRewarded(
            onReward: () {
              Progress.instance.grantHints(1);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('+1 HINT'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            onUnavailable: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ad not ready — try again in a moment'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
      ),
    );
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

class _HintShopSheet extends StatelessWidget {
  const _HintShopSheet({required this.onWatchAd});

  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GET HINTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 18),
            _ShopTile(
              icon: Icons.play_circle_outline,
              title: 'WATCH AD',
              trailing: '+1',
              accent: ZTheme.accent,
              onTap: onWatchAd,
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<ProductDetails>>(
              valueListenable: IapService.instance.products,
              builder: (context, products, _) {
                if (products.isEmpty) {
                  return Column(
                    children: [
                      for (final entry in IapService.hintProducts.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ShopTile(
                            icon: Icons.lightbulb_outline,
                            title: '${entry.value} HINTS',
                            trailing: 'COMING SOON',
                            accent: ZTheme.inkSoft,
                            onTap: null,
                          ),
                        ),
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final product in products)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ShopTile(
                          icon: Icons.lightbulb,
                          title:
                              '${IapService.hintProducts[product.id] ?? '?'} HINTS',
                          trailing: product.price,
                          accent: ZTheme.ink,
                          onTap: () {
                            Navigator.of(context).pop();
                            IapService.instance.buy(product);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: onTap == null ? ZTheme.inkSoft : ZTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
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
