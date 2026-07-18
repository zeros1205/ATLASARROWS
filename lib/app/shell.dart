import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shop/shop_screen.dart';
import '../shared/pressable.dart';
import 'tokens/colors.dart';
import 'tokens/dimens.dart';
import 'tokens/typography.dart';

/// The 4-tab home shell: home / map / shop / settings, with a floating
/// capsule tab bar. All tabs open from the start (no locking).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home, label: '홈'),
    (icon: Icons.public_outlined, active: Icons.public, label: '맵'),
    (icon: Icons.storefront_outlined, active: Icons.storefront, label: '상점'),
    (icon: Icons.settings_outlined, active: Icons.settings, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          MapScreen(),
          ShopScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _TabBar(
        index: _index,
        tabs: _tabs,
        onTap: (i) => setState(() => _index = i),
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
        height: 64,
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

  final ({IconData icon, IconData active, String label}) tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.accent : c.inkFaint;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: AppDur.fast,
          width: 46,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Icon(selected ? tab.active : tab.icon, size: 22, color: color),
        ),
        const SizedBox(height: 2),
        Text(tab.label,
            style: AppText.caption.copyWith(
                fontSize: 10.5, color: color, letterSpacing: 0)),
      ],
    );
  }
}
