import UIKit
import GYCWindowPolicy

@main
struct WindowPolicyChecks {
    @MainActor static func main() {
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
