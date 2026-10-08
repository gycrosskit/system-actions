import UIKit
import GYCWindowPolicy

@main
struct WindowPolicyChecks {
    @MainActor static func main() async {
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
    window.bounds = CGRect(x: 0, y: 0, width: 300, height: 600)
    window.frameOrigin = CGPoint(x: 50, y: 100)
    let observations = SystemObservations { window }
    var heights: [CGFloat] = []
    let oldStop = observations.observeKeyboardHeight { heights.append($0) }
    _ = observations.observeKeyboardHeight { heights.append($0) }
    oldStop()
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(rect: CGRect(x: 50, y: 500, width: 300, height: 200))])
    precondition(heights == [0, 0, 200], "old stop cannot remove new owner; screen frame converts through offset Window to host points")
    var themes: [Bool] = []
    let stopTheme = observations.observeDarkMode { themes.append($0) }
    _ = observations.observeDarkMode { themes.append($0) }
    stopTheme()
    window.traitCollection.userInterfaceStyle = .dark
    observations.refresh()
    precondition(themes == [false, false, true])
    observations.dispose()
    _ = observations.observeDarkMode { _ in preconditionFailure("disposed observer must not reopen") }
    let reentrant = SystemObservations { window }
    _ = reentrant.observeDarkMode { _ in reentrant.dispose() }
    reentrant.refresh()

    let fullscreenHost = FullscreenPolicyViewController()
    window.windowScene = UIWindowScene()
    window.addSubview(fullscreenHost.viewIfLoaded!)
    let firstFullscreen = fullscreenHost.createFullscreenLease(orientations: .landscape, layoutFullscreen: true)
    precondition(firstFullscreen.enter() == .requested)
    precondition(fullscreenHost.edgesForExtendedLayout == .all && fullscreenHost.extendedLayoutIncludesOpaqueBars)
    precondition(!firstFullscreen.requestedOrientationMatchesScene, "request is not a geometry success receipt")
    window.windowScene!.interfaceOrientation = .landscapeLeft
    precondition(firstFullscreen.requestedOrientationMatchesScene)
    let secondFullscreen = fullscreenHost.createFullscreenLease(statusBarHidden: false)
    precondition(secondFullscreen.enter() == .requested)
    firstFullscreen.release()
    precondition(secondFullscreen.isActive && !fullscreenHost.prefersStatusBarHidden)
    secondFullscreen.release(); secondFullscreen.release()
    precondition(!fullscreenHost.prefersStatusBarHidden && !fullscreenHost.prefersHomeIndicatorAutoHidden)
    precondition(fullscreenHost.supportedInterfaceOrientations == .all, "replacement restores first owner baseline")
    precondition(fullscreenHost.edgesForExtendedLayout.isEmpty && !fullscreenHost.extendedLayoutIncludesOpaqueBars)
    precondition(window.windowScene!.geometryRequests.last == .portrait, "orientation restoration survives replacement by a chrome-only owner")
    precondition(secondFullscreen.enter() == .unavailable)
    let retryHost = FullscreenPolicyViewController()
    let retryScene = UIWindowScene()
    window.windowScene = retryScene
    window.addSubview(retryHost.viewIfLoaded!)
    let retryLease = retryHost.createFullscreenLease(orientations: .landscape)
    precondition(retryLease.enter() == .requested)
    retryScene.interfaceOrientation = .landscapeLeft
    var restoreErrors = 0
    precondition(retryLease.exit { _ in restoreErrors += 1 } == .requested)
    let firstRestoreFailure = retryScene.geometryErrorHandlers.last!
    firstRestoreFailure(NSError(domain: "geometry", code: 1))
    await flushMainQueue()
    precondition(restoreErrors == 1 && !retryLease.isActive)
    precondition(retryLease.exit { _ in restoreErrors += 1 } == .requested, "failed restoration can retry without re-entering or recapturing baseline")
    precondition(retryScene.geometryRequests.last == .portrait)
    retryScene.interfaceOrientation = .portrait // 实际 Scene 回执；不把 requested 当作旋转成功。
    precondition(retryLease.exit() == .unavailable, "successful retry must not retain an unconditional restore permit")
    precondition(retryLease.enter() == .requested)
    retryScene.interfaceOrientation = .landscapeLeft
    precondition(retryLease.exit { _ in restoreErrors += 1 } == .requested)
    let obsoleteRestoreFailure = retryScene.geometryErrorHandlers.last!
    obsoleteRestoreFailure(NSError(domain: "geometry", code: 2))
    await flushMainQueue()
    precondition(restoreErrors == 2)
    let successor = retryHost.createFullscreenLease(orientations: .landscape, statusBarHidden: false)
    precondition(successor.enter() == .requested)
    let requestCount = retryScene.geometryRequests.count
    precondition(retryLease.exit() == .unavailable, "failed old lease cannot restore over a successor")
    obsoleteRestoreFailure(NSError(domain: "geometry", code: 3))
    await flushMainQueue()
    precondition(restoreErrors == 2 && retryScene.geometryRequests.count == requestCount)
    precondition(successor.isActive && !retryHost.prefersStatusBarHidden)
    successor.release()
    precondition(retryScene.geometryRequests.last == .portrait, "successor of a failed restoration inherits the first portrait baseline")
    retryScene.interfaceOrientation = .portrait
    let freshOwner = retryHost.createFullscreenLease(orientations: .landscape)
    precondition(freshOwner.enter() == .requested)
    retryScene.interfaceOrientation = .landscapeLeft
    precondition(freshOwner.exit() == .requested)
    retryScene.geometryErrorHandlers.last!(NSError(domain: "geometry", code: 4))
    await flushMainQueue()
    precondition(freshOwner.enter() == .requested, "same owner can reenter after a failed restoration")
    precondition(freshOwner.exit() == .requested)
    precondition(retryScene.geometryRequests.last == .portrait, "same owner reentry must not recapture the failed landscape baseline")
    let releasedRetry = retryHost.createFullscreenLease(orientations: .landscape)
    precondition(releasedRetry.enter() == .requested)
    releasedRetry.release { _ in restoreErrors += 1 }
    retryScene.geometryErrorHandlers.last!(NSError(domain: "geometry", code: 5))
    await flushMainQueue()
    precondition(restoreErrors == 3 && releasedRetry.enter() == .unavailable)
    let beforeReleaseRetry = retryScene.geometryRequests.count
    releasedRetry.release()
    precondition(retryScene.geometryRequests.count == beforeReleaseRetry + 1 && retryScene.geometryRequests.last == .portrait,
        "release is terminal for entering but can retry a failed restoration")
    print("Swift window policy source checks passed: process owners, capture changes, initial idle timer, window transfer and ended leases.")
}
    @MainActor private static func flushMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
