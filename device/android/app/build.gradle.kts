plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.aiq.ongi.device"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.aiq.ongi.device"
        minSdk = 33
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = true
                packageScope = setOf("androidx.**", "kotlin.**", "kotlinx.**")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

android {
    // Genie·QNN 라이브러리를 압축하지 않고 풀어 둠(libGenie가 libQnnHtp.so 등을 이름으로 찾음)
    packaging { jniLibs { useLegacyPackaging = true } }
}

dependencies {
    implementation("org.java-websocket:Java-WebSocket:1.5.7")
    // DEV-08 임베딩 판단: MiniLM(ONNX). 토크나이저는 앱 안 UnigramTokenizer로 직접 계산
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")

    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.core.ktx)
    implementation(libs.material)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
}