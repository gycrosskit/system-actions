import { window } from '@kit.ArkUI';

/** 宿主传方向和系统栏目标；省略退出值时恢复首次接管前的窗口状态。 */
export interface FullscreenWindowPolicy {
  /** 进入方向；省略时不改方向。 */
  enterOrientation?: window.Orientation;
  /** 退出方向；优先于基线和 unspecifiedExitOrientation。 */
  exitOrientation?: window.Orientation;
  /** 仅当首次基线方向为 UNSPECIFIED 时使用的退出方向。 */
  unspecifiedExitOrientation?: window.Orientation;
  /** 进入时显示的系统栏；空数组隐藏全部，省略不修改。 */
  enterSystemBars?: Array<'status' | 'navigation'>;
  /** 退出显示系统栏；显式值优先于基线分支。 */
  exitSystemBars?: Array<'status' | 'navigation'>;
  /** 首次基线为全屏时的退出系统栏，省略时为空数组。 */
  exitSystemBarsWhenFullscreen?: Array<'status' | 'navigation'>;
  /** 首次基线非全屏时的退出系统栏，省略时显示 status/navigation。 */
  exitSystemBarsWhenNotFullscreen?: Array<'status' | 'navigation'>;
  /** 进入时是否延伸布局到系统栏区域；与 isFullScreen 分开。 */
  enterLayoutFullscreen?: boolean;
  /** 退出布局模式；省略时恢复首次接管前的 isLayoutFullScreen。 */
  exitLayoutFullscreen?: boolean;
}

/** 同一 Ability 共用 shared；resolver 留给宿主，库不读取业务页面或导航状态。 */
export class WindowPolicyController {
  /** 同一 Ability 共用的窗口策略所有者。 */
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

  /** 主线程创建未应用的 privacy lease。@param resolveWindow 宿主解析当前 Window 的异步函数。 */
  createLease(resolveWindow: () => Promise<window.Window>): WindowPolicyLease {
    return new WindowPolicyLease(this, resolveWindow);
  }

  /** 供 lease.update 使用的串行入口。@param lease 本 controller 创建的未释放 owner。@param resolveWindow 首次接管的 Window resolver。 */
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

  /** 供 privacy lease.release 使用；恢复失败保留基线供重试。@param lease 本 controller 的 owner。 */
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

  /**
   * 创建未进入的全屏 lease；一个 controller 仅允许一个全屏 owner。
   * @param resolveWindow 当前 Window 的异步 resolver。
   * @param policy 方向、布局和系统栏策略；构造时复制数组，避免排队期间外部修改。
   * @param onReplaced 被后继 owner 替换时同步通知，默认无回调。
   */
  createFullscreenLease(resolveWindow: () => Promise<window.Window>, policy: FullscreenWindowPolicy,
    onReplaced?: () => void): FullscreenWindowLease {
    return new FullscreenWindowLease(this, resolveWindow, policy, onReplaced);
  }

  /** lease.enter 的串行入口。@param lease 当前全屏 owner。@param revision 本次进入代次；迟任务不可操作 Window。 */
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

  /** lease.exit 的串行恢复入口；旧 owner 不触碰后继窗口。@param lease 退出的 owner。 */
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

  /**
   * 创建未应用的 privacy owner。
   * @param controller 同一 Ability 共用的策略 controller。
   * @param resolveWindow 首次应用时解析的窗口，释放前由 controller 持有。
   */
  constructor(controller: WindowPolicyController, resolveWindow: () => Promise<window.Window>) {
    this.controller = controller;
    this.resolveWindow = resolveWindow;
  }
  /** 是否已撤销 owner；释放后 update 不再修改窗口。 */
  get isReleased(): boolean { return this.released; }
  /** 本 owner 的录制意图，默认 false；不覆盖其他 owner 或窗口原有保护。 */
  get screenRecordingAllowed(): boolean { return this.allowed; }

  /** 主线程更新并等待策略生效。@param screenRecordingAllowed true 允许录制；基线或其他 owner 禁止时仍保护。 */
  update(screenRecordingAllowed: boolean): Promise<void> {
    if (this.released) return Promise.resolve();
    this.allowed = screenRecordingAllowed;
    return this.controller.apply(this, this.resolveWindow);
  }

  /** 即时撤销 owner，等待串行恢复；可重复调用以重试失败的恢复。 */
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
  /** 构造时复制的策略快照；宿主不要直接修改 lease 的快照。 */
  readonly policy: FullscreenWindowPolicy;
  /** 每次进入时解析当前窗口，避免缓存旧 Scene。 */
  readonly resolveWindow: () => Promise<window.Window>;
  private readonly controller: WindowPolicyController;
  private readonly onReplaced: (() => void) | undefined;

  /**
   * 创建未进入的全屏 owner。
   * @param controller 同一 Ability 共用的策略 controller。
   * @param resolveWindow 每次进入的窗口 resolver。
   * @param policy 窗口策略，复制其数组作为快照。
   * @param onReplaced 后继 owner 接管时的同步通知，异常忽略。
   */
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
  /** 是否已释放；释放后 enter 返回 false。 */
  get isReleased(): boolean { return this.released; }
  /** 当前是否请求全屏，替换或退出会立即变为 false。 */
  get isActive(): boolean { return this.active; }
  /** 单调请求代次，隔离异步进入与退出，不表示系统状态。 */
  get revision(): number { return this.generation; }

  /** 主线程进入并等待生效；后继替换/退出/释放期间返回 false，系统错误抛出并尝试恢复。 */
  enter(): Promise<boolean> {
    if (this.released) return Promise.resolve(false);
    this.active = true;
    return this.controller.enterFullscreen(this, ++this.generation);
  }
  /** 主线程即时撤销当前代次并等待恢复；旧 owner 不影响后继，恢复失败可重试。 */
  exit(): Promise<void> {
    this.active = false;
    this.generation++;
    return this.controller.exitFullscreen(this);
  }
  /** 主线程永久释放并执行 exit；重复调用可重试系统恢复。 */
  release(): Promise<void> {
    this.released = true;
    return this.exit();
  }
  /** 供 controller 同步撤销旧 owner；只通知宿主，不执行旧 owner 的窗口恢复。 */
  replace(): void {
    this.active = false;
    this.generation++;
    try { this.onReplaced?.(); } catch (_) {}
  }
}
