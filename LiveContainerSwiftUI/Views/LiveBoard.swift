import SwiftUI

// The existing list stays mounted to retain install, deep-link and JIT delegates.
struct LiveBoardRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "switchboard"
    @AppStorage("StrataSwitchboardAMOLEDDark", store: LCUtils.appGroupUserDefault) private var switchboardDark = false
    @State private var settingsPresented = false
    @State private var settingsInitialDestination: String? = nil
    @State private var destinationPresented = false

    var body: some View {
        LCAppListView(openInterface: { presentSettings(destination: nil) })
        .onAppear { if mode != "switchboard" { mode = "switchboard" }; StrataMemoryOverlay.shared.apply() }
        .preferredColorScheme(switchboardDark ? .dark : .light)
        .sheet(isPresented: $destinationPresented, onDismiss: { sharedModel.selectedTab = .apps; NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil) }) {
            VStack(spacing: 0) {
                HStack { Spacer(); Button("Done") { destinationPresented = false }.padding() }
                switch sharedModel.selectedTab {
                case .sources: LCSourcesView()
                case .tweaks: LCTweaksView()
                case .settings: LCSettingsView()
                case .apps: EmptyView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .strataOpenSettings)) { _ in
            presentSettings(destination: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .strataOpenNxNativeSkinSettings)) { _ in
            presentSettings(destination: "portraitskin")
        }
        .fullScreenCover(isPresented: $settingsPresented, onDismiss: { NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil) }) {
            StrataSettingsApp(close: { settingsPresented = false },
                              initialDestination: settingsInitialDestination)
                .environmentObject(sharedModel)
        }
        .onChange(of: sharedModel.selectedTab) { tab in
            if tab != .apps { NotificationCenter.default.post(name: LiveBoardControllerInput.pauseNotification, object: nil) }
            if tab == .apps {
                destinationPresented = false
            } else {
                destinationPresented = true
            }
        }
    }

    private func presentSettings(destination: String?) {
        settingsInitialDestination = destination
        NotificationCenter.default.post(name: LiveBoardControllerInput.pauseNotification, object: nil)
        settingsPresented = true
    }
}
