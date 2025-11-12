import java.util.Properties

plugins {
    id("com.android.application")
    // Firebase Google Services (version declared in settings.gradle.kts)
    id("com.google.gms.google-services")
    // Kotlin Android (use modern plugin id)
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        load(keystorePropsFile.inputStream())
    }
}

android {
    // Use your real package
    namespace = "com.allcare.allcare"

    // Let Flutter pin the SDKs (these resolve to API 34 / NDK set by Flutter)
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        // Your Play/App id
        applicationId = "com.allcare.allcare"

        // Inherit from Flutter (minSdk should be >= 23 by default)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Bump these for each store release
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // If you prefer explicit numbers:
        // versionCode = 1
        // versionName = "1.0.0"
    }

    // AGP 8+ requires Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        jniLibs {
            // Keep symbols in native .so files, so Gradle doesn’t try to strip them
            keepDebugSymbols += setOf("**/*.so")
        }
    }

    signingConfigs {
        create("release") {
            // Reads from android/key.properties
            storeFile = keystoreProps["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProps["storePassword"] as String?
            keyAlias = keystoreProps["keyAlias"] as String?
            keyPassword = keystoreProps["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            // Sign with your release key
            signingConfig = signingConfigs.getByName("release")

            // Shrink & optimize for Play
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // keep default debug signing
        }
    }

    // If you ever hit duplicate META-INF files, uncomment:
    // packaging {
    //     resources {
    //         excludes += "/META-INF/{AL2.0,LGPL2.1}"
    //     }
    // }
}

flutter {
    source = "../.."
}

// You usually don't need extra "dependencies { ... }" here because FlutterFire
// plugins add their native deps automatically. If you want to add Crashlytics/Perf
// at the native layer, do it here using the Firebase BOM.
