plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0" apply false
    id("com.android.library") version "8.10.1" apply false
}
allprojects {
    group = "com.github.gycrosskit.system-actions"
    version = providers.environmentVariable("VERSION").orElse("0.1.2").get()
}
