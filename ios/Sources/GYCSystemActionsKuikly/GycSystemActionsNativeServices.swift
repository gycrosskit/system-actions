import UIKit

/// 当前 Renderer 的 native owner，观察与常亮共用既有服务，不创建另一套窗口状态。
@MainActor
public final class GycSystemActionsNativeServices {
    private let observations: SystemObservations
    private let policy: WindowPolicyController
    private var keepScreen: WindowPolicyLease?

    init(view: @escaping () -> UIView?) {
        observations = SystemObservations(hostView: view)
        policy = WindowPolicyController(windowResolver: { view()?.window })
    }

    public func setKeepScreenOn(_ enabled: NSNumber) -> NSNumber {
        if enabled.boolValue {
            if keepScreen == nil { keepScreen = policy.acquire(keepScreenOn: true, screenRecordingAllowed: true) }
        } else {
            keepScreen?.end()
            keepScreen = nil
        }
        return NSNumber(value: true)
    }

    public func observeKeyboardHeight(_ callback: @escaping (NSNumber) -> NSNumber) -> () -> NSNumber {
        let stop = observations.observeKeyboardHeight { _ = callback(NSNumber(value: Float($0))) }
        return { stop(); return NSNumber(value: true) }
    }

    public func observeDarkMode(_ callback: @escaping (NSNumber) -> NSNumber) -> () -> NSNumber {
        let stop = observations.observeDarkMode { _ = callback(NSNumber(value: $0)) }
        return { stop(); return NSNumber(value: true) }
    }

    public func dispose() {
        observations.dispose()
        keepScreen?.end()
        keepScreen = nil
    }
}
