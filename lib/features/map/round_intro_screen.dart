import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../app/tokens/colors.dart';
import '../../app/tokens/typography.dart';
import '../../models/campaign_repository.dart';
import '../../services/progress.dart';
import '../../shared/motion.dart';
import '../game/game_screen.dart';

/// Reached by selecting a country on the world map. A brief splash: the
/// country's flag stamps in over its name (in the app language), holds for a
/// beat, then clears itself. An unlocked round hands off to play; a locked one
/// returns to the map. Full-screen, so the shell header and tab bar stay hidden.
class RoundIntroScreen extends StatefulWidget {
  const RoundIntroScreen({super.key, required this.countryIndex});
  final int countryIndex;

  @override
  State<RoundIntroScreen> createState() => _RoundIntroScreenState();
}

class _RoundIntroScreenState extends State<RoundIntroScreen>
    with TickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 1200);

  // Enter (flag stamps in, name follows) and exit (whole thing fades out).
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _out = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));

  // Flag overshoots in like a passport stamp.
  late final Animation<double> _flagScale =
      Tween(begin: 0.4, end: 1.0).animate(
          CurvedAnimation(parent: _in, curve: Curves.easeOutBack));
  late final Animation<double> _flagOpacity = CurvedAnimation(
      parent: _in, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
  // Name arrives a beat later, rising into place.
  late final Animation<double> _nameOpacity = CurvedAnimation(
      parent: _in, curve: const Interval(0.32, 1.0, curve: Curves.easeOut));
  late final Animation<double> _nameRise = Tween(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _in,
          curve: const Interval(0.32, 1.0, curve: Curves.easeOutCubic)));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // run the sequence once, after context is ready
    _started = true;
    _run();
  }

  Future<void> _run() async {
    final reduce = reduceMotion(context);
    if (reduce) {
      _in.value = 1;
    } else {
      await _in.forward();
    }
    await Future<void>.delayed(_hold);
    if (!mounted) return;
    if (!reduce) {
      await _out.forward();
      if (!mounted) return;
    }
    _finish();
  }

  void _finish() {
    final repo = CampaignRepository.instance;
    final country = repo.countries[widget.countryIndex];
    final first = repo.firstStageOf(widget.countryIndex);
    final unlocked = Progress.instance.unlocked.value;
    if (first > unlocked) {
      Navigator.of(context).pop(); // still locked — nothing to play yet
      return;
    }
    final start = unlocked.clamp(first, first + country.stageCount - 1);
    Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => GameScreen(stage: start)));
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final country = CampaignRepository.instance.countries[widget.countryIndex];
    // One line, in the selected language — Korean where we have it, otherwise
    // the country's standard (English) name.
    final lang = Localizations.localeOf(context).languageCode;
    final name = lang == 'ko' && country.ko.isNotEmpty ? country.ko : country.name;
    final iso = country.iso;
    final hasFlag = iso.length == 2;

    return Scaffold(
      backgroundColor: c.bg, // home-screen ground, light/dark
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _out]),
          builder: (context, _) => Opacity(
            opacity: 1 - _out.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasFlag) ...[
                  Opacity(
                    opacity: _flagOpacity.value,
                    child: Transform.scale(
                      scale: _flagScale.value * (1 - 0.14 * _out.value),
                      child: _Flag(iso: iso),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Opacity(
                  opacity: _nameOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _nameRise.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: AppText.display.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w900,
                              height: 1.05),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.iso});
  final String iso;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CountryFlag.fromCountryCode(
            iso,
            theme: const ImageTheme(width: 116, height: 77),
          ),
        ),
      );
}
