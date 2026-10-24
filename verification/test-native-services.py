"""执行实际 Kuikly native services；UIKit/系统观察仅作为受控事件边界。"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'ios/Sources/GYCSystemActionsKuikly/GycSystemActionsNativeServices.swift').read_text().replace('import UIKit', 'import Foundation')
fixture = '''
final class UIView {
    var window: UIView?
    var layouts = 0
    func layoutIfNeeded() { layouts += 1 }
}
@MainActor final class WindowPolicyLease { func end() {} }
@MainActor final class WindowPolicyController {
    init(windowResolver: @escaping () -> UIView?) {}
    func acquire(keepScreenOn: Bool, screenRecordingAllowed: Bool) -> WindowPolicyLease { WindowPolicyLease() }
}
@MainActor final class SystemObservations {
    static var last: SystemObservations!
    var change: ((CGFloat) -> Void)?
    var completed: ((CGFloat) -> Void)?
    init(hostView: @escaping () -> UIView?) { Self.last = self }
    func observeKeyboardHeight(_ callback: @escaping (CGFloat) -> Void, onFrameChangeCompleted: ((CGFloat) -> Void)?) -> () -> Void {
        change = callback; completed = onFrameChangeCompleted; callback(0)
        return { self.change = nil; self.completed = nil }
    }
    func observeDarkMode(_ callback: @escaping (Bool) -> Void) -> () -> Void { callback(false); return {} }
    func dispose() { change = nil; completed = nil }
}
'''
checks = '''
MainActor.assumeIsolated {
    let view = UIView(), window = UIView(); view.window = window
    let services = GycSystemActionsNativeServices(view: { view })
    var values: [Float] = []
    let stop = services.observeKeyboardHeight { values.append($0.floatValue); return true }
    let observation = SystemObservations.last!
    observation.change?(80)
    observation.change?(0)
    precondition(values == [0, 80], "will-change zero cannot release layout-dependent dialogs")
    observation.completed?(0)
    precondition(values == [0, 80, 0] && view.layouts == 1 && window.layouts == 1)
    observation.completed?(0)
    precondition(values == [0, 80, 0] && view.layouts == 1, "duplicate completion is ignored")
    observation.completed?(40)
    precondition(values == [0, 80, 0, 40])
    _ = stop()
    observation.completed?(0)
    precondition(values == [0, 80, 0, 40])
    services.dispose()
}
print("Native Module keyboard completion, layout ordering, duplicate suppression and stop passed")
'''
with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / 'main.swift'
    path.write_text(fixture + source + checks)
    subprocess.run(['xcrun', 'swift', '-module-cache-path', str(Path(folder)/'modules'), str(path)], check=True)
