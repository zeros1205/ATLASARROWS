import 'package:flutter/material.dart';

import '../models/levels.dart';
import '../services/ads/ads.dart';
import '../services/progress.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = Progress.instance;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: IconButton(
                        onPressed: () => _showSettings(context),
                        icon: const Icon(Icons.settings,
                            color: ZTheme.inkSoft, size: 28),
                        tooltip: 'Settings',
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_upward, color: ZTheme.ink, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Z-ARROWS',
                    style: TextStyle(
                      color: ZTheme.ink,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Shift the Arrows, Clear the Maze.',
                    style: TextStyle(
                      color: ZTheme.inkSoft,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: progress.unlocked,
                    builder: (context, unlocked, _) {
                      final next =
                          unlocked.clamp(0, bundledLevels.length - 1);
                      return FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ZTheme.ink,
                          foregroundColor: ZTheme.bg,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 56, vertical: 18),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameScreen(initialIndex: next),
                          ),
                        ),
                        child: Text('PLAY  ·  LEVEL ${next + 1}'),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZTheme.ink,
                      side: const BorderSide(color: ZTheme.ink, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelSelectScreen(),
                      ),
                    ),
                    child: const Text('LEVELS'),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
          const AdsBanner(),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final progress = Progress.instance;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZTheme.card,
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: ZTheme.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: progress.soundOn,
              builder: (context, on, _) => SwitchListTile(
                title: const Text('Sound', style: TextStyle(color: ZTheme.ink)),
                value: on,
                activeThumbColor: ZTheme.accent,
                onChanged: progress.setSound,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: progress.hapticsOn,
              builder: (context, on, _) => SwitchListTile(
                title: const Text('Vibration',
                    style: TextStyle(color: ZTheme.ink)),
                value: on,
                activeThumbColor: ZTheme.accent,
                onChanged: progress.setHaptics,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: ZTheme.accent)),
          ),
        ],
      ),
    );
  }
}
