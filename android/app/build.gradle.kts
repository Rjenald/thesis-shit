plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.final_thesis_ui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

  defaultConfig {
    applicationId = "com.example.final_thesis_ui"

    // Flutter-managed values
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName

    // Required for TensorFlow Lite native libraries
    ndk {
        abiFilters += listOf("armeabi-v7a", "arm64-v8a")
    }
}

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

  aaptOptions {
    noCompress += listOf("tflite", "lite")
}


}

flutter {
    source = "../.."
}

ndk {
    abiFilters "armeabi-v7a", "arm64-v8a"
}
