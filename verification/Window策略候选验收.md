# Window 策略 0.2.0-rc.1 预发布验收

`0.2.0-rc.1` 已预发布；最新远程结果见末节。以下“已完成”部分是 2026-10-04 发布前的本地验证，本记录区分源码测试、产物消费和设备行为。

## 已完成

- Android `:system-actions-core:testDebugUnitTest --tests '*AndroidWindowPolicyTest'`：2 项通过；多 owner、已有常亮/secure、其他 flags 不变、不同 Window 与关闭后更新。Core 无 Compose 依赖。
- OHOS 四组 Node 真实源码测试通过；WindowPolicy 测试覆盖多 owner、初始 privacy、获取期间释放、set 操作期间释放、恢复失败重试和后续窗口重建。
- Swift `ios/Tests/run.sh`：真实策略源码与 UIKit mock 编译并执行通过；进程 owner 跨 controller、录屏通知、窗口转移、初始 idle timer、已结束 lease。
- `publishAllPublicationsToStagingRepository` 成功：Android、iOS Arm64/X64/SimulatorArm64、JVM、OHOS 及公共 metadata。
- 组织 `check-maven.py`：9 模块 POM/metadata、实际产物 hash、项目依赖坐标、Android AAR 和 iOS/OHOS target 通过；`release-pack.py` 归档并检查无 AppleDouble 成员。
- Maven 独立消费者从候选 staging 解析，Android compile、iOS Arm64/X64 compile、iOS Simulator framework link、OHOS compile 均成功，无源码 substitution。
- HAR `assembleHar`、`ohpm prepublish <HAR>` 成功；独立 consumer 从打包 HAR 安装后 `assembleHar` 成功，消费导出的 WindowPolicyController 和 `window.Window`。
- Swift Package 本身及 `verification-ios` 独立 Package 消费者使用真实 iOS Simulator SDK，Arm64/X86_64 编译链接成功。
- CocoaPods 独立 framework 消费者安装本地 `GYCWindowPolicy (0.2.0-rc.1)`；真实 iOS Simulator SDK 编译链接成功，无 Shared/KMP Framework 依赖。安装器关于 framework 无 App 宿主的提示与该消费者类型一致。
- `git diff --check` 通过。宿主候选保持四个薄接线文件，Android lease 在 DisposableEffect 中获取，不在 composition 直接写 Window。

## 产物与限制

本地 Maven 位于 `build/maven`，归档 `build/system-actions-maven-0.2.0-rc.1.tar.gz`；HAR 位于 `ohos/system-actions-native/build/default/outputs/default/SystemActionsNative.har`；SHA-256 在 ignored `build/WINDOW_SHA256SUMS`。Swift 源码由根 `Package.swift` 和 `GYCWindowPolicy.podspec` 共同消费。构建日志均在 ignored `build/window-*.log`，不把本地 staging 当作远程发布。

首次 Maven consumer 因独立工程缺少 SDK 路径而失败，添加 ignored local.properties 后完整通过；Swift mock 测试入口和 CGRect fixture 修正后通过，真实 UIKit SDK 编译另已验证。HAR 编译提示 setWindowPrivacyMode 需宿主声明 `ohos.permission.PRIVACY_WINDOW`；原应用已声明，组件 README/接入指南注明契约。

尚未进行真实设备的常亮、录屏/镜像、窗口切换、快速关闭或恢复验收；发布前未进行远程消费，发布后结果见下节。iOS 公开 API 无法阻止静态截图；OHOS 本轮只有 privacy，不提供常亮或全屏策略。


## 发布准备复核

2026-10-04 用户授权提交、PR 合并和远程预发布。目标 `main` 默认分支保护已核验：要求 PR、对管理员生效、禁止强推与删除；Issues 已启用且无未关闭 Issue，`0.2.0-rc.1` 尚未占用。`jitpack-install.sh`、metadata 和 checker 与组织模板同步；回归测试覆盖幂等修改、checksum 重算与空输入失败。旧 `0.1.3` Maven Release 归档重新下载核验为 `474b8f091ef310c9be66665e5e0d9b7c544c1333cdbf714abc3faff3b3d4861e`，checksum 文件保留该版本。新 staging 的 9 个 metadata 完成本地正规化，checker 再次通过，标准资产名 `system-actions-maven.tar.gz` / `SystemActionsNative.har`。远程结果将另外记录，不以本地结果代替。


## 已发布与远程验收

- [PR #12](https://github.com/gycrosskit/system-actions/pull/12) 已合并；发布 merge commit `ec531d46225406e8e24095364e0034b35f16527e`，固定标签 `0.2.0-rc.1` 来自该提交。本次不覆盖标签或归档。
- [GitHub prerelease](https://github.com/gycrosskit/system-actions/releases/tag/0.2.0-rc.1) 上传标准资产 `system-actions-maven.tar.gz` / `SystemActionsNative.har` / `SHA256SUMS`，isPrerelease=true。
- Maven 归档 SHA-256：`12264dc3daa1e919f2658040f5dde4869a47246ecb3e5f2a1df7913c9ff2442c`；HAR SHA-256：`18da53e64aa79a66f3b7f280950261adc430db7da54255bd3db68896fa55900d`。重新下载两项 Release 资产，`SHA256SUMS` 均 OK；远程 Maven 解包后的 9 模块 artifact/metadata checker 再次通过。
- [JitPack 构建状态](https://jitpack.io/api/builds/com.github.gycrosskit/system-actions/0.2.0-rc.1) 最终 `status=ok`、commit 与发布 merge commit 一致，9 个模块齐全。正式坐标为 `com.github.gycrosskit.system-actions:system-actions-core:0.2.0-rc.1` / `system-actions-kuikly:0.2.0-rc.1`。
- 干净独立 Maven 工程只配置正式 JitPack，`--refresh-dependencies` 完整执行 Android compile、iOS Arm64/X64 compile、Simulator framework link、OHOS compile，BUILD SUCCESSFUL（3m22s），没有本地 staging 或源码 substitution。
- Swift 独立 consumer 从 GitHub exact tag `0.2.0-rc.1` 获取 Package，Package.resolved revision 为发布 merge commit；真实 iOS Simulator SDK Arm64/X86_64 编译链接 BUILD SUCCEEDED。
- CocoaPods 独立 framework consumer 从 GitHub Git tag `0.2.0-rc.1` 安装 `GYCWindowPolicy`，真实 iOS Simulator SDK 编译链接 BUILD SUCCEEDED，不依赖 Shared/KMP Framework。
- `ohpm prepublish` 通过；`ohpm publish SystemActionsNative.har --tag next` 接受 `@gycrosskit/system-actions-native@0.2.0-rc.1`，回执明确 under review。随后精确版本 Registry 安装实际返回 `NOTFOUND`，尚未上架。
- 审核期间独立 HAR consumer 使用从固定 Release URL 下载且 SHA-256 匹配的 HAR，通过本机 `ohpm install <相对 HAR 路径>` 安装后 `assembleHar` BUILD SUCCESSFUL（3.535s），不是 ArkTS 源码目录依赖，也不作为 Registry 安装验收。

设备常亮、录屏/镜像、快速关闭和恢复尚未验收；iOS 静态截图无法阻止。当前仅完成发布、编译/链接与源码策略测试；OHPM 审核通过后的正常精确版本安装仍待完成。
