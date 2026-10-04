import UIKit
import GYCWindowPolicy

@main
struct WindowPolicyChecks {
    @MainActor static func main() {
    var ran = false
    UIKitExecutionContext.run { ran = true }
    precondition(ran, "main thread run preserves immediate semantics")
    let actorValue = UIKitExecutionContext.syncOnMainActor { 42 }
    precondition(actorValue == 42)
    UIKitExecutionContext.runOnMainActor { ran = false }
    precondition(!ran)
    let foreground = UIWindowScene(), background = UIWindowScene()
    background.activationState = .background
    let frontWindow = UIWindow(frame: CGRect()), backWindow = UIWindow(frame: CGRect())
    frontWindow.isKeyWindow = true; backWindow.isKeyWindow = true
    foreground.windows = [frontWindow]; background.windows = [backWindow]
    UIApplication.shared.connectedScenes = [background, foreground]
    precondition(UIKitPresentationContext.activeWindow === frontWindow)
    let root = UINavigationController(), tab = UITabBarController(), split = UISplitViewController()
    let custom = UIViewController(), child = UIViewController(), modal = UIViewController()
    root.visibleViewController = tab; tab.selectedViewController = split
    split.viewControllers = [UIViewController(), custom]; child.presentedViewController = modal
    frontWindow.rootViewController = root
    let top = UIKitPresentationContext.topViewController(activeChild: { $0 === custom ? child : nil })
    precondition(top === modal)
    let replacementRoot = UIViewController(); frontWindow.rootViewController = replacementRoot
    precondition(UIKitPresentationContext.topViewController() === replacementRoot, "root is never cached")
    replacementRoot.presentedViewController = replacementRoot
    precondition(UIKitPresentationContext.topViewController() === replacementRoot, "cycle guard")
    foreground.windows = []
    precondition(UIKitPresentationContext.activeWindow === backWindow)
    backWindow.isKeyWindow = false; foreground.windows = [frontWindow]; frontWindow.isKeyWindow = false
    precondition(UIKitPresentationContext.activeWindow === frontWindow, "visible foreground fallback")
    let window = UIWindow(frame: CGRect())
    var currentWindow: UIWindow? = window
    let firstController = WindowPolicyController { currentWindow }
    let secondController = WindowPolicyController { window }
    firstController.refresh()
    precondition(!UIApplication.shared.isIdleTimerDisabled)
    UIScreen.main.isCaptured = true
    let first = firstController.acquire()
    let second = secondController.acquire(screenRecordingAllowed: true)
    precondition(UIApplication.shared.isIdleTimerDisabled)
    precondition(window.subviews.count == 1)
    first.end()
    precondition(window.subviews.isEmpty)
    precondition(UIApplication.shared.isIdleTimerDisabled, "other controller still owns idle timer")
    first.update(screenRecordingAllowed: false)
    precondition(window.subviews.isEmpty, "ended lease cannot restore shield")
    second.update(screenRecordingAllowed: false)
    precondition(window.subviews.count == 1)
    UIScreen.main.isCaptured = false
    NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: UIScreen.main)
    precondition(window.subviews.isEmpty)
    UIScreen.main.isCaptured = true
    NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: UIScreen.main)
    precondition(window.subviews.count == 1)
    second.end(); second.end()
    precondition(!UIApplication.shared.isIdleTimerDisabled)
    precondition(window.subviews.isEmpty)

    UIApplication.shared.isIdleTimerDisabled = true
    let third = firstController.acquire(keepScreenOn: false)
    precondition(window.subviews.count == 1)
    let replacement = UIWindow(frame: window.bounds)
    currentWindow = replacement
    firstController.refresh()
    precondition(window.subviews.isEmpty && replacement.subviews.count == 1)
    third.end()
    precondition(UIApplication.shared.isIdleTimerDisabled, "initial idle timer preserved")
    precondition(replacement.subviews.isEmpty)
    print("Swift window policy source checks passed: process owners, capture changes, initial idle timer, window transfer and ended leases.")
}
}
