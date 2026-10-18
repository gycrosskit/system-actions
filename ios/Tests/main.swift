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
    let legacyObserve: (@escaping (CGFloat) -> Void) -> (() -> Void) = observations.observeKeyboardHeight
    let oldStop = legacyObserve { heights.append($0) }
    _ = observations.observeKeyboardHeight { heights.append($0) }
    oldStop()
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(rect: CGRect(x: 50, y: 500, width: 300, height: 200))])
    precondition(heights == [0, 0, 200], "old stop cannot remove new owner; screen frame converts through offset Window to host points")
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(heights == [0, 0, 200], "legacy height API keeps its will-change timing")

    var changes: [CGFloat] = [], completed: [CGFloat] = []
    let oldCompletedStop = observations.observeKeyboardHeight({ changes.append($0) }, onFrameChangeCompleted: { completed.append($0) })
    let stopCompleted = observations.observeKeyboardHeight({ changes.append($0) }, onFrameChangeCompleted: { completed.append($0) })
    oldCompletedStop()
    precondition(changes == [0, 0] && completed.isEmpty, "completion has no synthetic initial value")
    let intersectingFrame = NSValue(rect: CGRect(x: 50, y: 500, width: 300, height: 200))
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    precondition(changes == [0, 0, 200] && completed.isEmpty)
    NotificationCenter.default.post(name: UIResponder.keyboardDidChangeFrameNotification, object: window.screen,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    precondition(completed == [200] && changes == [0, 0, 200], "completed frame uses the same current host coordinate conversion")
    let otherScreen = UIScreen()
    for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardDidChangeFrameNotification, UIResponder.keyboardDidHideNotification] {
        NotificationCenter.default.post(name: name, object: otherScreen,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    }
    precondition(completed == [200] && changes == [0, 0, 200], "another display cannot update or clear the current host owner")
    let floatingFrame = NSValue(rect: CGRect(x: 400, y: 300, width: 200, height: 200))
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: floatingFrame])
    precondition(changes.last == 0 && completed == [200], "will-change zero is not a completion receipt")
    NotificationCenter.default.post(name: UIResponder.keyboardDidChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: floatingFrame])
    precondition(completed == [200, 0], "floating keyboard can leave the host without a did-hide notification")
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(rect: CGRect(x: 50, y: 700, width: 300, height: 200))])
    precondition(completed == [200, 0], "dismissal target frame cannot release a pending dialog before completion")
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(completed == [200, 0, 0], "did-hide completes dismissal even without frame metadata")
    stopCompleted()
    let changeCount = changes.count
    NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    NotificationCenter.default.post(name: UIResponder.keyboardDidChangeFrameNotification, object: nil,
        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: intersectingFrame])
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(changes.count == changeCount && completed == [200, 0, 0], "stop removes all notifications of this owner")
    _ = observations.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { completed.append($0) })
    var themes: [Bool] = []
    let stopTheme = observations.observeDarkMode { themes.append($0) }
    _ = observations.observeDarkMode { themes.append($0) }
    stopTheme()
    window.traitCollection.userInterfaceStyle = .dark
    observations.refresh()
    precondition(themes == [false, false, true])
    observations.dispose()
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(completed == [200, 0, 0], "dispose removes completion notifications")
    _ = observations.observeDarkMode { _ in preconditionFailure("disposed observer must not reopen") }
    let reentrant = SystemObservations { window }
    _ = reentrant.observeDarkMode { _ in reentrant.dispose() }
    reentrant.refresh()
    let keyboardReentrant = SystemObservations { window }
    _ = keyboardReentrant.observeKeyboardHeight({ _ in keyboardReentrant.dispose() }, onFrameChangeCompleted: { _ in
        preconditionFailure("disposing in the initial callback must not register completion notifications")
    })
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)

    let completionReentrant = SystemObservations { window }
    var stoppedCompletions = 0
    var stopDuringCompletion: () -> Void = {}
    stopDuringCompletion = completionReentrant.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { _ in
        stoppedCompletions += 1
        stopDuringCompletion()
    })
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(stoppedCompletions == 1, "stopping inside completion removes every notification")
    var oldCompletions = 0, newCompletions = 0
    let replacedStop = completionReentrant.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { _ in
        oldCompletions += 1
        _ = completionReentrant.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { _ in newCompletions += 1 })
    })
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    replacedStop()
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(oldCompletions == 1 && newCompletions == 1, "replacing inside completion preserves only the new owner")
    var disposedCompletions = 0
    _ = completionReentrant.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { _ in
        disposedCompletions += 1
        completionReentrant.dispose()
    })
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    precondition(disposedCompletions == 1, "disposing inside completion does not re-register observers")

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
