plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0"
    id("com.android.library") version "8.10.1"
}
val verifyFileActions = providers.gradleProperty("verifyFileActions").orElse("false").get().toBoolean()
val systemActionsVersion = providers.gradleProperty("systemActionsVersion").orElse("0.2.0-rc.7").get()
val verifyKuiklyNative = systemActionsVersion !in setOf("0.1.3", "0.2.0-rc.1", "0.2.0-rc.2", "0.2.0-rc.3", "0.2.0-rc.4", "0.2.0-rc.5", "0.2.0-rc.6")
val kuiklyRenderFrameworkDir = providers.gradleProperty("kuiklyRenderFrameworkDir").orNull
kotlin {
    androidTarget()
    iosArm64()
    iosX64 { binaries.framework {
        baseName = "SystemActionsConsumer"
        if (verifyKuiklyNative) kuiklyRenderFrameworkDir?.let { linkerOpts("-F$it", "-framework", "OpenKuiklyIOSRender") }
        export("com.github.gycrosskit.system-actions:system-actions-core:$systemActionsVersion")
        if (verifyKuiklyNative) export("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion")
    } }
    iosSimulatorArm64 { binaries.framework {
        baseName = "SystemActionsConsumer"
        if (verifyKuiklyNative) kuiklyRenderFrameworkDir?.let { linkerOpts("-F$it", "-framework", "OpenKuiklyIOSRender") }
        export("com.github.gycrosskit.system-actions:system-actions-core:$systemActionsVersion")
        if (verifyKuiklyNative) export("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion")
    } }
    ohosArm64()
    sourceSets {
        if (verifyFileActions) {
            commonMain.get().kotlin.srcDir("src/fileActionsMain/kotlin")
            androidMain.get().kotlin.srcDir("src/fileActionsAndroidMain/kotlin")
            iosMain.get().kotlin.srcDir("src/fileActionsIosMain/kotlin")
        }
        commonMain.dependencies { api("com.github.gycrosskit.system-actions:system-actions-core:$systemActionsVersion") }
        if (verifyKuiklyNative) {
            commonMain.get().kotlin.srcDir("src/kuiklyNativeMain/kotlin")
            androidMain.get().kotlin.srcDir("src/kuiklyNativeAndroidMain/kotlin")
            iosMain.get().kotlin.srcDir("src/kuiklyNativeIosMain/kotlin")
            commonMain.dependencies { api("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion") }
        } else {
            ohosArm64Main.dependencies { implementation("com.github.gycrosskit.system-actions:system-actions-kuikly:$systemActionsVersion") }
        }
    }
}
android { namespace = "io.github.gycrosskit.systemactions.consumer"; compileSdk = 36; defaultConfig { minSdk = 24 } }
