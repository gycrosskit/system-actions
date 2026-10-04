# Window 策略候选验收

候选 `0.2.0-rc.1`，2026-10-04 本地验证；无 commit、push、tag、Release、JitPack 构建或 OHPM publish。本记录区分源码测试、产物消费和设备行为。

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

尚未进行真实设备的常亮、录屏/镜像、窗口切换、快速关闭或恢复验收；未进行远程 Package/Pod/Maven/OHPM 消费。iOS 公开 API 无法阻止静态截图；OHOS 本轮只有 privacy，不提供常亮或全屏策略。


## 发布准备复核

2026-10-04 用户授权提交、PR 合并和远程预发布。目标 `main` 默认分支保护已核验：要求 PR、对管理员生效、禁止强推与删除；Issues 已启用且无未关闭 Issue，`0.2.0-rc.1` 尚未占用。`jitpack-install.sh`、metadata 和 checker 与组织模板同步；回归测试覆盖幂等修改、checksum 重算与空输入失败。旧 `0.1.3` Maven Release 归档重新下载核验为 `474b8f091ef310c9be66665e5e0d9b7c544c1333cdbf714abc3faff3b3d4861e`，checksum 文件保留该版本。新 staging 的 9 个 metadata 完成本地正规化，checker 再次通过，标准资产名 `system-actions-maven.tar.gz` / `SystemActionsNative.har`。远程结果将另外记录，不以本地结果代替。
