import UIKit
import GYCWindowPolicy

@MainActor
public func probe(window: UIWindow) {
    let controller = WindowPolicyController { window }
    let lease = controller.acquire()
    lease.update(screenRecordingAllowed: true)
    controller.refresh()
    lease.end()
}

@MainActor
public func presentationProbe(root: UIViewController, activeChild: (UIViewController) -> UIViewController?) -> UIViewController? {
    UIKitPresentationContext.topViewController(from: root, activeChild: activeChild)
}

public func executionProbe() -> Bool {
    UIKitExecutionContext.syncOnMainActor { Thread.isMainThread }
}
