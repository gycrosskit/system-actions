# 更新日志

## HAR／私有 OHPM 1.1.2

状态：已发布；[HAR 1.1.2](https://github.com/gycrosskit/system-actions/releases/tag/har-1.1.2) 与私有 OHPM 精确版本均完成独立远程消费。Maven 保留 `1.1.1`，Swift/Git Pod 保留 `native-1.0.2`。

- OHOS 读取首条剪贴板记录已有的 `text/plain` 表示，兼容富文本主 MIME；不解析 HTML/RTF、不扫描后续记录，保持空串、空白与内嵌 NUL。
- Android/iOS 实现保持原样，补充 Android 与 OHOS 回归及三端合同说明。源码、SDK、发布和设备证据见[剪贴板验证](docs/功能与平台差异.md#原生剪贴板读取当前源码候选)。

## 1.1.1

状态：已发布；[Maven 1.1.1](https://github.com/gycrosskit/system-actions/releases/tag/1.1.1)、[HAR 1.1.1](https://github.com/gycrosskit/system-actions/releases/tag/har-1.1.1) 与私有 OHPM 精确版本消费已分别确认，Swift/Git Pod 保留 `native-1.0.2`。

- Android 商店直接使用 `ACTION_VIEW + setPackage + startActivity`，移除 `resolveActivity` 硬门禁及市场 `<queries>`；新增 `openMarketDetails(packageName, appUrl)`，继续验证输入并固定接收包。
- Android Module/注册入口与 iOS Kotlin handler 支持宿主商店回调，保留旧公开构造器、注册签名、默认行为和显式 URL 合同。
- Harmony Module 支持返回 `NativeStoreRequest` 的宿主回调，沿用请求级取消、销毁及迟回执保护。厂商选择、品牌配置和网页兜底仍归宿主。

发行验收：[源码 verify #192](http://121.36.107.201:18080/job/component-ci/job/verify/192/) 通过 34 个行为、23 个合同及 8 个 OHOS 脚本测试，均零失败、零跳过。[Maven package #142](http://121.36.107.201:18080/job/component-ci/job/package/142/) 冻结 13 个 publication；[release #149](http://121.36.107.201:18080/job/component-ci/job/release/149/) 已确认公开，但其消费者入口因 CI pin 不匹配失败，原失败保留。随后用 Store 对应的干净 `c595cafb37a187b0b8b4c7386cba25930573d4d6` 受管入口、原 journal 和准确 Tag 单独完成 `PUBLIC_CONSUMERS_CONFIRMED`（无延期平台）；没有重发制品。[HAR release #150](http://121.36.107.201:18080/job/component-ci/job/release/150/) 与[私有 OHPM release #151](http://121.36.107.201:18080/job/component-ci/job/release/151/) 均成功，使用同一 #143 冻结 HAR。设备联调范围见[商店策略验证](docs/功能与平台差异.md#商店策略验证)。

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
