@_exported import Foundation

@MainActor public final class UIApplication {
    public static let shared = UIApplication()
    public var isIdleTimerDisabled = false
    public var connectedScenes: Set<UIScene> = []
}
@MainActor public final class UIScreen {
    public nonisolated static let capturedDidChangeNotification = Notification.Name("captured")
    public static let main = UIScreen()
    public var isCaptured = false
}
public struct UIViewAutoresizing: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let flexibleWidth = Self(rawValue: 1)
    public static let flexibleHeight = Self(rawValue: 2)
}
public final class UIColor { public static let black = UIColor() }
@MainActor public class UIView {
    public var bounds: CGRect
    public var backgroundColor: UIColor?
    public var autoresizingMask: UIViewAutoresizing = []
    public var isUserInteractionEnabled = false
    public private(set) weak var superview: UIView?
    public private(set) var subviews: [UIView] = []
    public init(frame: CGRect) { bounds = frame }
    public func addSubview(_ view: UIView) { view.removeFromSuperview(); subviews.append(view); view.superview = self }
    public func removeFromSuperview() { superview?.subviews.removeAll { $0 === self }; superview = nil }
    public func bringSubviewToFront(_ view: UIView) { subviews.removeAll { $0 === view }; subviews.append(view) }
}
@MainActor public final class UIWindow: UIView {
    public var screen: UIScreen = .main
    public var isKeyWindow = false
    public var isHidden = false
    public var rootViewController: UIViewController?
    public override init(frame: CGRect) { super.init(frame: frame) }
}

@MainActor public class UIViewController {
    public var presentedViewController: UIViewController?
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
}
