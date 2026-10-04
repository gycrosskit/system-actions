# GY CrossKit System Actions Native

HarmonyOS API 22 的拨号、HTTP(S) 外链、应用设置和商店能力，含可注入共享 `SystemActions` 的 Kuikly Renderer Module。

`0.1.1` 已在 OHPM Registry 发布；本目录 `0.1.2` 是原生 AppGallery 商店候选，仅本地打包验证。候选未上传 Registry。

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
