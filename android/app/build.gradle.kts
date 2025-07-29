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

        // Performance optimizations
        multiDexEnabled = true
        vectorDrawables.useSupportLibrary = true

        // Enable hardware acceleration and optimize rendering
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
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
            // Debug performance optimizations
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            // Apply your release signing config
            signingConfig = signingConfigs.getByName("releaseConfig")
            // Release performance optimizations
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // Additional performance settings
            isDebuggable = false
            isJniDebuggable = false
            isRenderscriptDebuggable = false
        }
    }

    // Additional performance optimizations
    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}