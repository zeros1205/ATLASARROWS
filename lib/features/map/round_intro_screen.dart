import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../services/progress.dart';
import '../../shared/pressable.dart';
import '../game/game_screen.dart';

/// Reached by selecting a country on the world map. Shows the round summary
/// (ROUND / country / blurb / N Stages·Cities·Paths). If the country is
/// unlocked it offers PLAY; if still locked it shows a lock button.
class RoundIntroScreen extends StatelessWidget {
  const RoundIntroScreen({super.key, required this.countryIndex});
  final int countryIndex;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final repo = CampaignRepository.instance;
    final country = repo.countries[countryIndex];
    final unlocked = Progress.instance.unlocked.value;
    final first = repo.firstStageOf(countryIndex);
    final locked = first > unlocked;
    final lang = Localizations.localeOf(context).languageCode;
    final blurb = country.introFor(lang);
    // How much of this round is behind the player — the same number the map
    // colours in, so the two surfaces agree.
    final cleared = (unlocked - first).clamp(0, country.stageCount);
    final progress = country.stageCount == 0
        ? 0
        : (cleared * 100 / country.stageCount).round();

    void play() {
      final start = unlocked.clamp(first, first + country.stageCount - 1);
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => GameScreen(stage: start)));
    }

    final headColor = locked ? c.inkFaint : c.accent;
    final nameColor = locked ? c.inkSoft : c.ink;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pressable(
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back, color: c.inkFaint, size: 24)),
              ),
              const SizedBox(height: 6),
              Text('ROUND ${(countryIndex + 1).toString().padLeft(2, '0')}',
                  style: AppText.label
                      .copyWith(color: headColor, letterSpacing: 4, fontSize: 13)),
              const SizedBox(height: 10),
              Text(country.displayName,
                  style: AppText.display.copyWith(
                      color: nameColor, fontWeight: FontWeight.w900, height: 1.05)),
              if (country.ko.isNotEmpty && country.name != country.ko)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(country.name,
                      style: AppText.body.copyWith(color: c.inkFaint)),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    locked
                        ? '이전 국가를 클리어하면 이 라운드가 열립니다.'
                        : blurb.isNotEmpty
                            ? blurb
                            : country.teaches.isNotEmpty
                                ? '이번 라운드에서 배울 것 — ${country.teaches}'
                                : country.cityCount > 0
                                    ? '${country.displayName}의 도시 ${country.cityCount}곳을 '
                                        '지나 마지막에 나라 전체를 풀어냅니다.'
                                    : '${country.displayName}의 영토를 한 판으로 풀어냅니다.',
                    style: AppText.body.copyWith(
                        color: c.inkSoft, height: 1.55, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: locked ? 0.5 : 1,
                child: Row(
                  children: [
                    _stat(c, '${country.stageCount}', '스테이지'),
                    _stat(c, '${country.cityCount}', '도시'),
                    _stat(c, '$progress%', '진행'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (locked)
                _LockButton(c)
              else
                Pressable(
                  onTap: play,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('플레이',
                        style: AppText.headline.copyWith(
                            color: c.onAccent, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Column(
            children: [
              Text(value,
                  style: AppText.title.copyWith(
                      color: c.ink, fontWeight: FontWeight.w900, fontSize: 26)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption.copyWith(
                      color: c.inkFaint, letterSpacing: 1.5, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _LockButton extends StatelessWidget {
  const _LockButton(this.c);
  final AppColors c;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: c.dot, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: c.inkFaint),
            const SizedBox(width: 8),
            Text('잠김',
                style: AppText.headline.copyWith(
                    color: c.inkFaint, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
