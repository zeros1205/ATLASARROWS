import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase is opt-in: the google-services plugin hard-fails when
// google-services.json is missing, which would break every build for anyone
// who hasn't run the console setup yet. Applying it conditionally keeps the
// project buildable before Firebase exists and wires itself up the moment the
// file is dropped in. See docs/FIREBASE.md.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "Firebase: android/app/google-services.json not found — building without Firebase."
    )
}

// Release signing material, resolved in this order:
//   1. android/key.properties          — local release builds (git-ignored)
//   2. ANDROID_KEYSTORE_* env vars     — CI, where the keystore is decoded
//                                        from a secret into a temp file
//   3. nothing                         — falls back to debug signing so
//                                        `flutter run --release` still works
// See docs/RELEASE.md for how to produce the keystore and the CI secrets.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun signing(property: String, env: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(env)

val storeFilePath = signing("storeFile", "ANDROID_KEYSTORE_PATH")
val hasReleaseSigning = storeFilePath != null && file(storeFilePath).exists()

android {
    namespace = "com.loganland.atlasarrows"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.loganland.atlasarrows"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(storeFilePath!!)
                storePassword = signing("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signing("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signing("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Play rejects debug-signed uploads, so a store build MUST resolve
            // real signing material. The debug fallback exists only so local
            // `flutter run --release` works without a keystore.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
