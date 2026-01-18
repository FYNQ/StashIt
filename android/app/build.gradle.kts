plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}



fun env(name: String) = System.getenv(name)?.trim()
fun prop(name: String) = keystoreProperties.getProperty(name)?.trim()

android {
    namespace = "com.fynq.stashr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fynq.stashr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {

            val storeFilePath = keystoreProperties.getProperty("storeFile")
			if (!storeFilePath.isNullOrEmpty()) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
			/*
            val storePath = env("KEYSTORE_FILE") ?: prop("storeFile")
            require(!storePath.isNullOrBlank()) {
                "Signing error: Missing KEYSTORE_FILE env var (or storeFile in key.properties)"
            }
            storeFile = file(storePath)

            val sp = env("KEYSTORE_PASSWORD") ?: prop("storePassword")
            require(!sp.isNullOrBlank()) { "Signing error: Missing KEYSTORE_PASSWORD (or storePassword)" }
            storePassword = sp

            val ka = env("KEY_ALIAS") ?: prop("keyAlias")
            require(!ka.isNullOrBlank()) { "Signing error: Missing KEY_ALIAS (or keyAlias)" }
            keyAlias = ka

            val kp = env("KEY_PASSWORD") ?: prop("keyPassword") ?: sp
            require(!kp.isNullOrBlank()) { "Signing error: Missing KEY_PASSWORD (or keyPassword)" }
            keyPassword = kp

            // Optional debug print (masks sensitive data)
            println("Signing -> file=${storeFile}, alias=$ka, pwdLen=${sp.length}, keyPwdLen=${kp.length}")

			*/
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}


flutter {
    source = "../.."
}
