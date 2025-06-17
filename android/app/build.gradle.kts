plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // 🔥 Plugin Firebase
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sae.ai_assistance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sae.ai_assistance"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
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

// 🔥 Dépendances Firebase - IMPORTANT: Ce bloc doit être en dehors du bloc android
dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    // 🔥 BoM Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.13.0"))
    // 🔐 Firebase Auth
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-analytics")
    // 👇 Ajoute d'autres services Firebase ici si besoin
}

