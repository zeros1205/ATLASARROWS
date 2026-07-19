import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/boot/boot_screen.dart';
import 'app_settings.dart';
import 'theme.dart';

/// Root of the app: applies the light/dark themes and locale from
/// [AppSettings], and shows a temporary landing until the real screens land.
class ZArrowsApp extends StatelessWidget {
  const ZArrowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final locale = settings.locale;
        return MaterialApp(
          title: 'Atlas Arrows',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: buildTheme(Brightness.light, locale),
          darkTheme: buildTheme(Brightness.dark, locale),
          locale: locale,
          supportedLocales: AppSettings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const BootScreen(),
        );
      },
    );
  }
}
