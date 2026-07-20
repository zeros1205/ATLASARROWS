import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../app/shell.dart';
import '../../models/campaign_repository.dart';
import '../../services/progress.dart';
import '../../shared/pressable.dart';
import '../../shared/theme_toggle_button.dart';
import '../game/game_screen.dart';

/// Home: centred game logo, then the play CTAs. A brand-new player sees a
/// single '시작하기'; a returning player sees '이어서 플레이' + '맵에서 플레이'.
/// No hearts/gem in the header (hearts live in-play; gem is unused).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    void play() {
      final stage = Progress.instance.unlocked.value
          .clamp(0, (CampaignRepository.instance.totalStages - 1).clamp(0, 1 << 30));
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GameScreen(stage: stage)));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ValueListenableBuilder<int>(
          valueListenable: Progress.instance.unlocked,
          builder: (context, unlocked, _) {
            final isNew = unlocked <= 0;
            return Column(
              children: [
                const Spacer(flex: 3),
                // Centred game logo (wordmark stands in until the logo art lands).
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'ATLAS'),
                    TextSpan(text: '·', style: TextStyle(color: c.accent)),
                    const TextSpan(text: 'ARROWS'),
                  ]),
                  style: AppText.display.copyWith(
                      color: c.ink, fontSize: 38, letterSpacing: -1),
                ),
                const SizedBox(height: 6),
                Text('SHIFT THE ARROWS',
                    style: AppText.caption
                        .copyWith(color: c.inkFaint, letterSpacing: 2.5)),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: isNew
                      ? _PrimaryButton(label: '시작하기', onTap: play)
                      : Column(
                          children: [
                            _PrimaryButton(
                                label: '이어서 플레이',
                                sub: _resumeLabel(),
                                onTap: play),
                            const SizedBox(height: AppGap.md),
                            _SecondaryButton(
                                label: '맵에서 플레이',
                                icon: Icons.public_outlined,
                                onTap: () => appTab.value = 1),
                          ],
                        ),
                ),
                const Spacer(flex: 3),
              ],
            );
          },
            ),
            const Positioned(
              top: 4,
              right: 12,
              child: ThemeToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}

String _resumeLabel() {
  final repo = CampaignRepository.instance;
  if (!repo.isLoaded) return '스테이지 1';
  final stage =
      Progress.instance.unlocked.value.clamp(0, repo.totalStages - 1);
  final (ci, local) = repo.locate(stage);
  final country = repo.countries[ci];
  // Position inside the round, not the global index: "stage 641" tells a
  // player nothing, and the round is the unit they are actually working on.
  return '${country.displayName} · ${local + 1} / ${country.stageCount}';
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.sub, required this.onTap});
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppText.headline
                    .copyWith(color: c.onAccent, fontWeight: FontWeight.w900)),
            if (sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  style: AppText.caption.copyWith(
                      color: c.onAccent.withValues(alpha: 0.8),
                      letterSpacing: 1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c.ink),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.label
                    .copyWith(color: c.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
