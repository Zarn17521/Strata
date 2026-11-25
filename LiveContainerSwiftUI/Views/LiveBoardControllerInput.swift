import Foundation
import GameController

/// Input is owned only while the launcher is visible. No guest controller configuration is changed.
@MainActor
final class LiveBoardControllerInput: ObservableObject {
    static let pauseNotification = Notification.Name("LiveBoardPauseController")
    static let resumeNotification = Notification.Name("LiveBoardResumeController")
    static let launchFailedNotification = Notification.Name("LiveBoardLaunchFailed")
    enum Command: Equatable { case left, right, up, down, confirm, back, details, favorite, previousSection, nextSection }
    @Published private(set) var connected = false
    @Published private(set) var confirmSymbol = "a.circle"
    @Published private(set) var detailsSymbol = "x.circle"
    var onCommand: ((Command) -> Void)?

    // Visual feedback states for custom skin overlay
    @Published var aPressed = false
    @Published var bPressed = false
    @Published var xPressed = false
    @Published var yPressed = false
    @Published var lPressed = false
    @Published var rPressed = false
    @Published var zlPressed = false
    @Published var zrPressed = false
    @Published var l3Pressed = false
    @Published var r3Pressed = false
    @Published var leftStick = CGPoint.zero
    @Published var rightStick = CGPoint.zero
    @Published var dpad = CGPoint.zero

    private static let owners = NSMapTable<GCExtendedGamepad, LiveBoardControllerInput>.weakToWeakObjects()
    private var active = false
    private var observers: [NSObjectProtocol] = []
    private var profiles: [(GCExtendedGamepad, GCExtendedGamepadValueChangedHandler?)] = []
    private var controllerProfileNames: [ObjectIdentifier: String] = [:]
    private var repeatTask: Task<Void, Never>?
    private var heldDirection: Command?

    func start() {
        guard !active else {
            for controller in GCController.controllers() { attach(controller) }
            return
        }
        active = true
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor [weak self] in self?.attach(controller) }
            },
            center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor [weak self] in self?.detach(controller) }
            }
        ]
        // Observe before enumeration so a controller arriving during startup cannot be missed.
        for controller in GCController.controllers() { attach(controller) }
        connected = !profiles.isEmpty
    }
    func stop() {
        onCommand = nil
        guard active else { return }
        active = false
        repeatTask?.cancel(); repeatTask = nil; heldDirection = nil
        for (profile, previous) in profiles where Self.owners.object(forKey: profile) === self {
            profile.valueChangedHandler = previous
            Self.owners.removeObject(forKey: profile)
        }
        profiles.removeAll()
        controllerProfileNames.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll(); connected = false
    }
    // Internal for tests with GameController's supported synthetic extended-gamepad profile.
    func attach(_ controller: GCController) {
        guard active, let profile = controller.extendedGamepad,
              !profiles.contains(where: { $0.0 === profile }) else { return }
        // SwiftUI can mount the new mode before unmounting the old one. Transfer
        // ownership first so the old view cannot restore over the new handler.
        if let previousOwner = Self.owners.object(forKey: profile), previousOwner !== self {
            previousOwner.detach(controller)
        }
        Self.owners.setObject(self, forKey: profile)
        profiles.append((profile, profile.valueChangedHandler))
        controllerProfileNames[ObjectIdentifier(profile)] = LiveBoardControllerMapping.profileName(for: controller)
        profile.valueChangedHandler = { [weak self] gamepad, element in
            Task { @MainActor [weak self] in self?.handle(gamepad, element: element) }
        }
        let defaults = LCUtils.appGroupUserDefault
        confirmSymbol = defaults.bool(forKey: "ZNBetaSwapAB") ? (profile.buttonB.sfSymbolsName ?? "b.circle") : (profile.buttonA.sfSymbolsName ?? "a.circle")
        detailsSymbol = defaults.bool(forKey: "ZNBetaSwapXY") ? (profile.buttonY.sfSymbolsName ?? "y.circle") : (profile.buttonX.sfSymbolsName ?? "x.circle")
        connected = true
    }
    private func detach(_ controller: GCController) {
        guard let profile = controller.extendedGamepad else { return }
        if let index = profiles.firstIndex(where: { $0.0 === profile }) {
            let previous = profiles.remove(at: index)
            if Self.owners.object(forKey: profile) === self {
                profile.valueChangedHandler = previous.1
                Self.owners.removeObject(forKey: profile)
            }
            controllerProfileNames.removeValue(forKey: ObjectIdentifier(profile))
        }
        repeatTask?.cancel(); heldDirection = nil
        connected = !profiles.isEmpty
    }
    private func handle(_ profile: GCExtendedGamepad, element: GCControllerElement) {
        guard active else { return }

        let defaults = LCUtils.appGroupUserDefault
        let swapAB = defaults.bool(forKey: "ZNBetaSwapAB")
        let swapXY = defaults.bool(forKey: "ZNBetaSwapXY")
        if !defaults.bool(forKey: "ZNBetaLowMemory") {
        // Update visual states for skin
        leftStick = CGPoint(x: CGFloat(profile.leftThumbstick.xAxis.value), y: CGFloat(profile.leftThumbstick.yAxis.value))
        rightStick = CGPoint(x: CGFloat(profile.rightThumbstick.xAxis.value), y: CGFloat(profile.rightThumbstick.yAxis.value))
        dpad = CGPoint(x: CGFloat(profile.dpad.xAxis.value), y: CGFloat(profile.dpad.yAxis.value))

        aPressed = profile.buttonA.isPressed
        bPressed = profile.buttonB.isPressed
        xPressed = profile.buttonX.isPressed
        yPressed = profile.buttonY.isPressed
        lPressed = profile.leftShoulder.isPressed
        rPressed = profile.rightShoulder.isPressed
        zlPressed = profile.leftTrigger.value > 0.15
        zrPressed = profile.rightTrigger.value > 0.15
        l3Pressed = profile.leftThumbstickButton?.isPressed ?? false
        r3Pressed = profile.rightThumbstickButton?.isPressed ?? false

        }
        if element === profile.dpad || element === profile.leftThumbstick {
            let pad = element === profile.dpad ? profile.dpad : profile.leftThumbstick
            updateDirection(x: pad.xAxis.value, y: pad.yAxis.value)
        } else if element === profile.buttonA, profile.buttonA.isPressed { dispatch("A", fallback: swapAB ? .back : .confirm, for: profile) }
        else if element === profile.buttonB, profile.buttonB.isPressed { dispatch("B", fallback: swapAB ? .confirm : .back, for: profile) }
        else if element === profile.buttonX, profile.buttonX.isPressed { dispatch("X", fallback: swapXY ? .favorite : .details, for: profile) }
        else if element === profile.buttonY, profile.buttonY.isPressed { dispatch("Y", fallback: swapXY ? .details : .favorite, for: profile) }
        else if element === profile.leftShoulder, profile.leftShoulder.isPressed { dispatch("L", fallback: .previousSection, for: profile) }
        else if element === profile.rightShoulder, profile.rightShoulder.isPressed { dispatch("R", fallback: .nextSection, for: profile) }
        else if element === profile.buttonMenu, profile.buttonMenu.isPressed { dispatch("Menu", fallback: .details, for: profile) }
    }
    private func dispatch(_ button: String, fallback: Command, for profile: GCExtendedGamepad) {
        let name = controllerProfileNames[ObjectIdentifier(profile)] ?? "Default"
        guard let action = LiveBoardControllerMapping.command(button, profile: name) else { onCommand?(fallback); return }
        switch action {
        case "confirm": onCommand?(.confirm)
        case "back": onCommand?(.back)
        case "details": onCommand?(.details)
        case "favorite": onCommand?(.favorite)
        case "previousSection": onCommand?(.previousSection)
        case "nextSection": onCommand?(.nextSection)
        default: onCommand?(fallback)
        }
    }
    private func updateDirection(x: Float, y: Float) {
        let direction: Command?
        if max(abs(x), abs(y)) < 0.55 { direction = nil }
        else if abs(x) >= abs(y) { direction = x > 0 ? .right : .left }
        else { direction = y > 0 ? .up : .down }
        guard heldDirection != direction else { return }
        repeatTask?.cancel(); heldDirection = direction
        guard let direction else { return }
        onCommand?(direction)
        repeatTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            while !Task.isCancelled {
                guard let self, self.active else { return }
                self.onCommand?(direction)
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
    }
}

struct LiveBoardConsoleNavigation: Equatable {
    enum Focus: Equatable { case header, rail, launch, details }
    var selectedIndex = 0
    var headerIndex = 0
    var focus: Focus = .rail
    mutating func move(_ command: LiveBoardControllerInput.Command, count: Int) {
        switch command {
        case .left:
            if focus == .header { headerIndex = max(0, headerIndex - 1) }
            else if focus == .details { focus = .launch }
            else if focus == .rail { selectedIndex = max(0, selectedIndex - 1) }
        case .right:
            if focus == .header { headerIndex = min(3, headerIndex + 1) }
            else if focus == .launch { focus = .details }
            else if focus == .rail { selectedIndex = min(max(0, count - 1), selectedIndex + 1) }
        case .up: focus = focus == .rail ? .header : .rail
        case .down: focus = focus == .header ? .rail : .launch
        case .back: focus = .rail
        default: break
        }
    }
}
