plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0"
    id("com.android.library") version "8.10.1"
}
val verifyFileActions = providers.gradleProperty("verifyFileActions").orElse("false").get().toBoolean()
kotlin {
    val systemActionsVersion = providers.gradleProperty("systemActionsVersion").orElse("0.2.0-rc.5").get()
    androidTarget()
    iosArm64()
    iosX64 { binaries.framework { baseName = "SystemActionsConsumer" } }
    iosSimulatorArm64 { binaries.framework { baseName = "SystemActionsConsumer" } }
    ohosArm64()
    sourceSets {
        if (verifyFileActions) {
            commonMain.get().kotlin.srcDir("src/fileActionsMain/kotlin")
            androidMain.get().kotlin.srcDir("src/fileActionsAndroidMain/kotlin")
            iosMain.get().kotlin.srcDir("src/fileActionsIosMain/kotlin")
        }
        commonMain.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-core:$systemActionsVersion") }
        ohosArm64Main.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion") }
    }
}
android { namespace = "io.github.gycrosskit.systemactions.consumer"; compileSdk = 36; defaultConfig { minSdk = 24 } }
