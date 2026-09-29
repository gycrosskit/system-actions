plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0"
    id("com.android.library") version "8.10.1"
}
kotlin {
    androidTarget()
    iosArm64()
    iosX64()
    iosSimulatorArm64 { binaries.framework { baseName = "SystemActionsConsumer" } }
    sourceSets.commonMain.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-core:0.1.0") }
}
android { namespace = "io.github.gycrosskit.systemactions.consumer"; compileSdk = 36; defaultConfig { minSdk = 24 } }
