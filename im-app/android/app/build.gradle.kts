plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yourcompany.im_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yourcompany.im_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 极光推送 SDK 必需占位符（jpush_flutter 插件 manifest 合并时读取）：
        // TODO: 替换成极光控制台（包名必须与本 applicationId 一致）创建应用的 AppKey
        // 注意：AGP 9 的 Kotlin DSL 里 applicationId 是 String?，必须 toString() 转 Any
        manifestPlaceholders["JPUSH_PKGNAME"] = applicationId.toString()
        manifestPlaceholders["JPUSH_APPKEY"] = "REPLACE_WITH_JPUSH_APPKEY"
        manifestPlaceholders["JPUSH_CHANNEL"] = "default"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
