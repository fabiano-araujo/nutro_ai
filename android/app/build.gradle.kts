plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.snapdark.apps.studyai"
    compileSdk = 35
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
        applicationId = "br.com.snapdark.apps.studyai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 3
        versionName = "1.0.1"
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
            isMinifyEnabled = false
            isShrinkResources = false
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
    // Adiciona apenas a dependência do Google ML Kit para reconhecimento de texto
    implementation("com.google.mlkit:text-recognition:16.0.0")
    
    // Adiciona appcompat para resolver problema de lStar
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // Novas bibliotecas específicas do Google Play
    implementation("com.google.android.play:feature-delivery:2.1.0")
    implementation("com.google.android.play:asset-delivery:2.1.0")
    implementation("com.google.android.play:review:2.0.1")
    implementation("com.google.android.play:app-update:2.1.0")
    // Versões Kotlin (KTX) das novas bibliotecas, se necessário
    implementation("com.google.android.play:feature-delivery-ktx:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
    implementation("com.google.android.play:review-ktx:2.0.1")
}

flutter {
    source = "../.."
}
