import UIKit

/// 已在主线程时保持同步语义；桥接同步入口不得执行阻塞 IO。
public enum UIKitExecutionContext {
    public static func run(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    public static func runOnMainActor(_ action: @escaping @MainActor () -> Void) {
        if Thread.isMainThread { MainActor.assumeIsolated(action) }
        else { DispatchQueue.main.async { MainActor.assumeIsolated(action) } }
    }

    public static func syncOnMainActor<T>(_ action: @escaping @MainActor () -> T) -> T {
        if Thread.isMainThread { return MainActor.assumeIsolated(action) }
        return DispatchQueue.main.sync { MainActor.assumeIsolated(action) }
    }
}

/// 每次展示即时查询系统 Scene；宿主可以注入实际根以及自定义容器的 active child。
@MainActor
public enum UIKitPresentationContext {
    public static var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foreground = scenes.filter { $0.activationState == .foregroundActive }
        return foreground.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? foreground.flatMap(\.windows).first { !$0.isHidden }
    }

    public static func topViewController(
        activeChild: (UIViewController) -> UIViewController? = { _ in nil }
    ) -> UIViewController? {
        topViewController(from: activeWindow?.rootViewController, activeChild: activeChild)
    }

    public static func topViewController(
        from root: UIViewController?,
        activeChild: (UIViewController) -> UIViewController? = { _ in nil }
    ) -> UIViewController? {
        var current = root
        var visited = Set<ObjectIdentifier>()
        while let controller = current {
            guard visited.insert(ObjectIdentifier(controller)).inserted else { return controller }
            let next: UIViewController?
            if let presented = controller.presentedViewController { next = presented }
            else if let navigation = controller as? UINavigationController { next = navigation.visibleViewController }
            else if let tab = controller as? UITabBarController { next = tab.selectedViewController }
            else if let split = controller as? UISplitViewController { next = split.viewControllers.last }
            else { next = activeChild(controller) }
            guard let next else { return controller }
            current = next
        }
        return nil
    }
}
