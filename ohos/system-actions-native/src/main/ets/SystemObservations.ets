import { window } from '@kit.ArkUI';
import { common, ConfigurationConstant, EnvironmentCallback } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';

/** 每个 Module 仅一份系统观察；generation 同时隔离迟 Window 和 off 后已排队的回调。 */
export class SystemObservations {
  private readonly context: () => common.UIAbilityContext | null | undefined;
  private keyboardWindow: window.Window | null = null;
  private keyboardListener: ((height: number) => void) | null = null;
  private keyboardGeneration: number = 0;
  private keyboardToken: string | null = null;
  private environmentContext: common.ApplicationContext | null = null;
  private environmentId: number | null = null;
  private environmentGeneration: number = 0;
  private environmentToken: string | null = null;
  private disposed: boolean = false;

  /** @param context 每次读取当前 UIAbility，不缓存旧 Window 或业务页面。 */
  constructor(context: () => common.UIAbilityContext | null | undefined) { this.context = context; }

  /**
   * 主线程替换本实例旧观察；初值为 0，迟到旧 Window/旧事件忽略。
   * @param token 本次所有权标识，停止时使用相同值。
   * @param callback 主线程回调，高度由当前 Window px2vp 转为 vp。
   */
  async observeKeyboardHeight(token: string, callback: (height: number) => void): Promise<void> {
    this.stopKeyboardHeight();
    if (this.disposed) return;
    this.keyboardToken = token;
    const generation = this.keyboardGeneration;
    try {
      const context = this.context();
      if (!context) { callback(0); return; }
      const target = await window.getLastWindow(context);
      if (this.disposed || generation !== this.keyboardGeneration) return;
      const listener = (height: number): void => {
        if (!this.disposed && generation === this.keyboardGeneration) {
          callback(target.getUIContext().px2vp(height));
        }
      };
      this.keyboardWindow = target;
      this.keyboardListener = listener;
      target.on('keyboardHeightChange', listener);
      callback(0);
    } catch (_) {
      if (!this.disposed && generation === this.keyboardGeneration) callback(0);
    }
  }

  /** 幂等停止键盘观察。@param token 省略停止当前观察；旧 token 不影响后继观察。 */
  stopKeyboardHeight(token?: string): void {
    if (token !== undefined && token !== this.keyboardToken) return;
    this.keyboardGeneration++;
    const target = this.keyboardWindow, listener = this.keyboardListener;
    this.keyboardToken = null;
    this.keyboardWindow = null;
    this.keyboardListener = null;
    if (target && listener) { try { target.off('keyboardHeightChange', listener); } catch (_) {} }
  }

  /**
   * 主线程替换旧主题观察，先同步交付当前配置，再订阅系统变化。
   * @param token 本次所有权标识。
   * @param callback true 为深色模式，可在初始回调中同步 stop/dispose。
   */
  observeDarkMode(token: string, callback: (darkMode: boolean) => void): void {
    this.stopDarkMode();
    if (this.disposed) return;
    this.environmentToken = token;
    const generation = this.environmentGeneration;
    const context = this.context();
    if (!context) return;
    try {
      callback(context.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK);
      // 初始回调也可能同步触发 stop/dispose，不能在其后建立已失效的监听。
      if (this.disposed || generation !== this.environmentGeneration) return;
      const application = context.getApplicationContext();
      const listener: EnvironmentCallback = {
        onConfigurationUpdated: configuration => {
          if (!this.disposed && generation === this.environmentGeneration) {
            callback(configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          }
        },
        onMemoryLevel: _level => {}
      };
      this.environmentId = application.on('environment', listener);
      this.environmentContext = application;
    } catch (_) {}
  }

  /** 幂等停止主题观察。@param token 省略停止当前观察；旧 token 不影响后继观察。 */
  stopDarkMode(token?: string): void {
    if (token !== undefined && token !== this.environmentToken) return;
    this.environmentGeneration++;
    const context = this.environmentContext, id = this.environmentId;
    this.environmentToken = null;
    this.environmentContext = null;
    this.environmentId = null;
    if (context && id !== null) { try { context.off('environment', id); } catch (_) {} }
  }

  /** 主线程幂等撤销所有观察；后续观察请求忽略。 */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.stopKeyboardHeight();
    this.stopDarkMode();
  }
}
