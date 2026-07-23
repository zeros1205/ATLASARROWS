package com.loganland.atlasarrows

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Play Games v2 requires this before any GamesSignInClient call
    // (isAuthenticated/signIn). Without it, silent sign-in restore never
    // works and every launch — even relaunching the same install — falls
    // through to the interactive account-picker sheet.
    override fun onCreate(savedInstanceState: Bundle?) {
        PlayGamesSdk.initialize(this)
        super.onCreate(savedInstanceState)
    }
}
