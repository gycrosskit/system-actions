@_exported import Foundation
@_exported import CoreGraphics

@MainActor public final class UIApplication {
    public static let shared = UIApplication()
    public var isIdleTimerDisabled = false
    public var connectedScenes: Set<UIScene> = []
}
@MainActor public protocol UICoordinateSpace {}
@MainActor public final class UIScreen: UICoordinateSpace {
    public nonisolated static let capturedDidChangeNotification = Notification.Name("captured")
    public static let main = UIScreen()
    public var isCaptured = false
    public var coordinateSpace: UICoordinateSpace { self }
}
public struct UIViewAutoresizing: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let flexibleWidth = Self(rawValue: 1)
    public static let flexibleHeight = Self(rawValue: 2)
}
public final class UIColor { public static let black = UIColor() }
@MainActor open class UIView {
    public var bounds: CGRect
    public var frameOrigin: CGPoint
    public var backgroundColor: UIColor?
    public var autoresizingMask: UIViewAutoresizing = []
    public var isUserInteractionEnabled = false
    public var traitCollection = UITraitCollection()
    public var window: UIWindow? { (self as? UIWindow) ?? superview?.window }
    public private(set) weak var superview: UIView?
    public private(set) var subviews: [UIView] = []
    public init(frame: CGRect) { bounds = CGRect(origin: .zero, size: frame.size); frameOrigin = frame.origin }
    public func addSubview(_ view: UIView) { view.removeFromSuperview(); subviews.append(view); view.superview = self }
    public func removeFromSuperview() { superview?.subviews.removeAll { $0 === self }; superview = nil }
    public func bringSubviewToFront(_ view: UIView) { subviews.removeAll { $0 === view }; subviews.append(view) }
    public var absoluteOrigin: CGPoint {
        let parent = superview?.absoluteOrigin ?? .zero
        return CGPoint(x: parent.x + frameOrigin.x, y: parent.y + frameOrigin.y)
    }
    public func convert(_ rect: CGRect, from view: UIView?) -> CGRect {
        let source = view?.absoluteOrigin ?? window?.absoluteOrigin ?? .zero
        return rect.offsetBy(dx: source.x - absoluteOrigin.x, dy: source.y - absoluteOrigin.y)
    }
    open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
}
@MainActor public final class UIWindow: UIView {
    public var screen: UIScreen = .main
    public var isKeyWindow = false
    public var isHidden = false
    public var rootViewController: UIViewController?
    public var windowScene: UIWindowScene?
    public func convert(_ rect: CGRect, from coordinateSpace: UICoordinateSpace) -> CGRect {
        rect.offsetBy(dx: -frameOrigin.x, dy: -frameOrigin.y)
    }
    public override init(frame: CGRect) { super.init(frame: frame) }
}

@MainActor open class UIViewController {
    public var presentedViewController: UIViewController?
    public var viewIfLoaded: UIView? = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
    public var edgesForExtendedLayout: UIRectEdge = []
    public var extendedLayoutIncludesOpaqueBars = false
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    open var prefersStatusBarHidden: Bool { false }
    open var prefersHomeIndicatorAutoHidden: Bool { false }
    public func setNeedsStatusBarAppearanceUpdate() {}
    public func setNeedsUpdateOfHomeIndicatorAutoHidden() {}
    public func setNeedsUpdateOfSupportedInterfaceOrientations() {}
    public init() {}
}
@MainActor public class UINavigationController: UIViewController {
    public var visibleViewController: UIViewController?
}
@MainActor public class UITabBarController: UIViewController {
    public var selectedViewController: UIViewController?
}
@MainActor public class UISplitViewController: UIViewController {
    public var viewControllers: [UIViewController] = []
}
@MainActor public class UIScene: NSObject {
    public enum ActivationState { case foregroundActive, background }
    public var activationState: ActivationState = .foregroundActive
}
@MainActor public class UIWindowScene: UIScene {
    public var windows: [UIWindow] = []
    public var interfaceOrientation: UIInterfaceOrientation = .portrait
    public var geometryRequests: [UIInterfaceOrientationMask] = []
    public var geometryErrorHandlers: [(Error) -> Void] = []
    public enum GeometryPreferences { case iOS(interfaceOrientations: UIInterfaceOrientationMask) }
    public func requestGeometryUpdate(_ geometry: GeometryPreferences, errorHandler: @escaping (Error) -> Void) {
        if case let .iOS(orientations) = geometry { geometryRequests.append(orientations) }
        geometryErrorHandlers.append(errorHandler)
    }
}

public struct UIInterfaceOrientationMask: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let portrait = Self(rawValue: 1 << 1)
    public static let landscape = Self(rawValue: (1 << 3) | (1 << 4))
    public static let all = Self(rawValue: 30)
}
public struct UIRectEdge: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let all = Self(rawValue: 15)
}
public enum UIInterfaceOrientation: Int { case unknown = 0, portrait = 1, landscapeLeft = 3, landscapeRight = 4 }
public enum UIUserInterfaceStyle { case unspecified, light, dark }
public final class UITraitCollection {
    public var userInterfaceStyle: UIUserInterfaceStyle = .light
    public init() {}
}
public enum UIResponder {
    public static let keyboardWillChangeFrameNotification = Notification.Name("keyboardFrame")
    public static let keyboardFrameEndUserInfoKey = "keyboardFrameEnd"
}
extension NSValue { public var cgRectValue: CGRect { rectValue } }
