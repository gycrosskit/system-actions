# 变更记录

## 0.1.2

- 新增原生 AppGallery 商店详情，等待 onAppear；错误、提前关闭、取消和 20 秒超时结束等待。
- Renderer 按请求独立取消、释放计时器，销毁只清理自身等待，迟到回调不会交给重用 ID 或其他 owner。

## 0.1.1

- 提供可注入同一 SystemActions 的 Kuikly Renderer Module，等待系统回执，取消/销毁抑制迟到回调。
- 明确 OHOS 独立定位设置不支持，返回 unavailable。

## 0.1.0

- 拨号、HTTP(S) 外链、应用设置和商店详情，校验输入并等待系统受理结果。
