# Bundled font licenses

All bundled typefaces are licensed under the **SIL Open Font License, Version
1.1** (free to use, study, modify and redistribute; bundling in software is
permitted; the fonts may not be sold on their own). The full license text for
each ships alongside the fonts and is registered with `LicenseRegistry` in
`lib/main.dart`, so attribution is surfaced in-app via the standard licenses
page (Settings ▸ Licenses).

Flutter bundles the font files **unmodified** (it does not subset/alter text
fonts at build time — only icon fonts are tree-shaken), so no modification of
the font files occurs.

## Outfit
- Files: `Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf`,
  `Outfit-Bold.ttf`, `Outfit-ExtraBold.ttf` (weights 400/500/600/700/800)
- Copyright 2021 The Outfit Project Authors — https://github.com/Outfitio/Outfit-Fonts
- **Reserved Font Name: Outfit**
- License: SIL OFL 1.1 — full text in `Outfit-OFL.txt`.
- **App-wide default for all non-Korean locales** (Latin).

## Paperlogy
- Files: `Paperlogy-Regular.ttf`, `Paperlogy-Bold.ttf`, `Paperlogy-ExtraBold.ttf`
  (weights 400/700/800)
- Sandoll — covers Hangul + Latin.
- License: SIL OFL 1.1 — full text in `Paperlogy-OFL.txt`.
- **Default for the Korean locale.**

## Pretendard
- Files: `Pretendard-Regular.otf`, `Pretendard-Bold.otf` (Regular 400 / Bold 700)
- Copyright (c) 2021, Kil Hyung-jin — https://github.com/orioncactus/pretendard
- **Reserved Font Name: Pretendard**
- License: SIL OFL 1.1 — full text in `Pretendard-OFL.txt`.
- **Glyph fallback** for both default faces (covers Latin + Hangul); also a
  dev-only font-picker option.
