import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loganland_boot/loganland_boot.dart';

import 'app/app.dart';
import 'app/boot.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Fullscreen: hide status + navigation bars; swipe reveals them briefly.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Nothing else goes here. Android's native splash disappears the moment
    // Flutter paints, so every await before runApp is time the player spends
    // looking at the OS's screen instead of ours — settings, progress and the
    // puzzle bank all load inside the gate, behind the LOGAN LAND card.
    runApp(
      LoganLandBootGate<void>(
        config: kBootConfig,
        bootstrap: bootServices,
        builder: (context, _) => const ZArrowsApp(),
        onBooted: (_) => initDeferredServices(),
      ),
    );
  }, (error, stack) {
    // Surfaces minified web-release startup failures in the console.
    debugPrint('FATAL: $error\n$stack');
  });
}
