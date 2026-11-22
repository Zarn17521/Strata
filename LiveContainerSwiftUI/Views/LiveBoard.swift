import SwiftUI

private enum LiveBoardMode: String, CaseIterable, Identifiable {
    case switchboard
    var id: String { rawValue }
    var title: String { "Switchboard" }
    var symbol: String { "rectangle.split.3x1.fill" }
    var detail: String { "Square game covers in a horizontal row." }
}

// The existing list stays mounted to retain install, deep-link and JIT delegates.
struct LiveBoardRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "switchboard"
    @State private var interfacePresented = false
    @State private var settingsPresented = false
    @AppStorage("StrataResumeAfterSystemClose", store: LCUtils.appGroupUserDefault) private var resumeAfterSystemClose = false
    @AppStorage("StrataKeepGuestAlive", store: LCUtils.appGroupUserDefault) private var keepGuestAlive = false
    @State private var destinationPresented = false

    var body: some View {
        LCAppListView(openInterface: { interfacePresented = true })
        .onAppear { if mode != "switchboard" { mode = "switchboard" }; StrataMemoryOverlay.shared.apply() }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $interfacePresented, onDismiss: { NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil) }) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        Button { interfacePresented = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { settingsPresented = true } } label: {
                            Label("Settings", systemImage: "gearshape.fill").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain).accessibilityIdentifier("interface.settings")
                        ForEach(LiveBoardMode.allCases) { option in
                            Button { mode = option.rawValue } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: option.symbol).font(.title).frame(width: 48)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(option.title).font(.headline)
                                        Text(option.detail).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: mode == option.rawValue ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(.blue)
                                }.padding(20)
                                    .background(Color.white.opacity(mode == option.rawValue ? 0.12 : 0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(mode == option.rawValue ? .isSelected : [])
                        }
                        Toggle("Reopen the running app if iOS closes Strata in the background", isOn: $resumeAfterSystemClose).padding(.horizontal, 20).padding(.vertical, 8)
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Keep the running app alive in the background", isOn: $keepGuestAlive)
                            Text("Lets you switch to another app and come back without losing progress. Uses more battery; iOS may still close very large games when memory runs out.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.horizontal, 20).padding(.vertical, 8)
                        NavigationLink { StrataPhoneAppsView() } label: { Label("iPhone Apps", systemImage: "iphone.and.arrow.forward").padding() }
                        StrataCreditsButton(location: "interface.about").padding(18).liveBoardGlass(radius: 20)
                    }.padding()
                }
                .navigationTitle("Interface")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { interfacePresented = false } } }
            }.navigationViewStyle(.stack)
        }
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
            NotificationCenter.default.post(name: LiveBoardControllerInput.pauseNotification, object: nil)
            if interfacePresented { interfacePresented = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { settingsPresented = true } } else { settingsPresented = true }
        }
        .fullScreenCover(isPresented: $settingsPresented, onDismiss: { NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil) }) {
            StrataSettingsApp(openInterface: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { interfacePresented = true } }, close: { settingsPresented = false })
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

}
