import 'package:flutter/widgets.dart';

/// One type family for the whole UI: Pretendard, across every locale. It
/// carries Latin, Cyrillic and full Hangul; Japanese kana/kanji and Chinese
/// hanzi it lacks fall through to the platform CJK font. A 6-step scale keeps
/// every screen on the same rhythm — use these, not ad-hoc sizes.
///
/// The only text NOT on this family is the ATLAS/ARROWS wordmark, which pins
/// itself to Outfit (see home_screen's `_Wordmark`).
///
/// ⛔ 16 is the floor, everywhere. [label] and [caption] are no longer smaller
/// than [body] — they differ in weight and tracking only. Do not reintroduce a
/// `fontSize:` under 16 in a copyWith; that is what this scale exists to stop.
abstract final class AppText {
  static const _fam = 'Pretendard';

  /// Only Regular (400) and Bold (700) Pretendard weights are bundled, so any
  /// requested weight resolves to the nearer of the two.
  static const fallback = <String>[];

  /// The primary family is Pretendard regardless of locale; kept as a function
  /// so the theme's per-locale wiring has nothing to special-case.
  static String familyFor(Locale? locale) => _fam;

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
