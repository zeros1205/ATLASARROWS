import 'package:flutter/material.dart';

import 'tokens/colors.dart';
import 'tokens/typography.dart';

/// Builds the Material theme for a given brightness + locale. Depth comes
/// from whitespace and hairline borders, not elevation; no Material ripple.
ThemeData buildTheme(Brightness brightness, Locale? locale) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final family = AppText.familyFor(locale);

  TextStyle t(TextStyle s) =>
      s.copyWith(fontFamily: family, color: c.ink);

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: family,
    fontFamilyFallback: AppText.fallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.surface,
    ).copyWith(primary: c.accent, onPrimary: c.onAccent, error: c.danger),
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: c.ink,
    ),
    textTheme: TextTheme(
      displayLarge: t(AppText.display),
      titleLarge: t(AppText.title),
      titleMedium: t(AppText.headline),
      bodyLarge: t(AppText.body),
      bodyMedium: t(AppText.body),
      labelLarge: t(AppText.label),
      labelSmall: t(AppText.caption),
    ),
  );
  return base;
}
