import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Per ULTIMATE.md §2.1 / §19.1 — secrets are loaded from gitignored
// local.properties (or CI env vars), never hardcoded in the manifest.
// Add `MAPS_API_KEY=...` to android/local.properties for local builds.
// CI sets it via `-PMAPS_API_KEY=...` or an env var injected before build.
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(FileInputStream(f))
}
val mapsApiKey: String =
    (findProperty("MAPS_API_KEY") as String?)
        ?: localProps.getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

// Per ULTIMATE.md §19.14 — release builds must NOT be signed with the
// debug keystore. android/key.properties is gitignored and contains the
// upload-keystore path + passwords. If it's missing (e.g. CI without the
// secret), the release signingConfig is left null and `flutter build apk
// --release` will fail loudly, which is the desired behavior.
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasReleaseKeystore: Boolean = keystoreProps.getProperty("storeFile") != null

android {
    namespace = "com.rahul.kathmanduhiker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rahul.kathmanduhiker"
        // Firebase Auth + Storage need ≥23. flutter_background_service requires ≥21.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val storeFilePath = keystoreProps.getProperty("storeFile")
                storeFile = file(storeFilePath)
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // ULTIMATE.md §19.14 — never ship debug-signed builds. If
            // key.properties is absent the release config is null and the
            // build fails fast, which is what we want.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            // ULTIMATE.md §4.4 / §11.1 — shrink + minify + remove resources.
            // Flutter and the Firebase / Maps / Google Sign-In plugins ship
            // their own consumer ProGuard rules, so the default app rules
            // file is intentionally minimal. If you hit a release-only crash
            // (typically a "ClassNotFoundException" via reflection), add a
            // -keep rule in proguard-rules.pro for the affected class.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
