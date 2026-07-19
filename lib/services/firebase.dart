import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase bootstrap.
///
/// Initialization reads the **native** config files that the console hands
/// out — `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist` — so there is no generated
/// `firebase_options.dart` to keep in sync and no `flutterfire configure`
/// step in the build. Both files are git-ignored (they are per-project
/// identifiers, and the iOS one carries the API key).
///
/// Before those files exist, [init] fails and sets [available] to false. That
/// is a supported state: Firebase currently backs App Distribution and the
/// optional Play Games ↔ Firebase Auth link, neither of which gameplay needs.
///
/// Setup steps: `docs/FIREBASE.md`.
abstract final class FirebaseService {
  /// Web needs explicit options rather than a native config file, so it stays
  /// off until someone actually needs Firebase in the browser build.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// True once Firebase has initialized. Anything Firebase-backed must check
  /// this rather than assuming a default app exists.
  static final ValueNotifier<bool> available = ValueNotifier(false);

  static Future<void> init() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp();
      available.value = true;
    } catch (e) {
      // Expected until the console files are added — not an error state.
      available.value = false;
      if (kDebugMode) {
        debugPrint('Firebase not configured, continuing without it: $e');
      }
    }
  }
}
