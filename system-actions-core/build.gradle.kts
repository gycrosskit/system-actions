plugins { kotlin("multiplatform"); id("com.android.library"); `maven-publish` }
kotlin {
    androidTarget { publishLibraryVariants("release") }
    iosArm64(); iosSimulatorArm64(); iosX64(); jvm(); ohosArm64()
    applyDefaultHierarchyTemplate()
    sourceSets {
        // URL 校验由各原生平台实现，OHOS 通过 HAR 处理，不复制平台解析器。
        val platformMain by creating {
            dependsOn(commonMain.get())
            dependencies { implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2") }
        }
        androidMain.get().dependsOn(platformMain)
        iosMain.get().dependsOn(platformMain)
        jvmMain.get().dependsOn(platformMain)
        androidMain.dependencies { implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2") }
        commonTest.dependencies { implementation(kotlin("test")) }
        androidUnitTest.dependencies {
            implementation("org.robolectric:robolectric:4.16")
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
        }
    }
}
android {
    namespace = "io.github.gycrosskit.systemactions"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    testOptions { unitTests.isIncludeAndroidResources = true }
}
publishing { repositories { maven { name = "staging"; url = uri(rootProject.layout.buildDirectory.dir("maven")) } } }
