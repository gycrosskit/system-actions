# GY CrossKit System Actions Native

当前 HAR 候选为 **0.2.0-rc.4**，补齐剪贴板、普通私有文件分享和复用 WindowPolicy lease 的常亮。发布和远程消费尚待完成；OHPM 接受提交、审核与 Registry 安装分别核验。审核通过并可查询后安装：

```sh
ohpm install @gycrosskit/system-actions-native@0.2.0-rc.4
```

以下为已有渠道历史记录，不替代新候选验收。


HarmonyOS API 22 的拨号、HTTP(S) 外链、应用设置和商店能力，含可注入共享 `SystemActions` 的 Kuikly Renderer Module。

`0.1.1` 已在 OHPM Registry 发布；`0.1.2` 的[独立 GitHub Release 归档](https://github.com/gycrosskit/system-actions/releases/tag/har-0.1.2)已发布并完成远程下载、校验、安装和编译。OHPM 已接受 `0.1.2` 提交，当前审核中，Registry 精确安装尚不可用。

`0.1.2` 上架后可按以下命令安装；Registry 接受提交不代表已经上架，当前仍需确认版本可用：

```sh
ohpm install @gycrosskit/system-actions-native@0.1.2
```

```typescript
import { SystemActions, GycSystemActionsModule } from '@gycrosskit/system-actions-native';
const actions = new SystemActions(uiAbilityContext);
const result = await actions.openNativeAppStore(); // 当前 bundleName，等待 onAppear
const request = actions.requestNativeAppStore('com.example.app');
request.cancel(); // 结束本次等待，不撤回已打开的 SDK 页面
await request.result;
modules.set(GycSystemActionsModule.MODULE_NAME, () => new GycSystemActionsModule(actions));
```

只有 AppGallery `onAppear` 返回 requested；错误、提前消失、取消或 20 秒超时返回 unavailable。取消/销毁清理本次计时器与 resolver，迟到回调无效。Renderer 只取消自己的请求，其他 owner 可继续使用共享实例。

用途、坐标和许可证见 [根 README](https://github.com/gycrosskit/system-actions/blob/main/README.md)；平台输入与生命周期见 [接入指南](https://github.com/gycrosskit/system-actions/blob/main/docs/接入指南.md)。业务 listingURL、升级决策及文案由宿主提供。

## Window 策略（0.2.0-rc.1 预发布）

`0.2.0-rc.1` 的 GitHub Release HAR 已发布并完成下载校验和独立消费；OHPM `next` 提交已接受但仍审核中，精确版本安装返回 `NOTFOUND`。上架后坐标为 `ohpm install @gycrosskit/system-actions-native@0.2.0-rc.1`；当前按[接入指南](https://github.com/gycrosskit/system-actions/blob/main/docs/接入指南.md)从固定 Release 下载、校验并以 `--no-save` 安装。

```typescript
import { WindowPolicyController, window } from '@gycrosskit/system-actions-native';
const lease = WindowPolicyController.shared.createLease(() => window.getLastWindow(context));
await lease.update(false);
await lease.update(true);
await lease.release();
```

宿主 `module.json5` 声明 `ohos.permission.PRIVACY_WINDOW`。同一 Ability 共用 controller；必须等保护设置成功才展示视频。多 owner 任意禁录即保持 privacy，最后一个释放才恢复进入前状态；获取窗口期间释放会抑制迟到结果，异步释放失败应由宿主处理，可重试 release。上述 rc.1 历史接口不提供常亮、全屏、方向或系统栏能力。业务授权、播放器错误 UI、导航和生命周期均由宿主决定。


`0.2.0-rc.2` 的固定 GitHub Release HAR 已发布并通过真实独立消费；OHPM `next` 提交已接受，审核状态与 Registry 安装另计。
该版 `GycSystemActionsModule` 提供键盘高度(vp)/环境观察和 stop/dispose；
`WindowPolicyController.shared.createFullscreenLease` 与 privacy lease 共用串行队列。
方向、系统栏目标及生命周期由宿主输入，完整 API/示例见仓库 `docs/接入指南.md`。
0.2.0-rc.3 已发布并完成固定 Release HAR 的独立消费，修正 layout-only 全屏退出时的方向恢复门禁；历史结果见仓库 verification/rc3远程发布验收.md。

## 0.2.0-rc.4 候选（未发布）

新增 `SystemActions.copyText(value)` / `shareFile(path, title)`，只分享当前 UIAbility filesDir/cacheDir/tempDir 下普通文件，拒绝 URI、路径穿越和符号链接。UTD 由扩展名推导，不接受自报 MIME；`requested` 只表示系统受理。
`createLease(resolver, keepScreenOn = false)` 复用窗口队列/owner恢复初值；传 true 请求常亮，未改变 privacy 时不要求 privacy 权限。Kuikly Module 提供 `copyText` / `shareFile` / `setKeepScreenOn` 并在取消/销毁时释放自身 lease；文件分享在异步检查后复核请求许可，取消或销毁阻止尚未展示的面板；详细边界见接入指南。
