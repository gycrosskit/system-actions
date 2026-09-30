import { call } from '@kit.TelephonyKit';
import { common } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';
import { productViewManager } from '@kit.AppGalleryKit';

export type ActionResult = 'requested' | 'invalid_input' | 'unavailable';
export interface NativeStoreRequest {
  result: Promise<ActionResult>;
  /** 结束等待；SDK 没有撤销已经打开的商店页面的 API。 */
  cancel: () => void;
}

/** 在宿主 UIAbility 的主线程调用。requested 不表示用户已完成操作。 */
export class SystemActions {
  private readonly context: common.UIAbilityContext;
  constructor(context: common.UIAbilityContext) { this.context = context; }

  async dial(phone: string): Promise<ActionResult> {
    const value = phone.trim();
    if (!/^\+?[0-9][0-9 ()-]{0,30}$/.test(value)) { return 'invalid_input'; }
    try {
      await call.makeCall(this.context, value.replace(/[ ()-]/g, ''));
      return 'requested';
    } catch (_) { return 'unavailable'; }
  }

  async openExternalUrl(value: string): Promise<ActionResult> {
    const normalized = value.trim();
    if (!/^https?:\/\//i.test(normalized) || /[\s\u0000-\u001f\u007f\\]/.test(normalized) ||
      /%(?![0-9A-Fa-f]{2})/.test(normalized)) { return 'invalid_input'; }
    try {
      const parsed = new url.URL(normalized);
      const authority = normalized.split('://')[1].split(/[/?#]/)[0];
      if (!authority || !parsed.hostname || authority.includes('@') || parsed.username || parsed.password ||
        (parsed.port !== '' && (Number(parsed.port) < 1 || Number(parsed.port) > 65535))) { return 'invalid_input'; }
    } catch (_) { return 'invalid_input'; }
    try {
      await this.context.openLink(normalized, { appLinkingOnly: false });
      return 'requested';
    } catch (_) { return 'unavailable'; }
  }

  async openAppSettings(): Promise<ActionResult> {
    try {
      // API 22 的系统设置协议；更高版本官方 API 不作为当前最低要求。
      await this.context.startAbility({
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'application_info_entry',
        parameters: { pushParams: this.context.abilityInfo.bundleName }
      });
      return 'requested';
    } catch (_) { return 'unavailable'; }
  }

  /** 没有独立的公开定位服务设置入口，不使用应用设置页伪装成功。 */
  async openLocationSettings(): Promise<ActionResult> { return 'unavailable'; }

  async openAppStore(listingUrl: string): Promise<ActionResult> {
    return this.openExternalUrl(listingUrl);
  }

  async openNativeAppStore(applicationId?: string): Promise<ActionResult> {
    return this.requestNativeAppStore(applicationId).result;
  }

  /** 原生调用可保留请求取消函数；Renderer 只取消自身请求，不销毁共享实例。 */
  requestNativeAppStore(applicationId?: string): NativeStoreRequest {
    const bundleName = applicationId === undefined ? this.context.abilityInfo.bundleName : applicationId.trim();
    if (bundleName.length > 255 || !/^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/.test(bundleName)) {
      return { result: Promise.resolve('invalid_input'), cancel: () => {} };
    }
    let complete: ((status: ActionResult) => void) | null = null;
    let timer: number | null = null;
    const result = new Promise<ActionResult>((resolve) => { complete = resolve; });
    const finish = (status: ActionResult): void => {
      if (!complete) { return; }
      const resolve = complete;
      complete = null;
      if (timer !== null) { clearTimeout(timer); timer = null; }
      resolve(status);
    };
    timer = setTimeout(() => finish('unavailable'), 20_000);
    try {
      // loadProduct 返回 void；只有 onAppear 证明详情页已显示。
      // SDK 可能保留 callback，结算后它不再持有 Promise resolver 或页面 context。
      productViewManager.loadProduct(this.context, { parameters: { bundleName } }, {
        onAppear: () => finish('requested'),
        onError: () => finish('unavailable'),
        onDisappear: () => finish('unavailable')
      });
    } catch (_) { finish('unavailable'); }
    return { result, cancel: () => finish('unavailable') };
  }
}
