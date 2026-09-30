pluginManagement {
    repositories {
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        google(); mavenCentral(); gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        maven(providers.gradleProperty("systemActionsRepository").orElse("https://jitpack.io").get()) {
            content { includeGroup("com.github.gycrosskit.system-actions") }
        }
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        google(); mavenCentral()
        maven("https://mirrors.tencent.com/nexus/repository/maven-tencent/")
    }
}
rootProject.name = "system-actions-consumer"
