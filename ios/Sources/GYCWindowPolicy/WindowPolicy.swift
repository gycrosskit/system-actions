import UIKit

/** iOS 公开 API 只能在录屏/镜像状态下遮罩，不能阻止静态截图。 */
@MainActor
public final class WindowPolicyController {
    private let windowResolver: () -> UIWindow?
    private static let state = WindowPolicyState()

    /// - Parameter windowResolver: 主线程即时解析宿主当前 Window；无窗口时返回 nil。
    public init(windowResolver: @escaping () -> UIWindow?) {
        self.windowResolver = windowResolver
    }

    /// 主线程获取 owner；任一 owner 常亮/禁录即生效，宿主在生命周期结束时显式 end。
    /// - Parameters:
    ///   - keepScreenOn: 默认 true；进程 idle timer 的既有禁用状态不会被放宽。
    ///   - screenRecordingAllowed: 默认 false；捕获/镜像时遮罩，不阻止静态截图。
    public func acquire(keepScreenOn: Bool = true, screenRecordingAllowed: Bool = false) -> WindowPolicyLease {
        let lease = WindowPolicyLease(keepScreenOn: keepScreenOn, screenRecordingAllowed: screenRecordingAllowed,
                                      windowResolver: windowResolver)
        Self.state.add(lease)
        return lease
    }

    /// 宿主 Window/Scene 切换后调用，重新解析窗口并转移遮罩。
    public func refresh() { Self.state.refresh() }

    fileprivate static func update() { state.refresh() }
    fileprivate static func release(_ lease: WindowPolicyLease) { state.remove(lease) }
}

/// 主线程拥有的窗口策略句柄；只影响自身意图，结束后无法重新接管窗口。
@MainActor
public final class WindowPolicyLease {
    fileprivate let id = UUID()
    fileprivate let keepScreenOn: Bool
    fileprivate var screenRecordingAllowed: Bool
    fileprivate let windowResolver: () -> UIWindow?
    private var ended = false

    fileprivate init(keepScreenOn: Bool, screenRecordingAllowed: Bool, windowResolver: @escaping () -> UIWindow?) {
        self.keepScreenOn = keepScreenOn
        self.screenRecordingAllowed = screenRecordingAllowed
        self.windowResolver = windowResolver
    }

    /// 更新此 owner 的录制意图，已结束时忽略；其他 owner 和初始策略优先。
    /// - Parameter screenRecordingAllowed: true 允许本 owner 的窗口被录制。
    public func update(screenRecordingAllowed: Bool) {
        guard !ended else { return }
        self.screenRecordingAllowed = screenRecordingAllowed
        WindowPolicyController.update()
    }

    /// 幂等；宿主须在生命周期结束时显式释放，避免依赖 deinit 的线程和时机。
    public func end() {
        guard !ended else { return }
        ended = true
        WindowPolicyController.release(self)
    }
}

/** idle timer 是进程状态，所有 controller 共用一个 owner 集合，不能互相提前恢复。 */
@MainActor
private final class WindowPolicyState {
    private var owners: [UUID: WindowPolicyLease] = [:]
    private var initialIdleTimerDisabled = false
    private var captureObserver: NSObjectProtocol?
    private var shields: [ObjectIdentifier: UIView] = [:]

    func add(_ lease: WindowPolicyLease) {
        if owners.isEmpty {
            initialIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            captureObserver = NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        owners[lease.id] = lease
        refresh()
    }

    func remove(_ lease: WindowPolicyLease) {
        owners.removeValue(forKey: lease.id)
        refresh()
        if owners.isEmpty {
            if let captureObserver { NotificationCenter.default.removeObserver(captureObserver) }
            captureObserver = nil
        }
    }

    func refresh() {
        guard !owners.isEmpty || captureObserver != nil else { return }
        UIApplication.shared.isIdleTimerDisabled = initialIdleTimerDisabled || owners.values.contains { $0.keepScreenOn }
        var protectedWindows: [ObjectIdentifier: UIWindow] = [:]
        for owner in owners.values where !owner.screenRecordingAllowed {
            if let window = owner.windowResolver(), window.screen.isCaptured {
                protectedWindows[ObjectIdentifier(window)] = window
            }
        }
        for key in Array(shields.keys) where protectedWindows[key] == nil {
            shields.removeValue(forKey: key)?.removeFromSuperview()
        }
        for (key, window) in protectedWindows {
            if let shield = shields[key] {
                window.bringSubviewToFront(shield)
                continue
            }
            let shield = UIView(frame: window.bounds)
            shield.backgroundColor = .black
            shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            shield.isUserInteractionEnabled = true
            window.addSubview(shield)
            shields[key] = shield
        }
    }
}
