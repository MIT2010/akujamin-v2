import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real gap, found 2026-07-17 from live testing: every `flavors/*.json`
// already carries an `APP_NAME` (e.g. "AKUJAMIN Dev"), but the
// `productFlavors` block below used to hardcode its own generic
// "Starter Kit (Dev)"-style labels instead -- completely disconnected
// from that config. `--dart-define-from-file` only reaches Dart code
// (see `Env.appName`), never this Gradle build, so the home-screen
// label needs its own read of the same JSON file. `flavors/*.json` is
// gitignored (real per-project config, not committed) -- falls back to
// the previous hardcoded label whenever the file doesn't exist yet
// (e.g. a fresh clone before the developer copies it from
// `flavors/*.example.json`), same "never assume it exists" caution
// `--dart-define-from-file` itself already requires.
fun appNameFrom(fileName: String, fallback: String): String {
    val flavorFile = file("../../../../flavors/$fileName")
    if (!flavorFile.exists()) return fallback
    return try {
        @Suppress("UNCHECKED_CAST")
        val json = JsonSlurper().parse(flavorFile) as Map<String, Any?>
        (json["APP_NAME"] as? String)?.takeIf { it.isNotEmpty() } ?: fallback
    } catch (e: Exception) {
        fallback
    }
}

android {
    namespace = "com.akujamin.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Separate, pre-existing bug found while verifying the `APP_NAME` fix
    // below with a real `flutter build apk --flavor dev`, 2026-07-17: AGP
    // 9.0.1 (pinned in settings.gradle.kts) defaults `resValues` to
    // `false`, and every `resValue(...)` call in `productFlavors` below
    // (present since this flavor setup was first written, unrelated to
    // this session's `APP_NAME` change) fails the build with "Product
    // Flavor ... contains custom resource values, but the feature is
    // disabled" the moment it's actually evaluated -- which nothing in
    // this migration ever had, since every prior verification ran on
    // Chrome web, never a real Android build.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.akujamin.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // §30: dev / staging / prod, each with its own applicationId suffix and
    // app name badge, driven by `flutter run/build --flavor <name>`.
    // https://docs.flutter.dev/deployment/flavors
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue(
                type = "string",
                name = "app_name",
                value = appNameFrom("development.json", "Starter Kit (Dev)"),
            )
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue(
                type = "string",
                name = "app_name",
                value = appNameFrom("staging.json", "Starter Kit (Staging)"),
            )
        }
        create("prod") {
            dimension = "environment"
            resValue(
                type = "string",
                name = "app_name",
                value = appNameFrom("production.json", "Starter Kit"),
            )
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
