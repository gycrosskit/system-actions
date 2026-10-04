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
