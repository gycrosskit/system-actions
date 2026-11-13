# 更新日志

## 1.1.2

状态：候选，尚未发布；正式下载、安装与消费以渠道回执为准。

- 剪贴板读取改为获取首条记录已有的 `text/plain` 表示，兼容主 MIME 为富文本的多格式记录；不解析 HTML、不转换 URI，也不扫描后续记录。
- 保留空串、空白、NUL、长文本及原有拒绝／失败映射，三端读取合同一致。
- 仅更新 HAR／私有 OHPM；Maven 保留 `1.1.1`，Swift/Git Pod 保留 `native-1.0.2`。

## 1.1.1

状态：已发布；[Release HAR](https://github.com/gycrosskit/system-actions/releases/tag/har-1.1.1) 与私有 OHPM `@gycrosskit/system-actions-native@1.1.1` 的同字节下载、精确安装及实际 ArkTS 消费分别通过 [release #150](http://121.36.107.201:18080/job/component-ci/job/release/150/) / [#151](http://121.36.107.201:18080/job/component-ci/job/release/151/)。这不表示官方 Registry 审核或 Harmony 真机验收。

- `GycSystemActionsModule(actions, windowPolicy, openNativeAppStore?)` 支持可选宿主商店回调，返回 `NativeStoreRequest` 并复用原请求级取消、销毁与迟回执保护。
- 未注入回调时保留 AppGallery 默认行为；宿主负责当前 App 的更新选择和专用网页兜底，不改变显式其他应用和 HTTP(S) URL 合同。
- Maven core/Kuikly 配套版本为 `1.1.1`，Swift/Git Pod 无源码变化，保留 `native-1.0.2`。

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

## 0.2.0-rc.5

GycSystemActionsModule 接受 Ability 级 windowPolicy 注入，隔离多 Ability 生命周期 owner。Maven / Swift / Git Pod 仍使用 0.2.0-rc.6。

## 0.2.0-rc.4

新增组件级 clipboard、受控私有普通文件 ShareKit 分享和 Kuikly 入口；异步分享复核 owner 许可。屏幕常亮复用共享 WindowPolicy lease，保留基线、失败恢复重试，不无谓调用 privacy API。

## 0.2.0-rc.3

- 修正 layout-only 全屏退出的方向恢复，保留跨 owner touched、显式退出策略与失败重试。

# 0.2.0-rc.2

- 完成本轮既有能力边界迁移，具体 API 与兼容规则见 README。

# 变更记录

## 0.2.0-rc.1（GitHub Release 预发布，OHPM 审核中）

- 新增 WindowPolicyController / WindowPolicyLease，多 owner privacy 合并与进入前状态恢复。
- 串行处理窗口获取、privacy 设置和释放；销毁期间迟到窗口不会被接管，恢复失败可重试。
- 只提取 privacy，常亮、全屏、方向和系统栏留给宿主。

## 0.1.2

- 新增原生 AppGallery 商店详情，等待 onAppear；错误、提前关闭、取消和 20 秒超时结束等待。
- Renderer 按请求独立取消、释放计时器，销毁只清理自身等待，迟到回调不会交给重用 ID 或其他 owner。

## 0.1.1

- 提供可注入同一 SystemActions 的 Kuikly Renderer Module，等待系统回执，取消/销毁抑制迟到回调。
- 明确 OHOS 独立定位设置不支持，返回 unavailable。

## 0.1.0

- 拨号、HTTP(S) 外链、应用设置和商店详情，校验输入并等待系统受理结果。
