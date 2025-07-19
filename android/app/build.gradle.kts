plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.demo"
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
        applicationId = "com.example.demo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Your existing debug signing config
        create("debugConfig") { // Renamed to avoid conflict with default 'debug' name
            keyAlias = "key0"
            keyPassword = "ajinkya"
            storeFile = file("upload-keystore.jks")
            storePassword = "ajinkya"
        }
        // Explicit release signing config (can be the same keystore for testing)
        create("releaseConfig") {
            keyAlias = "key0" // Use the same alias as debug for simplicity in testing
            keyPassword = "ajinkya"
            storeFile = file("upload-keystore.jks")
            storePassword = "ajinkya"
        }
    }

    buildTypes {
        getByName("debug") {
            // Apply your custom debug signing config
            signingConfig = signingConfigs.getByName("debugConfig")
        }
        getByName("release") {
            // Apply your release signing config
            signingConfig = signingConfigs.getByName("releaseConfig")
            // Other release specific settings can go here (e.g., minify, shrinkResources)
            // minifyEnabled true
            // shrinkResources true
        }
    }
}

flutter {
    source = "../.."
}