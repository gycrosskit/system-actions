# GY CrossKit System Actions

封装 Android、iOS、HarmonyOS 的拨号、HTTP(S) 外链、当前应用设置和商店详情跳转。商店详情 URL、业务域名白名单与提示文案由宿主提供；库不绑定品牌包名或厂商商店优先级。

## 平台与模块

- `system-actions-core/`：Android 24+ / iOS 14+ KMP API；依赖 Kotlin 2.2.21-1.0.0、kotlinx-coroutines 1.10.2。
- `ohos/system-actions-native/`：HarmonyOS API 22 SDK 构建的原生 HAR，ArkTS 调用；不包含 Kuikly/KMP 鸿蒙桥接。
- `verification-consumer/`：独立 JitPack 消费构建。JVM 变体仅含公共 API 与校验，用于测试，不提供桌面系统动作。

许可证 Apache-2.0。

## Android / iOS

```kotlin
repositories { maven("https://jitpack.io") }
commonMain.dependencies {
    implementation("com.github.gycrosskit.system-actions:system-actions-core:0.1.0")
}
```

Android 使用 `AndroidSystemActions(context)`，iOS 使用 `IosSystemActions()`，通过 `SystemActions` 调用：

```kotlin
val result = actions.dial("+86 138-1234-5678")
actions.openExternalUrl("https://example.com/help")
actions.openAppSettings()
actions.openAppStore(storeListingUrl) // 宿主提供对应平台的 HTTP(S) 详情地址
```

`ActionResult.Requested` 只代表系统已受理；`InvalidInput` 表示输入被拒绝；`Unavailable` 表示系统无法打开。Android 使用 ACTION_DIAL，不申请直接呼叫权限；iOS 等待 UIApplication completion 回执。Android Application Context 自动加新任务标记。系统动作均在主线程发起，协程取消不能撤回已经打开的系统页面。

拨号仅允许开头可选 `+`、数字及空格/括号/连字符，长度最多 31 位可见号码字符（不含开头 `+`）；拒绝 USSD、等待符和传入完整 tel URI。URL 必须包含 HTTP(S) 协议和有效主机，拒绝凭据、空白/控制字符、反斜线、无效转义及非法端口。国际化域名请提供 ASCII/Punycode URL。业务白名单必须由宿主在调用前检查。

商店地址同样只接受 HTTP(S)。系统可能通过 Universal Link / App Link 打开商店，也可能使用浏览器。当前版本不猜测应用市场包名，不承诺必须在某一厂商商店内打开。

## HarmonyOS

```sh
ohpm install @gycrosskit/system-actions-native@0.1.0
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

HAR 发布状态以 ohpm 查询/安装结果为准；已提交审核不代表已上架。构建产物为 `ohos/system-actions-native/build/default/outputs/default/SystemActionsNative.har`。

## 验证

```sh
bash gradlew :system-actions-core:jvmTest :system-actions-core:compileDebugKotlinAndroid :system-actions-core:compileKotlinIosSimulatorArm64
node ohos/tests/system-actions.test.cjs
cd ohos && DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHar --no-daemon
```

HAR 测试使用已有 TypeScript，可通过 `TYPESCRIPT_PATH` 指定模块。覆盖非法输入不触发系统、等待受理、系统失败、多品牌设置包名传递。真实拨号/商店/系统设置页面仍需真机验证。

macOS 发布完整 Maven 归档，JitPack 校验 SHA-256 后安装；不会把仓库目录作为 Maven 服务。独立远程消费：

```sh
bash gradlew -p verification-consumer compileDebugKotlinAndroid compileKotlinIosArm64 compileKotlinIosX64 linkDebugFrameworkIosSimulatorArm64 --rerun-tasks
```

参考 [Android Common Intents](https://developer.android.com/guide/components/intents-common)、[UIApplication](https://developer.apple.com/documentation/uikit/uiapplication)。
