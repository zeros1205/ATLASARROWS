import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loganland_boot/loganland_boot.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'app/boot.dart';

/// Sentry DSN, injected at build time via `--dart-define=SENTRY_DSN=...`. Left
/// empty in development and in any build without the secret — Sentry then
/// initializes as a no-op and transmits nothing, so a missing DSN is a
/// supported state, not a blocker (the same way Firebase and the ad units
/// degrade when their config is absent).
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  // Sentry owns the error zone and installs the Flutter + native crash
  // handlers, so its appRunner replaces the hand-rolled runZonedGuarded that
  // used to wrap runApp. With no DSN it still runs the app, just silently.
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'debug';
      // Crash + error reporting only. Performance tracing stays off so we don't
      // spend quota or frame budget on traces until we actually want them.
      options.tracesSampleRate = 0;
    },
    appRunner: () {
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
          builder: (context, _) => const AtlasArrowsApp(),
          onBooted: (_) => initDeferredServices(),
        ),
      );
    },
  );
}
