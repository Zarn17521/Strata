import SwiftUI
import UIKit

@MainActor enum LiveBoardOrientation {
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
    static var owner: UUID?
    static func apply(_ next: UIInterfaceOrientationMask, window: UIWindow?) {
        let changed = mask != next
        mask = next
        guard let scene = window?.windowScene else { return }
        let wrongOrientation = (next == .portrait && scene.interfaceOrientation != .portrait) || (next == .landscape && !scene.interfaceOrientation.isLandscape)
        guard changed || wrongOrientation else { return }
        if #available(iOS 16.0, *) {
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: next)) { _ in }
        } else { UIViewController.attemptRotationToDeviceOrientation() }
    }
    static func setLandscape(_ enabled: Bool, window: UIWindow?) {
        owner = nil
        apply(enabled ? .landscape : .allButUpsideDown, window: window)
    }
}

// Called only while an NxNative guest is being installed in the active
// UIWindow. This updates the orientation mask used by AppDelegate before
// UIKit processes the window-scene geometry request. The launcher remains
// portrait; it restores its own lock when presented again.
@objc(StrataNxGameOrientationBridge)
@MainActor final class StrataNxGameOrientationBridge: NSObject {
    @objc class func apply(_ landscape: NSNumber) {
        LiveBoardOrientation.owner = nil
        LiveBoardOrientation.mask = landscape.boolValue ? .landscapeRight : .portrait
    }

    @objc class func applyAuto() {
        // A previous Switchboard frame may have locked the shared host
        // window to Portrait. Release that mask for NxNative apps whose
        // App Settings > Orientation Lock is Disabled (system default).
        // No forced scene geometry change: the guest handles rotation.
        LiveBoardOrientation.owner = nil
        LiveBoardOrientation.mask = .allButUpsideDown
    }
}

struct LiveBoardOrientationLock: UIViewRepresentable {
    let mask: UIInterfaceOrientationMask
    final class WindowObserver: UIView {
        let token = UUID()
        var requestedMask: UIInterfaceOrientationMask = .allButUpsideDown
        var applied = false
        func apply() {
            guard window != nil else { return }
            applied = true
            LiveBoardOrientation.owner = token
            LiveBoardOrientation.apply(requestedMask, window: window)
        }
        override func didMoveToWindow() { super.didMoveToWindow(); applied = false; apply() }
    }
    func makeUIView(context: Context) -> WindowObserver { WindowObserver() }
    func updateUIView(_ view: WindowObserver, context: Context) {
        if view.requestedMask != mask { view.applied = false }
        view.requestedMask = mask
        if !view.applied { DispatchQueue.main.async { [weak view] in view?.apply() } }
    }
    static func dismantleUIView(_ view: WindowObserver, coordinator: ()) {
        guard LiveBoardOrientation.owner == view.token else { return }
        LiveBoardOrientation.owner = nil
        LiveBoardOrientation.apply(.allButUpsideDown, window: view.window)
    }
}
struct LiveBoardLandscapeLock: View {
    let enabled: Bool
    var body: some View { LiveBoardOrientationLock(mask: enabled ? .landscape : .allButUpsideDown) }
}
