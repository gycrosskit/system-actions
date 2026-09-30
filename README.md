# GY CrossKit System Actions

为 Android、iOS 和 HarmonyOS 提供拨号、HTTP(S) 外链、应用设置、定位设置及商店详情跳转。宿主提供商店 URL、业务域名白名单和提示文案；库不绑定品牌包名或厂商商店优先级。

## 平台与模块

| 模块 | 平台与要求 |
| --- | --- |
| `system-actions-core` | Android API 24+ / iOS（宿主基线 iOS 14+）；公共 `SystemActions` 与原生实现 |
| `system-actions-kuikly` | OHOS Kotlin Module；Kuikly `2.28.0-2.0.21-ohos` |
| `@gycrosskit/system-actions-native` | HarmonyOS API 22 兼容 HAR；原生 ArkTS 和 Kuikly Renderer Module，render `2.28.0` |

KMP 工具链基线为 OpenHarmony Kotlin `2.2.21-1.0.0` / JDK 17 / Gradle 8.11.1 / AGP 8.10.1。iOS 编译链接需 macOS / Xcode，OHOS 需匹配 Native SDK。Core 的 OHOS 和 JVM 变体仅包含公共 API；JVM 不提供桌面系统动作。

## 安装

项目 `settings.gradle.kts` 的依赖仓库：

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://maven.eazytec-cloud.com/nexus/repository/maven-public/") }
        maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-tencent/") }
    }
}
```

共享模块 `build.gradle.kts`：

```kotlin
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation("com.github.gycrosskit.system-actions:system-actions-core:0.1.2")
        }
    }
}
```

HarmonyOS 原生宿主：

```sh
ohpm install @gycrosskit/system-actions-native@0.1.1
```

Kotlin 插件仓库及 Kuikly 双侧注册见[接入指南](docs/接入指南.md)。Maven `0.1.2` 和 HAR `0.1.1` 分别发布。

本次原生商店增强的候选为 Maven `0.1.3` / HAR `0.1.2`，仅在本地 staging 打包验证；上述远程安装命令仍对应已发布版本。候选 API 与回执边界见接入指南，正式发布前需使用外部临时仓库注入消费。

## 快速使用

Android 在 `androidMain` 创建实现：

```kotlin
import io.github.gycrosskit.systemactions.AndroidSystemActions
val actions = AndroidSystemActions(context)
```

iOS 在 `iosMain` 使用 `IosSystemActions()`。共享业务在宿主协程中调用：

```kotlin
import io.github.gycrosskit.systemactions.ActionResult
import io.github.gycrosskit.systemactions.SystemActions

suspend fun openHelp(actions: SystemActions): ActionResult =
    actions.openExternalUrl("https://example.com/help")
```

还支持 `dial(phone)`、`openAppSettings()`、`openLocationSettings()`、`openAppStore(listingUrl)`；候选新增 `openNativeAppStore(applicationId = null)`。`Requested` 仅表示系统受理，`InvalidInput` 表示输入拒绝，`Unavailable` 表示无法打开。ArkTS 的对应状态为 `requested` / `invalid_input` / `unavailable`。

原生商店使用当前应用标识或宿主显式传入的 applicationId/bundleName：Android 优先匹配设备厂商商店，再尝试固定第三方商店；OHOS 使用 AppGallery `loadProduct` 并等待 `onAppear`，iOS 返回 `Unavailable`。业务商店 URL 和升级决策继续由宿主提供。取消和超时结束等待，不能关闭 SDK 已显示的商店页面。

Android 拨号使用 `ACTION_DIAL`，不申请直接呼叫权限。定位服务设置仅支持 Android；iOS/OHOS 返回不可用。商店地址只接受 HTTP(S)，可能由商店或浏览器处理；系统调用取消后无法撤回已打开页面。

输入格式、平台回执和 Kuikly 页面 `dispose()` 边界见接入指南。

## 文档与支持

- [接入指南](docs/接入指南.md)：三端 API、输入规则、主线程和 Kuikly 生命周期。
- [开发与验证](docs/开发与验证.md)、[历史验收记录](verification/验收记录.md)：源码验证与独立消费。
- [GitHub Releases](https://github.com/gycrosskit/system-actions/releases)：Maven / HAR 版本和归档。
- [GitHub Issues](https://github.com/gycrosskit/system-actions/issues)：提供平台、版本、输入和最小复现。

已有记录覆盖 Android/iOS/OHOS 远程产物消费、iOS Simulator Framework 链接、OHPM Registry 安装与 HAR 编译；真实系统页面和 Kuikly 设备交互仍待验收。

自有源码使用 [Apache-2.0](LICENSE)，第三方依赖遵循各自许可。
