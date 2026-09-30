plugins { kotlin("multiplatform"); `maven-publish` }
kotlin {
    ohosArm64()
    sourceSets.commonMain.dependencies {
        api(project(":system-actions-core"))
        implementation("com.tencent.kuikly-open:core:2.28.0-2.0.21-ohos")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2-1.0.0")
    }
}
publishing { repositories { maven { name = "staging"; url = uri(rootProject.layout.buildDirectory.dir("maven")) } } }
