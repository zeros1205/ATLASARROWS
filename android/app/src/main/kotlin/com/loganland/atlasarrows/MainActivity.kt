package com.loganland.atlasarrows

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Play Games v2 requires this before any GamesSignInClient call
    // (isAuthenticated/signIn) whenever the SDK's own auto-init
    // ContentProvider is removed (see AndroidManifest.xml) — call order and
    // pairing with the provider follow Google's official migration guide and
    // the games_services plugin's own "prevent auto sign-in" docs verbatim.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PlayGamesSdk.initialize(this)
    }
}
