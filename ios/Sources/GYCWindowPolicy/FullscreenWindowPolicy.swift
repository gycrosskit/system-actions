import UIKit

/// requested 是 UIKit 请求已发出；实际旋转须读 Scene 或宿主 transition 回执，不能当作已全屏。
public enum FullscreenRequestResult { case requested, unavailable, unsupported }

/// 宿主显式使用/继承此 controller 才能控制状态栏、home indicator 与支持方向，不操作任意业务 controller。
@MainActor
open class FullscreenPolicyViewController: UIViewController {
    fileprivate var fullscreenOwner: FullscreenWindowLease?
    // UIKit 无成功回调；实际 Scene 恢复前保留首次基线，后继 owner 不能采到尚未恢复的方向。
    fileprivate var fullscreenRestoration: FullscreenWindowLease?
    fileprivate var geometryRevision = 0
    fileprivate var fullscreenOrientations: UIInterfaceOrientationMask?
    fileprivate var hideStatusBar: Bool?
    fileprivate var hideHomeIndicator: Bool?

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        fullscreenOrientations ?? super.supportedInterfaceOrientations
    }
    open override var prefersStatusBarHidden: Bool { hideStatusBar ?? super.prefersStatusBarHidden }
    open override var prefersHomeIndicatorAutoHidden: Bool { hideHomeIndicator ?? super.prefersHomeIndicatorAutoHidden }

    /// nil 不请求旋转；非 nil 在 iOS16+ 使用公开 geometry API，仍受 Info.plist/父容器/多任务策略限制。
    public func createFullscreenLease(orientations: UIInterfaceOrientationMask? = nil,
        statusBarHidden: Bool = true, homeIndicatorHidden: Bool = true,
        layoutFullscreen: Bool? = nil) -> FullscreenWindowLease {
        if let orientations { precondition(!orientations.isEmpty) }
        return FullscreenWindowLease(controller: self, orientations: orientations,
            statusBarHidden: statusBarHidden, homeIndicatorHidden: homeIndicatorHidden, layoutFullscreen: layoutFullscreen)
    }

    fileprivate func refreshChrome() {
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        if #available(iOS 16.0, *) { setNeedsUpdateOfSupportedInterfaceOrientations() }
    }

    fileprivate func requestGeometry(_ orientations: UIInterfaceOrientationMask?,
        onError: @escaping (Error) -> Void) {
        guard let orientations, #available(iOS 16.0, *), let scene = viewIfLoaded?.window?.windowScene else { return }
        let revision = geometryRevision
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { [weak self] error in
            DispatchQueue.main.async {
                if self?.geometryRevision == revision { onError(error) }
            }
        }
    }
}

/// 一个 controller 只有一个 owner；替换继承首次基线，旧 exit 不会恢复后继状态。
@MainActor
public final class FullscreenWindowLease {
    private weak var controller: FullscreenPolicyViewController?
    private let orientations: UIInterfaceOrientationMask?
    private let statusBarHidden: Bool
    private let homeIndicatorHidden: Bool
    private let layoutFullscreen: Bool?
    private var originalOrientations: UIInterfaceOrientationMask?
    private var originalStatusBar: Bool?
    private var originalHomeIndicator: Bool?
    private var originalSceneOrientation: UIInterfaceOrientationMask?
    private var geometryChanged = false
    private var layoutChanged = false
    private var originalEdges: UIRectEdge = []
    private var originalIncludesOpaqueBars = false
    private var restoreRetryRevision: Int?
    private var released = false
    public private(set) var isActive = false

    fileprivate init(controller: FullscreenPolicyViewController, orientations: UIInterfaceOrientationMask?,
        statusBarHidden: Bool, homeIndicatorHidden: Bool, layoutFullscreen: Bool?) {
        self.controller = controller; self.orientations = orientations
        self.statusBarHidden = statusBarHidden; self.homeIndicatorHidden = homeIndicatorHidden
        self.layoutFullscreen = layoutFullscreen
    }

    /// 只反映当前 Scene 方向是否满足请求，不能证明状态栏/home indicator 已完成动画。
    public var requestedOrientationMatchesScene: Bool {
        guard isActive, let scene = controller?.viewIfLoaded?.window?.windowScene else { return false }
        guard let orientations else { return true }
        return orientations.contains(UIInterfaceOrientationMask(rawValue: 1 << scene.interfaceOrientation.rawValue))
    }

    public func enter(onGeometryError: @escaping (Error) -> Void = { _ in }) -> FullscreenRequestResult {
        guard !released, let controller, let scene = controller.viewIfLoaded?.window?.windowScene else { return .unavailable }
        if orientations != nil {
            guard #available(iOS 16.0, *) else { return .unsupported }
        }
        if controller.fullscreenOwner === self { return .requested }
        discardCompletedRestoration(controller)
        if let previous = controller.fullscreenOwner ?? controller.fullscreenRestoration {
            originalOrientations = previous.originalOrientations
            originalStatusBar = previous.originalStatusBar
            originalHomeIndicator = previous.originalHomeIndicator
            originalSceneOrientation = previous.originalSceneOrientation
            geometryChanged = previous.geometryChanged
            layoutChanged = previous.layoutChanged
            originalEdges = previous.originalEdges
            originalIncludesOpaqueBars = previous.originalIncludesOpaqueBars
            previous.isActive = false
            previous.restoreRetryRevision = nil
            if previous !== self { previous.released = true }
        } else {
            originalOrientations = controller.fullscreenOrientations
            originalStatusBar = controller.hideStatusBar
            originalHomeIndicator = controller.hideHomeIndicator
            originalSceneOrientation = UIInterfaceOrientationMask(rawValue: 1 << scene.interfaceOrientation.rawValue)
            originalEdges = controller.edgesForExtendedLayout
            originalIncludesOpaqueBars = controller.extendedLayoutIncludesOpaqueBars
        }
        controller.fullscreenOwner = self
        controller.fullscreenRestoration = nil
        restoreRetryRevision = nil
        geometryChanged = geometryChanged || orientations != nil
        layoutChanged = layoutChanged || layoutFullscreen != nil
        controller.geometryRevision += 1
        controller.fullscreenOrientations = orientations ?? controller.fullscreenOrientations
        controller.hideStatusBar = statusBarHidden
        controller.hideHomeIndicator = homeIndicatorHidden
        if let layoutFullscreen {
            controller.edgesForExtendedLayout = layoutFullscreen ? .all : []
            controller.extendedLayoutIncludesOpaqueBars = layoutFullscreen
        }
        isActive = true
        controller.refreshChrome()
        controller.requestGeometry(orientations, onError: onGeometryError)
        return .requested
    }

    @discardableResult
    public func exit(onGeometryError: @escaping (Error) -> Void = { _ in }) -> FullscreenRequestResult {
        guard let controller else { return .unavailable }
        discardCompletedRestoration(controller)
        let ownsWindow = isActive && controller.fullscreenOwner === self
        let canRetry = controller.fullscreenOwner == nil && controller.fullscreenRestoration === self &&
            restoreRetryRevision == controller.geometryRevision
        guard ownsWindow || canRetry else { return .unavailable }
        restoreRetryRevision = nil
        isActive = false
        controller.fullscreenOwner = nil
        controller.geometryRevision += 1
        controller.fullscreenOrientations = originalOrientations
        controller.hideStatusBar = originalStatusBar
        controller.hideHomeIndicator = originalHomeIndicator
        if layoutChanged {
            controller.edgesForExtendedLayout = originalEdges
            controller.extendedLayoutIncludesOpaqueBars = originalIncludesOpaqueBars
        }
        controller.refreshChrome()
        controller.fullscreenRestoration = geometryChanged ? self : nil
        let revision = controller.geometryRevision
        controller.requestGeometry(geometryChanged ? originalSceneOrientation : nil) { [weak self, weak controller] error in
            guard let self, let controller, controller.fullscreenOwner == nil, controller.fullscreenRestoration === self,
                  controller.geometryRevision == revision else { return }
            // UIKit 只有错误回调；保留失败恢复的基线供 exit/release 重试，不占用后继 owner。
            self.restoreRetryRevision = revision
            onGeometryError(error)
        }
        return .requested
    }

    private func discardCompletedRestoration(_ controller: FullscreenPolicyViewController) {
        guard let pending = controller.fullscreenRestoration,
              let original = pending.originalSceneOrientation,
              let scene = controller.viewIfLoaded?.window?.windowScene,
              original.contains(UIInterfaceOrientationMask(rawValue: 1 << scene.interfaceOrientation.rawValue)) else { return }
        pending.restoreRetryRevision = nil
        controller.fullscreenRestoration = nil
    }

    /// 永久禁止再次 enter；恢复失败后仍可 exit/release 重试，旧 owner 不影响后继。
    public func release(onGeometryError: @escaping (Error) -> Void = { _ in }) {
        _ = exit(onGeometryError: onGeometryError)
        released = true
    }
}
