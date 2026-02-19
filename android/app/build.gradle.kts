import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "wtf.sono.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" //THIS VERSION IS REQUIRED AND SHOULD NOT BE CHANGED

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "wtf.sono.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    flavorDimensions += "version"
    productFlavors {
        create("stable") {
            dimension = "version"
            applicationIdSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Sono"
            manifestPlaceholders["mainActivity"] = "wtf.sono.app.MainActivity"
        }
        create("beta") {
            dimension = "version"
            applicationIdSuffix = ".beta"
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Sono Beta"
            manifestPlaceholders["mainActivity"] = "wtf.sono.app.beta.MainActivity"
        }
        create("nightly") {
            dimension = "version"
            applicationIdSuffix = ".nightly"
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Sono Nightly"
            manifestPlaceholders["mainActivity"] = "wtf.sono.app.nightly.MainActivity"
        }
    }

    signingConfigs {
        getByName("debug") {
            //default debug signing config
        }

        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }
}

afterEvaluate {
    android.applicationVariants.configureEach {
        val flavorName = productFlavors.firstOrNull()?.name ?: return@configureEach
        val mainGoogleServices = file("src/main/google-services.json")
        val flavorGoogleServices = file("src/$flavorName/google-services.json")

        if (mainGoogleServices.exists() && !flavorGoogleServices.exists()) {
            flavorGoogleServices.parentFile.mkdirs()
            mainGoogleServices.copyTo(flavorGoogleServices)
        }

        val variantName = name.replaceFirstChar { it.uppercase() }
        val hasConfig = flavorGoogleServices.exists() || file("google-services.json").exists()
        if (!hasConfig) {
            tasks.findByName("process${variantName}GoogleServices")?.enabled = false
            logger.warn("Firebase disabled for variant '$name'; google-services.json not found")
        }
    }
}

flutter {
    source = "../.."
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
