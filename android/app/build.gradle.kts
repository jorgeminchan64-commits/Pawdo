import java.io.FileInputStream
import java.util.Properties
import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val skipCrashlyticsMappingUpload = providers
    .gradleProperty("pawdoSkipCrashlyticsMappingUpload")
    .orNull
    .toBoolean()
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(::load)
    }
}

android {
    namespace = "com.pawdo.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.pawdo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("Missing keyAlias in android/key.properties")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("Missing keyPassword in android/key.properties")
                storeFile = file(
                    keystoreProperties.getProperty("storeFile")
                        ?: error("Missing storeFile in android/key.properties"),
                )
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("Missing storePassword in android/key.properties")
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            configure<CrashlyticsExtension> {
                // Local/offline builds may skip only the network upload. The
                // generated mapping file and Crashlytics runtime stay intact.
                mappingFileUploadEnabled = !skipCrashlyticsMappingUpload
            }
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.13.0"))
}
