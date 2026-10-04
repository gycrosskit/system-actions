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

  constructor(context: () => common.UIAbilityContext | null | undefined) { this.context = context; }

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

  stopKeyboardHeight(token?: string): void {
    if (token !== undefined && token !== this.keyboardToken) return;
    this.keyboardGeneration++;
    const target = this.keyboardWindow, listener = this.keyboardListener;
    this.keyboardToken = null;
    this.keyboardWindow = null;
    this.keyboardListener = null;
    if (target && listener) { try { target.off('keyboardHeightChange', listener); } catch (_) {} }
  }

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

  stopDarkMode(token?: string): void {
    if (token !== undefined && token !== this.environmentToken) return;
    this.environmentGeneration++;
    const context = this.environmentContext, id = this.environmentId;
    this.environmentToken = null;
    this.environmentContext = null;
    this.environmentId = null;
    if (context && id !== null) { try { context.off('environment', id); } catch (_) {} }
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.stopKeyboardHeight();
    this.stopDarkMode();
  }
}
