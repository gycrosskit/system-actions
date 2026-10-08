import UIKit

/// MainActor 原生观察；宿主提供当前 View，切换 Window/Scene 后 refresh，离开时 dispose。
@MainActor
public final class SystemObservations {
    private let hostView: () -> UIView?
    private var keyboardToken: UUID?
    private var keyboardObserver: NSObjectProtocol?
    private var darkToken: UUID?
    private var traitView: TraitObserverView?
    private var disposed = false

    public init(hostView: @escaping () -> UIView?) { self.hostView = hostView }

    /// 初值 0；键盘与当前 host View 相交高度，单位 points。旧 stop 不停止后继观察。
    public func observeKeyboardHeight(_ onChange: @escaping (CGFloat) -> Void) -> () -> Void {
        stopKeyboardHeight()
        guard !disposed else { return {} }
        let token = UUID()
        keyboardToken = token
        onChange(0)
        guard !disposed, keyboardToken == token else { return {} }
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, !self.disposed, self.keyboardToken == token,
                      let view = self.hostView(), let window = view.window,
                      let value = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
                let frame = value.cgRectValue
                let windowFrame = window.convert(frame, from: window.screen.coordinateSpace)
                let overlap = view.bounds.intersection(view.convert(windowFrame, from: window))
                onChange(overlap.isNull ? 0 : overlap.height)
            }
        }
        return { [weak self] in if self?.keyboardToken == token { self?.stopKeyboardHeight() } }
    }

    /// 初始值和后续值取当前 View 的实际 trait；不修改宿主主题。
    public func observeDarkMode(_ onChange: @escaping (Bool) -> Void) -> () -> Void {
        stopDarkMode()
        guard !disposed else { return {} }
        let token = UUID()
        darkToken = token
        var last = hostView()?.traitCollection.userInterfaceStyle == .dark
        let observer = TraitObserverView(frame: .zero)
        observer.isUserInteractionEnabled = false
        observer.onChange = { [weak self] dark in
            guard let self, !self.disposed, self.darkToken == token else { return }
            if dark != last { last = dark; onChange(dark) }
        }
        traitView = observer
        onChange(last)
        if !disposed, darkToken == token { refresh() }
        return { [weak self] in if self?.darkToken == token { self?.stopDarkMode() } }
    }

    /// 将 trait 观察移到当前 host，不保留旧 Scene。
    public func refresh() {
        guard !disposed, let observer = traitView else { return }
        let host = hostView()
        if observer.superview !== host {
            observer.removeFromSuperview()
            host?.addSubview(observer)
        }
        if let host { observer.onChange?(host.traitCollection.userInterfaceStyle == .dark) }
    }

    public func stopKeyboardHeight() {
        keyboardToken = nil
        if let keyboardObserver { NotificationCenter.default.removeObserver(keyboardObserver) }
        keyboardObserver = nil
    }

    public func stopDarkMode() {
        darkToken = nil
        traitView?.onChange = nil
        traitView?.removeFromSuperview()
        traitView = nil
    }

    /// 永久关闭；初始回调中关闭也不会重新注册原生观察。
    public func dispose() {
        disposed = true
        stopKeyboardHeight()
        stopDarkMode()
    }
}

@MainActor
private final class TraitObserverView: UIView {
    var onChange: ((Bool) -> Void)?
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            onChange?(traitCollection.userInterfaceStyle == .dark)
        }
    }
}
