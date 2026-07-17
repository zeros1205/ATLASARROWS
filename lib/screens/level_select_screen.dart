import 'package:flutter/material.dart';

import '../models/level_repository.dart';
import '../models/levels.dart';
import '../services/ads/ads.dart';
import '../services/progress.dart';
import '../theme.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = LevelRepository.instance.length;
    final chapters = (total / levelsPerChapter).ceil();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ZTheme.bg,
        foregroundColor: ZTheme.ink,
        elevation: 0,
        title: const Text(
          'LEVELS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: Progress.instance.unlocked,
              builder: (context, unlocked, _) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: chapters,
                itemBuilder: (context, chapter) {
                  final start = chapter * levelsPerChapter;
                  final count =
                      (total - start).clamp(0, levelsPerChapter);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'CHAPTER ${chapter + 1}',
                          style: const TextStyle(
                            color: ZTheme.inkSoft,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: 5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          for (var i = start; i < start + count; i++)
                            _LevelTile(index: i, unlocked: unlocked),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const AdsBanner(),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.index, required this.unlocked});

  final int index;
  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final cleared = index < unlocked;
    final current = index == unlocked;
    final locked = index > unlocked;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: locked
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameScreen(initialIndex: index),
                ),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: cleared
              ? ZTheme.ink
              : current
                  ? ZTheme.accent
                  : ZTheme.dot,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: locked
            ? const Icon(Icons.lock, color: ZTheme.inkSoft, size: 20)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: cleared || current ? ZTheme.bg : ZTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
