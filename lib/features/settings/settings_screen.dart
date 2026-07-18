import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/tokens/colors.dart';
import '../../app/tokens/dimens.dart';
import '../../app/tokens/typography.dart';
import '../../shared/meta_header.dart';

/// Settings tab. Two themes only (light/dark). Language switch (one setting
/// = one language for the whole UI). Working dark-mode toggle wired to
/// AppSettings; other rows are skeletons.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MetaHeader('설정'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
              children: [
                _ToggleRow(
                  label: '다크 모드',
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (v) => settings.setDarkMode(v),
                ),
                const _NavRow(label: '소리', trailing: '켜짐'),
                const _NavRow(label: '진동', trailing: '켜짐'),
                _NavRow(
                  label: '언어',
                  trailing:
                      settings.locale?.languageCode == 'en' ? 'English' : '한국어',
                  onTap: () => _pickLanguage(context),
                ),
                const _NavRow(label: '광고 제거', trailing: '₩9,900 ›'),
                const _NavRow(label: '구매 복원', trailing: '›'),
                const SizedBox(height: 12),
                _Version(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(BuildContext context) {
    final settings = AppSettings.instance;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final loc in AppSettings.supportedLocales)
              ListTile(
                title: Text(loc.languageCode == 'en' ? 'English' : '한국어'),
                onTap: () {
                  settings.setLocale(loc);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _rowShell(
        c,
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.label.copyWith(color: c.ink))),
            Text(trailing, style: AppText.label.copyWith(color: c.inkFaint)),
          ],
        ),
      ),
    );
  }
}

Widget _rowShell(AppColors c, {required Widget child}) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );

class _Version extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text('v0.1.0 · © 2026 LOGAN LAND',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: c.inkFaint));
  }
}
