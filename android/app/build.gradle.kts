plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services para Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "br.com.snapdark.apps.nutreai"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.snapdark.apps.nutreai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = 10
        versionName = "1.0.8"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("C:\\Users\\Fabiano\\Documents\\AndroidStudioProjects\\whatlisten2019-master\\android_keys\\studyai.jks")
            storePassword = "IamTheBest@2"
            keyAlias = "studyai"
            keyPassword = "IamTheBest@2"
        }
    }

    buildTypes {
        release {
            // Configurando para usar a assinatura de release
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // Habilitar o uso do R8 para otimização de código
    buildFeatures {
        buildConfig = true
    }
    
    // Configuração moderna para excluir arquivos desnecessários no pacote
    packaging {
        resources {
            excludes += listOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/DEPENDENCIES",
                "META-INF/*.kotlin_module",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Adiciona appcompat para resolver problema de lStar
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
