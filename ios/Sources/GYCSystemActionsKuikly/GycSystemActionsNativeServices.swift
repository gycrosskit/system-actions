import UIKit

/// 当前 Renderer 的 native owner，观察与常亮共用既有服务，不创建另一套窗口状态。
@MainActor
public final class GycSystemActionsNativeServices {
    private let view: () -> UIView?
    private let observations: SystemObservations
    private let policy: WindowPolicyController
    private var keepScreen: WindowPolicyLease?

    init(view: @escaping () -> UIView?) {
        self.view = view
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
        var height: CGFloat = 0
        let publish: (CGFloat) -> Void = { value in
            height = value
            _ = callback(NSNumber(value: Float(value)))
        }
        let stop = observations.observeKeyboardHeight({ value in
            // 零相交可能早于收起动画完成，不能提前放行依赖布局的弹窗。
            if value > 0 || height == 0 { publish(value) }
        }, onFrameChangeCompleted: { [weak self] value in
            guard value != height else { return }
            if value == 0 { self?.view()?.window?.layoutIfNeeded(); self?.view()?.layoutIfNeeded() }
            publish(value)
        })
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
