plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    
    // THIS LINE MUST BE HERE AND NO OTHER 'plugins' BLOCK SHOULD EXIST
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.rikazapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Your confirmed Application ID
        applicationId = "com.example.rikazapp" 
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Any dependencies block should be here, *after* the android block.
dependencies {
    // This is optional but ensures that Google Sign-In and Firebase dependencies are available
    implementation(platform("com.google.firebase:firebase-bom:33.1.0")) 
}
