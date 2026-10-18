import UIKit
import GYCWindowPolicy

@MainActor
func consumeKeyboardObservation(view: @escaping () -> UIView?) {
    let observations = SystemObservations(hostView: view)
    let legacy: (@escaping (CGFloat) -> Void) -> (() -> Void) = observations.observeKeyboardHeight
    let stopLegacy = legacy { _ in }
    stopLegacy()
    let stop = observations.observeKeyboardHeight({ _ in }, onFrameChangeCompleted: { _ in })
    stop()
    observations.dispose()
}
