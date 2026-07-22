import 'package:flutter/widgets.dart';

/// Locale-aware type. Korean uses Paperlogy, other locales use Outfit,
/// Pretendard is the glyph fallback for both. A 6-step scale keeps every
/// screen on the same rhythm — use these, not ad-hoc sizes.
///
/// ⛔ 16 is the floor, everywhere. [label] and [caption] are no longer smaller
/// than [body] — they differ in weight and tracking only. Do not reintroduce a
/// `fontSize:` under 16 in a copyWith; that is what this scale exists to stop.
abstract final class AppText {
  /// Latin display face; Hangul falls back to Paperlogy via [fallback].
  static const _latin = 'Outfit';
  static const _hangul = 'Paperlogy';
  static const fallback = <String>[_hangul, 'Pretendard'];

  /// Chooses the primary family for the active locale.
  static String familyFor(Locale? locale) =>
      locale?.languageCode == 'ko' ? _hangul : _latin;

  static const _fam = _latin; // pre-boot default; overridden per-locale in theme

  static const display = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4);
  static const title = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.2);
  static const headline = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 18, fontWeight: FontWeight.w700);
  static const body = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 16, fontWeight: FontWeight.w500, height: 1.35, letterSpacing: 0.1);
  static const label = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const caption = TextStyle(
    fontFamily: _fam, fontFamilyFallback: fallback,
    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}

/// Every big action button — filled or outlined, on any screen — is this tall
/// and this weight. They used to run 12/13/14/15/16/17/18 with w600 and w900
/// mixed in, which reads as sloppiness the moment two of them share a screen.
const double kButtonPadV = 18;
final TextStyle kButtonText =
    AppText.headline.copyWith(fontWeight: FontWeight.w800);

/// Pill buttons inside a compact popup (confirm dialogs, bottom sheets) — the
/// full [kButtonPadV] height reads as oversized against the tighter copy a
/// modal is built from. Popups only; screen-level CTAs keep [kButtonPadV].
const double kPopupButtonPadV = 14;
