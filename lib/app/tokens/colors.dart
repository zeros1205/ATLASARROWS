import 'package:flutter/material.dart';

/// Semantic color tokens for Atlas Arrows, resolved per theme via a
/// [ThemeExtension]. Reach them with `AppColors.of(context)`.
///
/// Identity: paper + ink. Off-white paper ground, off-black ink for the
/// maze and headings, one blue accent for action, red for mistakes. Two
/// themes only — light and dark — per project policy.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.dot,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.success,
    required this.amber,
    required this.onAccent,
    required this.scrim,
    required this.shadow,
  });

  final Color bg;           // page ground (paper)
  final Color surface;      // panels
  final Color surfaceMuted; // recessed fills
  final Color card;         // elevated cards / dialogs
  final Color ink;          // primary text, maze lines
  final Color inkSoft;      // secondary text
  final Color inkFaint;     // tertiary / disabled
  final Color line;         // hairline borders
  final Color dot;          // empty-cell dots
  final Color accent;       // action / escaping line
  final Color accentSoft;   // accent tint fills
  final Color danger;       // hearts, mistakes
  final Color success;      // completion
  final Color amber;        // remove item
  final Color onAccent;     // text on accent
  final Color scrim;        // modal barrier
  final Color shadow;       // soft shadow color

  static const light = AppColors(
    bg: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDECE6),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF23252E),
    inkSoft: Color(0xFF6E6F78),
    inkFaint: Color(0xFF9A9DAB),
    line: Color(0xFFE7E5DE),
    dot: Color(0xFFE4E3DD),
    accent: Color(0xFF2F6BFF),
    accentSoft: Color(0x1F2F6BFF),
    danger: Color(0xFFFF4D67),
    success: Color(0xFF27C356),
    amber: Color(0xFFFF9E2C),
    onAccent: Color(0xFFFFFFFF),
    scrim: Color(0x59141A2E),
    shadow: Color(0x1A23252E),
  );

  static const dark = AppColors(
    bg: Color(0xFF17181D),
    surface: Color(0xFF1F2127),
    surfaceMuted: Color(0xFF23252C),
    card: Color(0xFF23252C),
    ink: Color(0xFFECEBE6),
    inkSoft: Color(0xFFA6A8B0),
    inkFaint: Color(0xFF7C7F8C),
    line: Color(0xFF2E3038),
    dot: Color(0xFF33353F),
    accent: Color(0xFF4C82FF),
    accentSoft: Color(0x264C82FF),
    danger: Color(0xFFFF5D75),
    success: Color(0xFF3AD06A),
    amber: Color(0xFFFFAE47),
    onAccent: Color(0xFF10131C),
    scrim: Color(0x8C000000),
    shadow: Color(0x66000000),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? bg, Color? surface, Color? surfaceMuted, Color? card, Color? ink,
    Color? inkSoft, Color? inkFaint, Color? line, Color? dot, Color? accent,
    Color? accentSoft, Color? danger, Color? success, Color? amber,
    Color? onAccent, Color? scrim, Color? shadow,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      dot: dot ?? this.dot,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      amber: amber ?? this.amber,
      onAccent: onAccent ?? this.onAccent,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      inkSoft: c(inkSoft, other.inkSoft),
      inkFaint: c(inkFaint, other.inkFaint),
      line: c(line, other.line),
      dot: c(dot, other.dot),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      amber: c(amber, other.amber),
      onAccent: c(onAccent, other.onAccent),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
    );
  }
}
