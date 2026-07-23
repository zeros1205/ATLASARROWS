import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../shared/pressable.dart';
import '../game/game_screen.dart';

/// Full-screen country sheet, opened from a map marker's name bubble. Country
/// name and flag pinned at the top, then a scrolling list: the country row
/// (accent hairline) first, then every city — all with a play button and all
/// open to play freely. Close with the X, top-right.
class CountryDetailScreen extends StatelessWidget {
  const CountryDetailScreen({super.key, required this.countryIndex});
  final int countryIndex;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final repo = CampaignRepository.instance;
    final country = repo.countries[countryIndex];
    final first = repo.firstStageOf(countryIndex);
    final iso = country.iso;
    final hasFlag = iso.length == 2;

    // The round's cities, in play order, with their global stage index.
    final cities = <({String name, int global})>[
      for (var j = 0; j < country.stages.length; j++)
        if (country.stages[j].kind == StageKind.city)
          (name: country.stages[j].displayName, global: first + j),
    ];
    // The country silhouette board (the round's finale, always its last stage).
    final countryGlobal = first + country.stages.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    country.displayName,
                    textAlign: TextAlign.center,
                    style: AppText.headline
                        .copyWith(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                ),
                if (hasFlag) ...[
                  const SizedBox(height: 16),
                  _Flag(iso: iso),
                ],
                const SizedBox(height: 12),
                // Emoji label so the stat needs no translation.
                Text('⬜  ${_fmtArea(country.areaKm2)}',
                    style: AppText.caption.copyWith(color: c.inkSoft)),
                const SizedBox(height: 20),
                Container(height: 1, color: c.line),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    // The country row leads, then every city — all open to play.
                    itemCount: cities.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _CityRow(
                          name: country.displayName,
                          accent: true,
                          onPlay: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      GameScreen(stage: countryGlobal))),
                        );
                      }
                      final city = cities[i - 1];
                      return _CityRow(
                        name: city.name,
                        onPlay: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    GameScreen(stage: city.global))),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                color: c.inkSoft,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "9,833,517㎢" — thousands-grouped, with a floor for sub-1km² micro-states.
String _fmtArea(int km2) {
  if (km2 < 1) return '1㎢ 미만';
  final s = km2.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b㎢';
}

/// One row: a name and a play button. [accent] gives the country row its 2px
/// accent hairline to set it apart from the cities below.
class _CityRow extends StatelessWidget {
  const _CityRow(
      {required this.name, required this.onPlay, this.accent = false});
  final String name;
  final VoidCallback onPlay;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: accent ? c.accent : c.line, width: accent ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppText.label
                  .copyWith(color: c.ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: onPlay,
            child: Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Icon(Icons.play_arrow_rounded, size: 26, color: c.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

/// The country flag, in a rounded plate with a hairline border.
class _Flag extends StatelessWidget {
  const _Flag({required this.iso});
  final String iso;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.of(context).line, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: CountryFlag.fromCountryCode(
            iso,
            theme: const ImageTheme(width: 54, height: 36),
          ),
        ),
      );
}
