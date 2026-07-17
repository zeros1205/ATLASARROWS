import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ads/ads.dart';
import 'services/progress.dart';
import 'theme.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Progress.instance.load();
    await Ads.init();
    runApp(const ZArrowsApp());
  }, (error, stack) {
    // Surfaces minified web-release startup failures in the console.
    debugPrint('FATAL: $error\n$stack');
  });
}

class ZArrowsApp extends StatelessWidget {
  const ZArrowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z-Arrows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: ZTheme.bg,
        fontFamily: 'monospace',
      ),
      home: const HomeScreen(),
    );
  }
}
