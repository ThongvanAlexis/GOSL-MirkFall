plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.gosl.mirkfall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required by `flutter_local_notifications` 21.0.0 at
        // AGP 8.x: the plugin uses `java.time` APIs that need backporting for minSdk < 26.
        // See https://pub.dev/packages/flutter_local_notifications#-android-setup.
        // `desugar_jdk_libs` 2.1.4 is the version bundled with AGP 8.x as of 2026-04.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.gosl.mirkfall"
        // Plan 01-01 pins minSdk to 24 (Android 7.0) to unlock features relied
        // on in later phases (background location, notifications-v2 APIs).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by `isCoreLibraryDesugaringEnabled = true` above. Pinned per
    // CLAUDE.md §Pin des versions (no `+`, no wildcard).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
