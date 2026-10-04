import { window } from '@kit.ArkUI';

/** 同一 Ability 共用 shared；resolver 留给宿主，库不读取业务页面或导航状态。 */
export class WindowPolicyController {
  static readonly shared: WindowPolicyController = new WindowPolicyController();
  private owners: Map<WindowPolicyLease, boolean> = new Map();
  private target: window.Window | null = null;
  private previousPrivacy: boolean = false;
  private task: Promise<void> = Promise.resolve();

  createLease(resolveWindow: () => Promise<window.Window>): WindowPolicyLease {
    return new WindowPolicyLease(this, resolveWindow);
  }

  apply(lease: WindowPolicyLease, resolveWindow: () => Promise<window.Window>): Promise<void> {
    return this.enqueue(async () => {
      if (lease.isReleased) return;
      let target = this.target;
      if (!target) {
        target = await resolveWindow();
        // 获取窗口期间页面可能已销毁，迟到回调不能建立 owner 或修改 Window。
        if (lease.isReleased) return;
        this.previousPrivacy = target.getWindowProperties().isPrivacyMode;
        this.target = target;
      }
      this.owners.set(lease, lease.screenRecordingAllowed);
      await target.setWindowPrivacyMode(this.privacyRequired());
    });
  }

  release(lease: WindowPolicyLease): Promise<void> {
    return this.enqueue(async () => {
      this.owners.delete(lease);
      const target = this.target;
      if (!target) return;
      await target.setWindowPrivacyMode(this.privacyRequired());
      // 恢复失败保留初值和目标，后续 release 可重试，不把受保护窗口当作新的初始状态。
      if (this.owners.size === 0) this.target = null;
    });
  }

  private privacyRequired(): boolean {
    let protect = this.previousPrivacy;
    this.owners.forEach(allowed => { if (!allowed) protect = true; });
    return protect;
  }

  private enqueue(action: () => Promise<void>): Promise<void> {
    const next = this.task.then(action);
    this.task = next.catch(() => {});
    return next;
  }
}

/** update 必须完成后再展示视频；release 即时撤销 lease，并等待串行窗口恢复。 */
export class WindowPolicyLease {
  private released: boolean = false;
  private allowed: boolean = false;
  private readonly controller: WindowPolicyController;
  private readonly resolveWindow: () => Promise<window.Window>;

  constructor(controller: WindowPolicyController, resolveWindow: () => Promise<window.Window>) {
    this.controller = controller;
    this.resolveWindow = resolveWindow;
  }
  get isReleased(): boolean { return this.released; }
  get screenRecordingAllowed(): boolean { return this.allowed; }

  update(screenRecordingAllowed: boolean): Promise<void> {
    if (this.released) return Promise.resolve();
    this.allowed = screenRecordingAllowed;
    return this.controller.apply(this, this.resolveWindow);
  }

  release(): Promise<void> {
    this.released = true;
    return this.controller.release(this);
  }
}
