# 更新日志

## 1.1.1

状态：待发布；Maven、HAR/OHPM 与远程消费分别以实际回执验收，Swift/Git Pod 保留 `native-1.0.2`。

- Android 商店直接使用 `ACTION_VIEW + setPackage + startActivity`，移除 `resolveActivity` 硬门禁及市场 `<queries>`；新增 `openMarketDetails(packageName, appUrl)`，继续验证输入并固定接收包。
- Android Module/注册入口与 iOS Kotlin handler 支持宿主商店回调，保留旧公开构造器、注册签名、默认行为和显式 URL 合同。
- Harmony Module 支持返回 `NativeStoreRequest` 的宿主回调，沿用请求级取消、销毁及迟回执保护。厂商选择、品牌配置和网页兜底仍归宿主。

## 1.1.0

状态：候选，发布与远程消费以各渠道回执为准。

- 新增 `SystemActions.readClipboardText()` 与 `ClipboardReadResult`，区分文本、无文本、拒绝、不可用与失败；Android/iOS 使用平台剪贴板，OHOS KMP 经宿主显式安装的 N-API bridge 接入 HAR。
- HAR 导出原生 bridge 头；未安装、拒绝或平台错误保持失败关闭，不记录剪贴板内容，宿主负责在前台用户操作中调用与原生接线。
- Maven 与 HAR/OHPM 使用新候选 `1.1.0`；Swift/Git Pod 源码未改，保留 `native-1.0.2`。构建、公开发布、精确远程消费与设备业务分别验收，旧版本与摘要不变。


## Native/HAR 1.0.2

- iOS Git Pod 使用 `native-1.0.2`，HAR/OHPM 使用 `har-1.0.2`；Maven 保留已发布 `1.0.1`，不重发未修改的 KMP 产物。
- Renderer 依赖由宿主选择：Pod 声明 `>= 2.29.1, < 3.0`，HAR 声明 `^2.29.1`。本轮未改动作、Window lease、观察与取消实现。
- 旧 Tag/归档/摘要保持不变；发布与公开同字节消费状态见对应 Release，设备验收单独记录。

## 1.0.1 - 2026-10-25

- 为本轮最新 dev 配套候选使用新版本，保留既有 1.0.0 标签和制品摘要；源码验证、制品生产与公开消费重新执行，当前尚未发布。

## 1.0.0（未发布）

- Maven、iOS Pod 与 OHPM 统一版本为 1.0.0；同仓模块使用同版，Kuikly 配套保持 2.29.1。
- 本地源码/产物消费与设备、远程发布验收分别记录；不覆盖旧标签或修改历史发布字节。

## 0.2.0-rc.6（2026-10-08）

- 补Android/iOS native观察和全屏窗口策略；修正owner/恢复边界；明确宿主接线及iOS能力限制。
- 更新功能、测试覆盖与平台差异文档；设备业务验收范围保持明确。
