import SwiftUI
import UIKit

@MainActor enum LiveBoardOrientation {
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
    static var owner: UUID?
    // Invalidate any queued launcher orientation request when a guest takes over.
    static var handoffGeneration: UInt64 = 0
    static func releaseForGuestLaunch(window: UIWindow?) {
        handoffGeneration &+= 1
        owner = nil
        mask = .allButUpsideDown
        if #available(iOS 16.0, *) { window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        // Do not request scene rotation here; the guest decides its own orientation.
    }
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
        handoffGeneration &+= 1
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
        LiveBoardOrientation.handoffGeneration &+= 1
        LiveBoardOrientation.owner = nil
        LiveBoardOrientation.mask = landscape.boolValue ? .landscapeRight : .portrait
    }

    @objc class func applyAuto() {
        // A previous Switchboard frame may have locked the shared host
        // window to Portrait. Release that mask for NxNative apps whose
        // App Settings > Orientation Lock is Disabled (system default).
        // No forced scene geometry change: the guest handles rotation.
        LiveBoardOrientation.handoffGeneration &+= 1
        LiveBoardOrientation.owner = nil
        LiveBoardOrientation.mask = .allButUpsideDown
    }
}

struct LiveBoardOrientationLock: UIViewRepresentable {
    let mask: UIInterfaceOrientationMask
    var active: Bool = true
    final class WindowObserver: UIView {
        let token = UUID()
        var requestedMask: UIInterfaceOrientationMask = .allButUpsideDown
        var enabled = false
        var applied = false
        var retired = false
        var revision: UInt64 = 0
        func apply() {
            guard window != nil, enabled, !retired else { return }
            applied = true
            LiveBoardOrientation.owner = token
            LiveBoardOrientation.apply(requestedMask, window: window)
        }
        func release() {
            revision &+= 1
            applied = false
            guard LiveBoardOrientation.owner == token else { return }
            LiveBoardOrientation.releaseForGuestLaunch(window: window)
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            revision &+= 1
            applied = false
            if window == nil { release() } else { apply() }
        }
    }
    func makeUIView(context: Context) -> WindowObserver { WindowObserver() }
    func updateUIView(_ view: WindowObserver, context: Context) {
        guard !view.retired else { return }
        if view.requestedMask != mask || view.enabled != active {
            view.revision &+= 1
            view.applied = false
        }
        view.requestedMask = mask
        view.enabled = active
        guard active else { view.release(); return }
        guard !view.applied else { return }
        let revision = view.revision
        let generation = LiveBoardOrientation.handoffGeneration
        DispatchQueue.main.async { [weak view] in
            guard let view, view.revision == revision,
                  LiveBoardOrientation.handoffGeneration == generation else { return }
            view.apply()
        }
    }
    static func dismantleUIView(_ view: WindowObserver, coordinator: ()) {
        view.retired = true
        view.enabled = false
        view.release()
    }
}
struct LiveBoardLandscapeLock: View {
    let enabled: Bool
    var body: some View { LiveBoardOrientationLock(mask: enabled ? .landscape : .allButUpsideDown) }
}
