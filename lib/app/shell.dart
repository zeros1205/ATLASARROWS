import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shop/shop_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/iap.dart';
import '../shared/pressable.dart';
import 'tokens/colors.dart';
import 'tokens/dimens.dart';
import 'tokens/typography.dart';

/// Selected shell tab, shared so any screen can switch tabs (e.g. Home's
/// "세계지도" button jumps to the map). 0=home 1=map 2=shop 3=settings.
final ValueNotifier<int> appTab = ValueNotifier<int>(0);

/// Height the floating tab bar occupies above the bottom safe area — its own
/// height plus the margin it floats on. Screens that draw behind it (the map
/// sets `extendBody`) inset their content by this so nothing hides under it.
const double kTabBarSlot = 64 + 14;

/// The 4-tab home shell: home / map / shop / settings, with a floating
/// capsule tab bar. All tabs open from the start (no locking).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // Purchase outcomes can land while the player is on any tab (or has left
    // the store and come back), so the feedback lives at the shell.
    IapService.instance.message.addListener(_showPurchaseMessage);
  }

  @override
  void dispose() {
    IapService.instance.message.removeListener(_showPurchaseMessage);
    super.dispose();
  }

  void _showPurchaseMessage() {
    final msg = IapService.instance.message.value;
    if (msg == null || !mounted) return;
    IapService.instance.message.value = null;
    final l = AppLocalizations.of(context);
    final text = switch (msg.outcome) {
      IapOutcome.purchaseStartFailed => l.iapPurchaseStartFailed,
      IapOutcome.restoreUnsupported => l.iapRestoreUnsupported,
      IapOutcome.restoreChecked => l.iapRestoreChecked,
      IapOutcome.restoreFailed => l.iapRestoreFailed,
      IapOutcome.purchaseFailed => l.iapPurchaseFailed,
      IapOutcome.hintsGranted => l.iapHintsGranted(msg.count),
      IapOutcome.removesGranted => l.iapRemovesGranted(msg.count),
      IapOutcome.adsRemoved => l.iapAdsRemoved,
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tabs = <({IconData icon, IconData active, String label})>[
      (icon: Icons.home_outlined, active: Icons.home, label: l.tabHome),
      (icon: Icons.public_outlined, active: Icons.public, label: l.tabMap),
      (icon: Icons.storefront_outlined, active: Icons.storefront, label: l.tabShop),
      (icon: Icons.settings_outlined, active: Icons.settings, label: l.tabSettings),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: appTab,
      builder: (context, index, _) => Scaffold(
        // The map is a full-screen surface with the tab bar floating over it,
        // so on that tab the body extends behind the bar. Other tabs keep the
        // bar reserving its own space.
        extendBody: index == 1,
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            MapScreen(),
            ShopScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: _TabBar(
          index: index,
          tabs: tabs,
          onTap: (i) => appTab.value = i,
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.tabs, required this.onTap});

  final int index;
  final List<({IconData icon, IconData active, String label})> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        height: kTabBarSlot - 14,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: c.line),
          boxShadow: [
            BoxShadow(color: c.shadow, blurRadius: 30, spreadRadius: -10,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: Pressable(
                  haptic: false,
                  onTap: () => onTap(i),
                  child: _TabItem(tab: tabs[i], selected: i == index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected});

  /// One width for all four pills. Comfortably inside the narrowest tab slot
  /// (a quarter of the bar) on a small phone.
  static const double _pillWidth = 68;

  final ({IconData icon, IconData active, String label}) tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.accent : c.inkSoft;
    // The selected pill wraps the icon AND the label — a chip round the icon
    // alone reads as a separate control sitting above unrelated text.
    //
    // Fixed width, not padding: '홈' is one glyph and '상점' is two, so a pill
    // sized to its content lands on a different width under every tab and the
    // row reads as ragged.
    return Center(
      child: AnimatedContainer(
        duration: AppDur.fast,
        width: _pillWidth,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? tab.active : tab.icon, size: 20, color: color),
            Text(tab.label,
                style: AppText.caption.copyWith(color: color, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}
