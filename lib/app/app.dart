import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_settings.dart';
import 'theme.dart';
import 'tokens/colors.dart';
import 'tokens/typography.dart';

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
          title: 'Z-Arrows',
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
          home: const _Landing(),
        );
      },
    );
  }
}

/// Temporary themed landing — proves tokens/fonts/theme render. Replaced by
/// the real shell (home/map/shop/settings) in the next task.
class _Landing extends StatelessWidget {
  const _Landing();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Z'),
              TextSpan(text: '·', style: TextStyle(color: c.accent)),
              const TextSpan(text: 'ARROWS'),
            ]), style: AppText.display.copyWith(
                color: c.ink, fontSize: 40, letterSpacing: -1)),
            const SizedBox(height: 6),
            Text('SHIFT THE ARROWS',
                style: AppText.caption.copyWith(
                    color: c.inkFaint, letterSpacing: 2.5)),
          ],
        ),
      ),
    );
  }
}
