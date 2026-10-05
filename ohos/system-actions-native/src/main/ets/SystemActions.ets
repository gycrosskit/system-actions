import { call } from '@kit.TelephonyKit';
import { common } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';
import { productViewManager } from '@kit.AppGalleryKit';

/** requested 仅代表系统受理；invalid_input 未调用系统；unavailable 为不支持或系统失败。 */
export type ActionResult = 'requested' | 'invalid_input' | 'unavailable';
/** 宿主拥有的 AppGallery 等待句柄，20 秒无出现回执结算 unavailable。 */
export interface NativeStoreRequest {
  /** onAppear 返回 requested，错误、消失、超时与取消返回 unavailable；至多结算一次。 */
  result: Promise<ActionResult>;
  /** 结束等待；SDK 没有撤销已经打开的商店页面的 API。 */
  cancel: () => void;
}

/** 在宿主 UIAbility 的主线程调用。requested 不表示用户已完成操作。 */
export class SystemActions {
  private readonly context: common.UIAbilityContext;
  /** @param context 当前 UIAbility；实例持有该引用，宿主限定其生命周期。 */
  constructor(context: common.UIAbilityContext) { this.context = context; }

  /** @param phone 可选前导 +、数字和空格/括号/连字符；去除首尾空白后最多 31 个数字/分隔字符。不表示电话已接通。 */
  async dial(phone: string): Promise<ActionResult> {
    const value = phone.trim();
    if (!/^\+?[0-9][0-9 ()-]{0,30}$/.test(value)) { return 'invalid_input'; }
    try {
      await call.makeCall(this.context, value.replace(/[ ()-]/g, ''));
      return 'requested';
    } catch (_) { return 'unavailable'; }
  }

  /** @param value 完整 HTTP(S) 地址；拒绝凭据、空白、控制符、反斜杠和错误编码，端口 1..65535。 */
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

  /** 打开当前应用的系统设置页，返回系统受理状态。 */
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

  /** @param listingUrl 宿主按品牌提供的 HTTP(S) 商店地址，沿用 openExternalUrl 校验。 */
  async openAppStore(listingUrl: string): Promise<ActionResult> {
    return this.openExternalUrl(listingUrl);
  }

  /** @param applicationId 省略时使用当前 bundleName；非空点分应用 ID，最长 255 字符，等待 AppGallery 出现回执。 */
  async openNativeAppStore(applicationId?: string): Promise<ActionResult> {
    return this.requestNativeAppStore(applicationId).result;
  }

  /**
   * 原生调用可保留请求取消函数；Renderer 只取消自身请求，不销毁共享实例。
   * @param applicationId 省略时使用当前 bundleName；最长 255 字符的点分应用 ID。
   * @returns 20 秒等待句柄；cancel 幂等停止等待，不能关闭已打开商店页面。
   */
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
