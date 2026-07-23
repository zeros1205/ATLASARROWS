import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that affect the whole widget tree: theme mode and
/// locale. Persisted to shared_preferences. Language policy: one setting =
/// one language for the entire UI (no mixing).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kTheme = 'app.themeMode';
  static const _kLocale = 'app.locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale? _locale; // null = follow system among supported

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  /// Seven service languages, chosen for this genre's highest-value markets
  /// (Chinese, Russian and Italian were dropped). Pretendard carries Latin and
  /// Hangul; Japanese kana/kanji falls through to the platform CJK font, which
  /// Pretendard doesn't cover. Portuguese ships the Brazilian variant.
  static final supportedLocales = <Locale>[
    const Locale('en'),
    const Locale('de'),
    const Locale('fr'),
    const Locale('ja'),
    const Locale('ko'),
    const Locale('pt'),
    const Locale('es'),
  ];

  /// Native language names (autonyms) for the language picker, keyed by
  /// language code.
  static const languageNames = <String, String>{
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'ja': '日本語',
    'ko': '한국어',
    'pt': 'Português (Brasil)',
    'es': 'Español',
  };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_kTheme)) {
      case 'dark':
        _themeMode = ThemeMode.dark;
      case 'light':
        _themeMode = ThemeMode.light;
      default:
        _themeMode = ThemeMode.light;
    }
    final loc = p.getString(_kLocale);
    if (loc != null) _locale = Locale(loc);
  }

  Future<void> setDarkMode(bool on) async {
    _themeMode = on ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, on ? 'dark' : 'light');
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, locale.languageCode);
  }
}
