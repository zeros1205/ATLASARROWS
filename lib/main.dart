import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_settings.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSettings.instance.load();
    runApp(const ZArrowsApp());
  }, (error, stack) {
    // Surfaces minified web-release startup failures in the console.
    debugPrint('FATAL: $error\n$stack');
  });
}
