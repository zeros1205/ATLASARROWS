import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_settings.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Fullscreen: hide status + navigation bars; swipe reveals them briefly.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await AppSettings.instance.load();
    runApp(const ZArrowsApp());
  }, (error, stack) {
    // Surfaces minified web-release startup failures in the console.
    debugPrint('FATAL: $error\n$stack');
  });
}
