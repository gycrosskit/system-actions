# 更新日志

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
