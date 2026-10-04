# GY CrossKit System Actions

为 Android、iOS 和 HarmonyOS 提供拨号、HTTP(S) 外链、应用设置、定位设置及商店详情跳转；`0.2.0-rc.1` 本地候选新增原生 Window 策略。宿主提供商店 URL、业务域名白名单和提示文案；库不绑定品牌包名或厂商商店优先级。

## 平台与模块

| 模块 | 平台与要求 |
| --- | --- |
| `system-actions-core` | Android API 24+ / iOS（宿主基线 iOS 14+）；公共 `SystemActions` 与原生实现 |
| `system-actions-kuikly` | OHOS Kotlin Module；Kuikly `2.28.0-2.0.21-ohos` |
| `@gycrosskit/system-actions-native` | HarmonyOS API 22 兼容 HAR；原生 ArkTS 和 Kuikly Renderer Module，render `2.28.0` |

KMP 工具链基线为 OpenHarmony Kotlin `2.2.21-1.0.0` / JDK 17 / Gradle 8.11.1 / AGP 8.10.1。iOS 编译链接需 macOS / Xcode，OHOS 需匹配 Native SDK。Core 的 OHOS 和 JVM 变体仅包含公共 API；JVM 不提供桌面系统动作。

## Window 策略候选

`0.2.0-rc.1` 尚未发布，不可把以下候选 API 当作已上架能力。Android Core 提供常亮和 `FLAG_SECURE` lease；iOS 原生 `GYCWindowPolicy` Swift Package / Git Pod 提供常亮和录屏/镜像黑遮罩；OHOS HAR 提供窗口 privacy lease。iOS 使用公开 UIKit，无法阻止静态截图；OHOS 本轮只抽离 privacy，不提供常亮、全屏、方向或系统栏控制。业务录屏授权由宿主输入，UI、导航和 Shared 协议留在宿主。

Android 候选坐标为 `com.github.gycrosskit.system-actions:system-actions-core:0.2.0-rc.1`，Android API 24+，不依赖 Compose。Swift Package 位于仓库根目录，product `GYCWindowPolicy`，iOS 14+、Swift 5.9，无 KMP/Shared 依赖；同源码 `GYCWindowPolicy.podspec` 支持宿主已有 CocoaPods 工作流。HAR 候选坐标为 `@gycrosskit/system-actions-native@0.2.0-rc.1`，HarmonyOS API 22。发布前仅使用本地 staging / 本地 Git Package / 本地 Pod / 打包 HAR 验证。

```kotlin
val lease = AndroidWindowPolicy.acquire(activity.window) // 主线程，默认常亮且禁录
lease.update(screenRecordingAllowed = true)
lease.close() // 最后一个 owner 释放后恢复进入前的 flags
```

```swift
import GYCWindowPolicy
// 在 MainActor；宿主提供当前 Window resolver。
let policy = WindowPolicyController { hostWindow }
let lease = policy.acquire()
lease.update(screenRecordingAllowed: true)
lease.end()
```

```typescript
import { WindowPolicyController, window } from '@gycrosskit/system-actions-native';
const lease = WindowPolicyController.shared.createLease(() => window.getLastWindow(context));
await lease.update(false); // 必须成功后才展示视频
await lease.update(true);
await lease.release();
```

多 owner 与异步释放、Swift/CocoaPods 接线和限制见[接入指南](docs/接入指南.md#window-策略候选)。本地验证方法见[开发与验证](docs/开发与验证.md#window-策略候选验证)。

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
            implementation("com.github.gycrosskit.system-actions:system-actions-core:0.1.3")
        }
    }
}
```

HarmonyOS 原生宿主：

```sh
ohpm install @gycrosskit/system-actions-native@0.1.1
```

Kotlin 插件仓库及 Kuikly 双侧注册见[接入指南](docs/接入指南.md)。Maven `0.1.3` 和 HAR 分别发布；上述 OHPM 命令对应当前公开上架的 `0.1.1`。

原生商店增强已发布 [Maven `0.1.3`](https://github.com/gycrosskit/system-actions/releases/tag/0.1.3)，JitPack 构建成功。[HAR `0.1.2` 归档](https://github.com/gycrosskit/system-actions/releases/tag/har-0.1.2)独立发布，OHPM 已接受提交、审核中；Registry 精确 `0.1.2` 安装仍返回 `NOTFOUND`。审核通过前可下载归档、校验 Release `SHA256SUMS` 后临时安装验证；不能视为 Registry 上架验收。API 与回执边界见接入指南。

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

还支持 `dial(phone)`、`openAppSettings()`、`openLocationSettings()`、`openAppStore(listingUrl)`；新增 `openNativeAppStore(applicationId = null)`。`Requested` 仅表示系统受理，`InvalidInput` 表示输入拒绝，`Unavailable` 表示无法打开。ArkTS 的对应状态为 `requested` / `invalid_input` / `unavailable`。

原生商店使用当前应用标识或宿主显式传入的 applicationId/bundleName：Android 优先匹配设备厂商商店，再尝试固定第三方商店；OHOS 使用 AppGallery `loadProduct` 并等待 `onAppear`，iOS 返回 `Unavailable`。业务商店 URL 和升级决策继续由宿主提供。取消和超时结束等待，不能关闭 SDK 已显示的商店页面。

Android 拨号使用 `ACTION_DIAL`，不申请直接呼叫权限。定位服务设置仅支持 Android；iOS/OHOS 返回不可用。商店地址只接受 HTTP(S)，可能由商店或浏览器处理；系统调用取消后无法撤回已打开页面。

输入格式、平台回执和 Kuikly 页面 `dispose()` 边界见接入指南。

## 文档与支持

- [接入指南](docs/接入指南.md)：三端 API、输入规则、主线程和 Kuikly 生命周期。
- [开发与验证](docs/开发与验证.md)、[历史验收记录](verification/验收记录.md)：源码验证与独立消费。
- [远程发布验收](verification/远程发布验收.md)：Maven `0.1.3` 远程消费与 HAR `0.1.2` 审核边界。
- [GitHub Releases](https://github.com/gycrosskit/system-actions/releases)：Maven / HAR 版本和归档。
- [GitHub Issues](https://github.com/gycrosskit/system-actions/issues)：提供平台、版本、输入和最小复现。

已有记录覆盖 Android/iOS/OHOS 远程产物消费、iOS Simulator Framework 链接、OHPM Registry 安装与 HAR 编译；真实系统页面和 Kuikly 设备交互仍待验收。

自有源码使用 [Apache-2.0](LICENSE)，第三方依赖遵循各自许可。
