import { call } from '@kit.TelephonyKit';
import { common } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';

export type ActionResult = 'requested' | 'invalid_input' | 'unavailable';

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

  async openAppStore(listingUrl: string): Promise<ActionResult> {
    return this.openExternalUrl(listingUrl);
  }
}
