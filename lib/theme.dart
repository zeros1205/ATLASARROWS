import 'dart:ui';

/// Atlas Arrows visual identity: paper-like off-white board with off-black
/// ink lines — the maze itself is the graphic. Color only speaks on
/// action: blue while a line escapes, red on a mistake.
abstract final class ZTheme {
  static const bg = Color(0xFFF7F6F2); // off-white paper
  static const ink = Color(0xFF23252E); // off-black lines & headings
  static const inkSoft = Color(0xFF9A9DAB); // secondary text
  static const accent = Color(0xFF2F6BFF); // escaping line, buttons
  static const danger = Color(0xFFFF4D67); // hearts, blocked flash
  static const dot = Color(0xFFE4E3DD); // faint dots on empty cells
  static const card = Color(0xFFFFFFFF); // overlay cards
}
