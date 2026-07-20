import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../app/tokens/colors.dart';
import 'pressable.dart';

/// A round sun/moon button that flips the app between light and dark on every
/// tap (not a switch). The icon shows the current mode — sun in light, moon in
/// dark — and swaps as the theme does.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final c = AppColors.of(context);
        final isDark = settings.themeMode == ThemeMode.dark;
        return Pressable(
          onTap: () => settings.setDarkMode(!isDark),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: c.line),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: size * 0.55,
              color: c.ink,
            ),
          ),
        );
      },
    );
  }
}
