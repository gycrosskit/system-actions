import UIKit

/// 已在主线程时保持同步语义；桥接同步入口不得执行阻塞 IO。
public enum UIKitExecutionContext {
    /// - Parameter action: 主线程执行的短操作；当前在主线程时同步，否则异步投递，不阻塞调用线程。
    public static func run(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// - Parameter action: 主线程即时或异步投递的 MainActor 操作，不执行阻塞 IO。
    public static func runOnMainActor(_ action: @escaping @MainActor () -> Void) {
        if Thread.isMainThread { MainActor.assumeIsolated(action) }
        else { DispatchQueue.main.async { MainActor.assumeIsolated(action) } }
    }

    /// 同步取得 MainActor 结果；后台调用阻塞至执行完成，调用者不得持有主线程正在等待的锁。
    /// - Parameter action: 短且无阻塞 IO 的 MainActor 操作。
    public static func syncOnMainActor<T>(_ action: @escaping @MainActor () -> T) -> T {
        if Thread.isMainThread { return MainActor.assumeIsolated(action) }
        return DispatchQueue.main.sync { MainActor.assumeIsolated(action) }
    }
}

/// 每次展示即时查询系统 Scene；宿主可以注入实际根以及自定义容器的 active child。
@MainActor
public enum UIKitPresentationContext {
    /// 当前系统 Window：优先前台 key Window，再任意 key Window，最后前台可见 Window；不缓存 Scene。
    public static var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foreground = scenes.filter { $0.activationState == .foregroundActive }
        return foreground.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? foreground.flatMap(\.windows).first { !$0.isHidden }
    }

    /// 从当前 activeWindow 根解析顶层控制器，不缓存根。
    /// - Parameter activeChild: 自定义容器的活动 child，默认 nil；系统模态/Nav/Tab/Split 优先。
    public static func topViewController(
        activeChild: (UIViewController) -> UIViewController? = { _ in nil }
    ) -> UIViewController? {
        topViewController(from: activeWindow?.rootViewController, activeChild: activeChild)
    }

    /// 从宿主指定根解析顶层控制器，循环引用时停止在已访问节点。
    /// - Parameters:
    ///   - root: 当前宿主根，nil 返回 nil。
    ///   - activeChild: 自定义容器的活动 child，默认 nil。
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
