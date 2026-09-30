# GY CrossKit System Actions

封装 Android、iOS、HarmonyOS 的拨号、HTTP(S) 外链、当前应用设置和商店详情跳转。商店详情 URL、业务域名白名单与提示文案由宿主提供；库不绑定品牌包名或厂商商店优先级。

Maven `0.1.2` 已发布：[GitHub Release](https://github.com/gycrosskit/system-actions/releases/tag/0.1.2)，JitPack 状态 `ok`，独立消费的Android、iOS arm64/x64 编译、iOS Simulator Framework 链接、OHOS 编译通过。 HAR `0.1.1` 已通过 OHPM 审核并上架，正式 Registry 精确版本安装和独立 assembleHar 已通过；GitHub Release HAR 已远程下载、SHA-256 校验、安装到独立工程并 assembleHar 成功。OHPM 不支持此 HAR URL 直接依赖，验收使用下载缓存的 file 依赖，另已使用正式 Registry 版本重新验收安装与编译。

## 平台与模块

- `system-actions-core/`：Android 24+ / iOS 14+ KMP API；依赖 Kotlin 2.2.21-1.0.0、kotlinx-coroutines 1.10.2；OHOS 变体只提供公共 API。
- `system-actions-kuikly/`：OHOS Kotlin Module，依赖 Kuikly 2.28.0-2.0.21-ohos、kotlinx-coroutines 1.10.2-1.0.0；Android/iOS 原生 API 不依赖 Kuikly。
- `ohos/system-actions-native/`：HarmonyOS API 22 SDK 构建的原生 HAR，包含 ArkTS SystemActions 和 Kuikly Renderer Module，依赖 @kuikly-open/render 2.28.0。
- `verification-consumer/`：独立 JitPack 消费构建。JVM 变体仅含公共 API 与校验，用于测试，不提供桌面系统动作。

许可证 Apache-2.0。

## Android / iOS

```kotlin
repositories { maven("https://jitpack.io") }
commonMain.dependencies {
    implementation("com.github.gycrosskit.system-actions:system-actions-core:0.1.2")
}
```

Android 使用 `AndroidSystemActions(context)`，iOS 使用 `IosSystemActions()`，通过 `SystemActions` 调用：

```kotlin
val result = actions.dial("+86 138-1234-5678")
actions.openExternalUrl("https://example.com/help")
actions.openAppSettings()
actions.openLocationSettings() // Android 系统定位服务设置；iOS 返回 Unavailable
actions.openAppStore(storeListingUrl) // 宿主提供对应平台的 HTTP(S) 详情地址
```

`ActionResult.Requested` 只代表系统已受理；`InvalidInput` 表示输入被拒绝；`Unavailable` 表示系统无法打开。Android 使用 ACTION_DIAL，不申请直接呼叫权限；iOS 等待 UIApplication completion 回执。Android Application Context 自动加新任务标记。系统动作均在主线程发起，协程取消不能撤回已经打开的系统页面。

拨号仅允许开头可选 `+`、数字及空格/括号/连字符，长度最多 31 位可见号码字符（不含开头 `+`）；拒绝 USSD、等待符和传入完整 tel URI。URL 必须包含 HTTP(S) 协议和有效主机，拒绝凭据、空白/控制字符、反斜线、无效转义及非法端口。国际化域名请提供 ASCII/Punycode URL。业务白名单必须由宿主在调用前检查。

`openLocationSettings()` 在 Android 使用 `Settings.ACTION_LOCATION_SOURCE_SETTINGS`，保留主线程、Application Context 的 NEW_TASK 与实际受理/拒绝回执；普通应用设置不能替代定位服务设置。iOS/HarmonyOS 没有当前支持的独立公开入口，返回 `Unavailable` / `unavailable`，不使用未公开 scheme，也不打开其他页面后报成功。接口默认实现返回 `Unavailable`，现有自定义 SystemActions 实现可继续编译。

商店地址同样只接受 HTTP(S)。系统可能通过 Universal Link / App Link 打开商店，也可能使用浏览器。当前版本不猜测应用市场包名，不承诺必须在某一厂商商店内打开。

## HarmonyOS

```sh
ohpm install @gycrosskit/system-actions-native@0.1.1
```

```typescript
import { SystemActions } from '@gycrosskit/system-actions-native';
const actions = new SystemActions(uiAbilityContext);
const result = await actions.dial('+86 138-1234-5678');
await actions.openExternalUrl('https://example.com');
await actions.openAppSettings();
await actions.openAppStore(storeListingUrl);
```

返回 `requested` / `invalid_input` / `unavailable`，只在系统 Promise 成功后返回 `requested`。在 UIAbility 主线程使用，context 生命周期由宿主管理，不将页面 context 放入全局单例。拨号走系统拨号界面；应用设置使用 API 22 支持的系统设置协议。库不申请额外业务权限。

0.1.1 产物已在本地准备；发布和远程消费需另行验证。HAR 发布状态以 ohpm 查询/安装结果为准；已提交审核不代表已上架。构建产物为 `ohos/system-actions-native/build/default/outputs/default/SystemActionsNative.har`。

## Kuikly OHOS 桥

在 `ohosArm64Main.dependencies` 添加：

```kotlin
implementation("com.github.gycrosskit.system-actions:system-actions-kuikly:0.1.2")
```

Kotlin `SystemActionsModule` 实现 `SystemActions`，覆盖拨号、HTTP(S) 外链、应用设置、定位设置与 HTTP(S) 商店地址。页面在 `createExternalModules()` 注册同一实例：

```kotlin
import io.github.gycrosskit.systemactions.kuikly.SystemActionsModule
private val actions = SystemActionsModule()
override fun createExternalModules() = mapOf(SystemActionsModule.NAME to actions)
// 在该页面的 Kuikly 协程上下文中调用 actions.dial(...) 等 API。
// 页面销毁时调用 actions.dispose()；它取消所有等待并移除 Kuikly callback。
```

ArkTS 宿主在 Renderer 的 `getCustomRenderModuleCreatorRegisterMap()` 注册：

```typescript
import { SystemActions, GycSystemActionsModule } from '@gycrosskit/system-actions-native';
// 每个页面持有 actions，原生调用与 Renderer 共享这个实例，不放入全局单例。
const actions = new SystemActions(uiAbilityContext);
modules.set(GycSystemActionsModule.MODULE_NAME, () => new GycSystemActionsModule(actions));
```

两侧模块名均为 `GycSystemActionsModule`。系统调用只委托注入的 SystemActions；URL/拨号校验与平台跳转均不在桥中重复。Renderer 等待系统 Promise 回执后返回 `requested` / `invalid_input` / `unavailable`。Kotlin 单次等待最多 20 秒，超时返回 `Unavailable`；外部协程取消继续传播取消。取消和 `dispose()` 发送对应 requestId 的取消指令，两侧移除 callback；Renderer 的 `onDestroy()` 清空等待并释放实例引用。迟到回调不会交给旧页面，但取消无法撤回系统已打开的页面。

宿主可删除上述 5 个 API 的自定义跨语言转接；键盘、主题、退出任务及 AppGallery/native 商店优先级继续由宿主决定。

## 验证

```sh
bash gradlew :system-actions-core:jvmTest :system-actions-core:testDebugUnitTest :system-actions-core:compileKotlinIosSimulatorArm64 :system-actions-kuikly:compileKotlinOhosArm64
node ohos/tests/system-actions.test.cjs
node ohos/tests/system-actions-module.test.cjs
cd ohos && DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHar --no-daemon
```

HAR 测试使用已有 TypeScript，可通过 `TYPESCRIPT_PATH` 指定模块。覆盖非法输入不触发系统、等待受理、系统失败、多品牌设置包名传递。Kuikly 测试覆盖取消/销毁和 requestId 重用后的迟到回执；Android mock Intent 检查定位设置 action、NEW_TASK 与系统拒绝。真实拨号/商店/系统设置页面仍需真机验证。

macOS 发布完整 Maven 归档，JitPack 校验 SHA-256 后安装；不会把仓库目录作为 Maven 服务。独立远程消费：

```sh
bash gradlew -p verification-consumer compileDebugKotlinAndroid compileKotlinIosArm64 compileKotlinIosX64 linkDebugFrameworkIosSimulatorArm64 compileKotlinOhosArm64 --rerun-tasks
```

独立 OHPM 消费工程默认从远程安装 0.1.1：

```sh
cd verification-ohos
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHar --no-daemon
```

本地发布前可用 `-PsystemActionsRepository=<staging Maven 目录>` 验证 Maven 产物，并将独立 OHPM 消费依赖临时指向构建的 HAR；这只验证产物独立消费，不能据此称远程已发布。远程验收仍需成功安装对应 JitPack/OHPM 坐标。发布完整 Maven 归档使用 `bash gradlew publishAllPublicationsToStagingRepository`。

参考 [Android Common Intents](https://developer.android.com/guide/components/intents-common)、[UIApplication](https://developer.apple.com/documentation/uikit/uiapplication)。
