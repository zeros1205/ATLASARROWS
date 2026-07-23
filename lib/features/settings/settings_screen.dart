import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_settings.dart';
import '../../app/shell.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../services/game_services.dart';
import '../../services/iap.dart';
import '../../services/progress.dart';
import '../../shared/meta_header.dart';
import '../../shared/pressable.dart';
import '../onboarding/onboarding_screen.dart';

/// Settings tab. Two themes only (light/dark). Language switch (one setting
/// = one language for the whole UI). Every row here is live — sound and
/// haptics gate [Sfx] and [Pressable], remove-ads / restore go to the store.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final progress = Progress.instance;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('설정'),
          Expanded(
            // SettingsScreen is a const child of the shell's IndexedStack, so it
            // never rebuilds on its own — without this, the dark-mode row's
            // `value` and the language row's `trailing` were read once at
            // construction and never again, so tapping the dark-mode switch
            // changed the app's actual theme (the root listens separately) but
            // the switch itself stayed stuck in its old position.
            child: AnimatedBuilder(
              animation: settings,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
                children: [
                  _ToggleRow(
                    label: '다크 모드',
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: settings.setDarkMode,
                  ),
                  _BoundToggleRow(
                    label: '소리',
                    source: progress.soundOn,
                    onChanged: progress.setSound,
                  ),
                  _BoundToggleRow(
                    label: '진동',
                    source: progress.hapticsOn,
                    onChanged: progress.setHaptics,
                  ),
                  _NavRow(
                    label: '언어',
                    trailing: AppSettings
                            .languageNames[settings.locale?.languageCode] ??
                        '한국어',
                    onTap: () => _pickLanguage(context),
                  ),
                  const SizedBox(height: AppGap.lg),
                  if (GameServices.supported) ...[
                    _GameServicesRows(),
                    const SizedBox(height: AppGap.lg),
                  ],
                  _NavRow(
                    label: '튜토리얼 다시 보기',
                    trailing: '›',
                    onTap: () => _replayOnboarding(context),
                  ),
                  const SizedBox(height: AppGap.lg),
                  _RemoveAdsRow(),
                  _NavRow(
                    label: '구매 복원',
                    trailing: '›',
                    onTap: IapService.instance.restore,
                  ),
                  const SizedBox(height: 12),
                  _Version(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Replays the intro carousel and re-arms the first-stage coach. Campaign
  /// progress is untouched — this is a refresher, not a reset.
  void _replayOnboarding(BuildContext context) {
    Progress.instance.replayOnboarding();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => OnboardingScreen(
          onDone: () {
            Navigator.of(routeContext).pop();
            appTab.value = 0;
          },
        ),
      ),
    );
  }

  void _pickLanguage(BuildContext context) {
    final settings = AppSettings.instance;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final loc in AppSettings.supportedLocales)
                ListTile(
                  title: Text(
                      AppSettings.languageNames[loc.languageCode] ??
                          loc.languageCode),
                  selected: settings.locale?.languageCode == loc.languageCode,
                  onTap: () {
                    settings.setLocale(loc);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Play Games / Game Center entry points. Only built on mobile. When the
/// player isn't signed in the first row offers sign-in; the platform sheets
/// prompt for it themselves too, so tapping a board before signing in still
/// works.
class _GameServicesRows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GameServices.signedIn,
      builder: (context, signedIn, _) => Column(
        children: [
          _NavRow(
            label: defaultTargetPlatform == TargetPlatform.iOS
                ? 'Game Center'
                : 'Play 게임즈',
            trailing: signedIn ? '연결됨' : '연결하기 ›',
            onTap: signedIn ? null : GameServices.signIn,
          ),
          _NavRow(
            label: '리더보드',
            trailing: '›',
            onTap: GameServices.showLeaderboards,
          ),
          _NavRow(
            label: '업적',
            trailing: '›',
            onTap: GameServices.showAchievements,
          ),
        ],
      ),
    );
  }
}

/// Remove-ads: shows the store price when the product is registered, 보유 중
/// once owned, 준비중 while the store listing is still pending.
class _RemoveAdsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iap = IapService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: Progress.instance.adsRemoved,
      builder: (context, removed, _) {
        if (removed) {
          return const _NavRow(label: '광고 제거', trailing: '보유 중');
        }
        return ValueListenableBuilder<List<ProductDetails>>(
          valueListenable: iap.products,
          builder: (context, _, _) {
            final product = iap.productFor(IapService.removeAdsProduct);
            return _NavRow(
              label: '광고 제거',
              trailing: product == null ? '준비중' : '${product.price} ›',
              onTap: product == null ? null : () => iap.buy(product),
            );
          },
        );
      },
    );
  }
}

/// A toggle driven by a persistent [ValueNotifier] in [Progress].
class _BoundToggleRow extends StatelessWidget {
  const _BoundToggleRow(
      {required this.label, required this.source, required this.onChanged});
  final String label;
  final ValueNotifier<bool> source;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: source,
        builder: (context, value, _) =>
            _ToggleRow(label: label, value: value, onChanged: onChanged),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _rowShell(
      c,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.label.copyWith(color: c.ink))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: c.accent),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.trailing, this.onTap});
  final String label, trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final row = _rowShell(
      c,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.label.copyWith(color: c.ink))),
          Text(trailing, style: AppText.label.copyWith(color: c.inkFaint)),
        ],
      ),
    );
    if (onTap == null) return Opacity(opacity: 0.65, child: row);
    return Pressable(scale: 0.985, onTap: onTap, child: row);
  }
}

/// Every settings row is the same height. A Switch is taller than a line of
/// text, so letting the rows size themselves made the toggles visibly taller
/// than the links sitting right under them.
const double _rowHeight = 56;

Widget _rowShell(AppColors c, {required Widget child}) => Container(
      height: _rowHeight,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );

/// LOGAN and LAND are separately tappable: ten taps on LOGAN arms the cheat
/// button on the play screen, ten on LAND disarms it. Deliberately silent —
/// the copyright line is the last place a player pokes at.
class _Version extends StatefulWidget {
  @override
  State<_Version> createState() => _VersionState();
}

class _VersionState extends State<_Version> {
  static const _tapsToToggle = 10;
  int _logan = 0, _land = 0;

  void _tapLogan() {
    _land = 0;
    if (++_logan < _tapsToToggle) return;
    _logan = 0;
    Progress.instance.setCheatOn(true);
    _say('치트 ON');
  }

  void _tapLand() {
    _logan = 0;
    if (++_land < _tapsToToggle) return;
    _land = 0;
    Progress.instance.setCheatOn(false);
    _say('치트 OFF');
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Version + build number, so a tester can tell exactly which build they're
    // on. CI passes --build-number=<github run number>, so the build number
    // here matches the Actions run that produced the APK/IPA.
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final label = info == null
            ? 'v0.1.0'
            : 'v${info.version} (build ${info.buildNumber})';
        final style = AppText.caption.copyWith(color: c.inkFaint);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$label · © 2026 ', style: style),
            GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tapLogan,
                child: Text('LOGAN', style: style)),
            Text(' ', style: style),
            GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tapLand,
                child: Text('LAND', style: style)),
          ],
        );
      },
    );
  }
}
