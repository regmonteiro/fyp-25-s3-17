pluginManagement {
    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://jitpack.io") }

    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // add Flutter's Maven so the Flutter plugin doesn't try to add it later
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        gradlePluginPortal()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") } // Flutter artifacts
        maven { url = uri("https://jitpack.io") } // <-- needed for com.github.* deps like audioswitch
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
