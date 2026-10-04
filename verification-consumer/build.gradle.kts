plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0"
    id("com.android.library") version "8.10.1"
}
kotlin {
    val systemActionsVersion = providers.gradleProperty("systemActionsVersion").orElse("0.2.0-rc.3").get()
    androidTarget()
    iosArm64()
    iosX64()
    iosSimulatorArm64 { binaries.framework { baseName = "SystemActionsConsumer" } }
    ohosArm64()
    sourceSets {
        commonMain.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-core:$systemActionsVersion") }
        ohosArm64Main.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion") }
    }
}
android { namespace = "io.github.gycrosskit.systemactions.consumer"; compileSdk = 36; defaultConfig { minSdk = 24 } }
