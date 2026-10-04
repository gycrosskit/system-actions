# GY CrossKit System Actions Native

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

## Window 策略候选

本源码的 `0.2.0-rc.1` 尚未发布，发布后坐标为 `ohpm install @gycrosskit/system-actions-native@0.2.0-rc.1`。候选通过本地打包 HAR 验证。

```typescript
import { WindowPolicyController, window } from '@gycrosskit/system-actions-native';
const lease = WindowPolicyController.shared.createLease(() => window.getLastWindow(context));
await lease.update(false);
await lease.update(true);
await lease.release();
```

宿主 `module.json5` 声明 `ohos.permission.PRIVACY_WINDOW`。同一 Ability 共用 controller；必须等保护设置成功才展示视频。多 owner 任意禁录即保持 privacy，最后一个释放才恢复进入前状态；获取窗口期间释放会抑制迟到结果，异步释放失败应由宿主处理，可重试 release。此接口不提供常亮、全屏、方向或系统栏能力。业务授权、播放器错误 UI、导航和生命周期均由宿主决定。
