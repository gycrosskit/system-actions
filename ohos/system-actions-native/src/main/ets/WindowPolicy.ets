import { window } from '@kit.ArkUI';

/** 宿主传方向和系统栏目标；省略退出值时恢复首次接管前的窗口状态。 */
export interface FullscreenWindowPolicy {
  enterOrientation?: window.Orientation;
  exitOrientation?: window.Orientation;
  unspecifiedExitOrientation?: window.Orientation;
  enterSystemBars?: Array<'status' | 'navigation'>;
  exitSystemBars?: Array<'status' | 'navigation'>;
  exitSystemBarsWhenFullscreen?: Array<'status' | 'navigation'>;
  exitSystemBarsWhenNotFullscreen?: Array<'status' | 'navigation'>;
  enterLayoutFullscreen?: boolean;
  exitLayoutFullscreen?: boolean;
}

/** 同一 Ability 共用 shared；resolver 留给宿主，库不读取业务页面或导航状态。 */
export class WindowPolicyController {
  static readonly shared: WindowPolicyController = new WindowPolicyController();
  private owners: Map<WindowPolicyLease, boolean> = new Map();
  private target: window.Window | null = null;
  private previousPrivacy: boolean = false;
  private task: Promise<void> = Promise.resolve();
  private fullscreenOwner: FullscreenWindowLease | null = null;
  private fullscreenTarget: window.Window | null = null;
  private previousOrientation: window.Orientation | null = null;
  private previousFullscreen: boolean = false;
  private previousLayoutFullscreen: boolean = false;
  private layoutTouched: boolean = false;
  private systemBarsTouched: boolean = false;
  private orientationTouched: boolean = false;
  private restorePolicy: FullscreenWindowPolicy | null = null;

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

  createFullscreenLease(resolveWindow: () => Promise<window.Window>, policy: FullscreenWindowPolicy,
    onReplaced?: () => void): FullscreenWindowLease {
    return new FullscreenWindowLease(this, resolveWindow, policy, onReplaced);
  }

  enterFullscreen(lease: FullscreenWindowLease, revision: number): Promise<boolean> {
    const oldOwner = this.fullscreenOwner;
    this.fullscreenOwner = lease;
    if (oldOwner && oldOwner !== lease) oldOwner.replace();
    let entered = false;
    return this.enqueue(async () => {
      if (!this.ownsFullscreen(lease, revision)) return;
      const target = await lease.resolveWindow();
      if (!this.ownsFullscreen(lease, revision)) return;
      if (this.fullscreenTarget && this.fullscreenTarget !== target) {
        await this.restoreFullscreen();
        if (!this.ownsFullscreen(lease, revision)) return;
      }
      if (!this.fullscreenTarget) {
        this.previousOrientation = target.getPreferredOrientation();
        this.previousFullscreen = target.getWindowProperties().isFullScreen;
        this.previousLayoutFullscreen = target.getWindowProperties().isLayoutFullScreen;
        this.fullscreenTarget = target;
      }
      const policy = lease.policy;
      this.restorePolicy = policy;
      if (policy.enterOrientation !== undefined) {
        this.orientationTouched = true;
        await target.setPreferredOrientation(policy.enterOrientation);
        if (!this.ownsFullscreen(lease, revision)) return;
      }
      if (policy.enterLayoutFullscreen !== undefined) {
        this.layoutTouched = true;
        await target.setWindowLayoutFullScreen(policy.enterLayoutFullscreen);
        if (!this.ownsFullscreen(lease, revision)) return;
      }
      if (policy.enterSystemBars !== undefined) {
        this.systemBarsTouched = true;
        await target.setWindowSystemBarEnable(policy.enterSystemBars);
      }
      entered = this.ownsFullscreen(lease, revision);
    }).then(() => entered).catch(async (error: Error) => {
      if (this.ownsFullscreen(lease, revision)) await lease.exit();
      throw error;
    });
  }

  exitFullscreen(lease: FullscreenWindowLease): Promise<void> {
    if (this.fullscreenOwner !== lease) {
      // 已释放 owner 的恢复曾失败时允许重试；仍有新 owner 时完全不触碰窗口。
      return this.fullscreenOwner === null ? this.enqueue(() => this.restoreFullscreen()) : Promise.resolve();
    }
    this.fullscreenOwner = null;
    return this.enqueue(async () => {
      // 在进入/退出排队期间已有新 View 接管时，旧退出不得恢复新 owner 的窗口。
      if (this.fullscreenOwner === null) await this.restoreFullscreen();
    });
  }

  private ownsFullscreen(lease: FullscreenWindowLease, revision: number): boolean {
    return this.fullscreenOwner === lease && lease.isActive && !lease.isReleased && lease.revision === revision;
  }

  private async restoreFullscreen(): Promise<void> {
    const target = this.fullscreenTarget;
    if (!target) return;
    const policy = this.restorePolicy;
    // 各恢复操作独立执行；失败保留基线，下一次 exit/release 可以重试。
    let failure: Error | null = null;
    try {
      if (this.systemBarsTouched || policy?.exitSystemBars !== undefined ||
        policy?.exitSystemBarsWhenFullscreen !== undefined || policy?.exitSystemBarsWhenNotFullscreen !== undefined) {
        await target.setWindowSystemBarEnable(policy?.exitSystemBars ?? (this.previousFullscreen
          ? (policy?.exitSystemBarsWhenFullscreen ?? [])
          : (policy?.exitSystemBarsWhenNotFullscreen ?? ['status', 'navigation'])));
      }
    } catch (error) { failure = error as Error; }
    try {
      if (this.layoutTouched || policy?.exitLayoutFullscreen !== undefined) {
        await target.setWindowLayoutFullScreen(policy?.exitLayoutFullscreen ?? this.previousLayoutFullscreen);
      }
    } catch (error) { if (!failure) failure = error as Error; }
    try {
      const previous = policy?.unspecifiedExitOrientation !== undefined &&
        this.previousOrientation === window.Orientation.UNSPECIFIED ? policy.unspecifiedExitOrientation : this.previousOrientation;
      const orientation = policy?.exitOrientation ?? previous;
      const fallbackRequested = policy?.unspecifiedExitOrientation !== undefined &&
        this.previousOrientation === window.Orientation.UNSPECIFIED;
      if ((this.orientationTouched || policy?.exitOrientation !== undefined || fallbackRequested) &&
        orientation !== null && orientation !== undefined) await target.setPreferredOrientation(orientation);
    } catch (error) { if (!failure) failure = error as Error; }
    if (failure) throw failure;
    this.fullscreenTarget = null;
    this.previousOrientation = null;
    this.restorePolicy = null;
    this.layoutTouched = false;
    this.systemBarsTouched = false;
    this.orientationTouched = false;
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

/** 与 privacy lease 共用 controller 与队列；替换立即撤销旧 owner，迟任务按身份校验。 */
export class FullscreenWindowLease {
  private released: boolean = false;
  private active: boolean = false;
  private generation: number = 0;
  readonly policy: FullscreenWindowPolicy;
  readonly resolveWindow: () => Promise<window.Window>;
  private readonly controller: WindowPolicyController;
  private readonly onReplaced: (() => void) | undefined;

  constructor(controller: WindowPolicyController, resolveWindow: () => Promise<window.Window>,
    policy: FullscreenWindowPolicy, onReplaced?: () => void) {
    this.controller = controller;
    this.resolveWindow = resolveWindow;
    // 拷贝宿主数组，避免排队后策略被外部修改。
    this.policy = {
      enterOrientation: policy.enterOrientation, exitOrientation: policy.exitOrientation,
      unspecifiedExitOrientation: policy.unspecifiedExitOrientation,
      enterSystemBars: policy.enterSystemBars?.slice(), exitSystemBars: policy.exitSystemBars?.slice(),
      exitSystemBarsWhenFullscreen: policy.exitSystemBarsWhenFullscreen?.slice(),
      exitSystemBarsWhenNotFullscreen: policy.exitSystemBarsWhenNotFullscreen?.slice(),
      enterLayoutFullscreen: policy.enterLayoutFullscreen, exitLayoutFullscreen: policy.exitLayoutFullscreen
    };
    this.onReplaced = onReplaced;
  }
  get isReleased(): boolean { return this.released; }
  get isActive(): boolean { return this.active; }
  get revision(): number { return this.generation; }

  enter(): Promise<boolean> {
    if (this.released) return Promise.resolve(false);
    this.active = true;
    return this.controller.enterFullscreen(this, ++this.generation);
  }
  exit(): Promise<void> {
    this.active = false;
    this.generation++;
    return this.controller.exitFullscreen(this);
  }
  release(): Promise<void> {
    this.released = true;
    return this.exit();
  }
  replace(): void {
    this.active = false;
    this.generation++;
    try { this.onReplaced?.(); } catch (_) {}
  }
}
