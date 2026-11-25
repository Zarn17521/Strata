import SwiftUI
import GameController

/// Launcher-only mappings. Guest apps keep their native GameController input unchanged.
enum LiveBoardControllerMapping {
    static let storageKey = "LiveBoardControllerProfiles"
    static let actions = ["confirm", "back", "details", "favorite", "previousSection", "nextSection"]
    static func title(_ action: String) -> String {
        switch action {
        case "confirm": return "Confirm"
        case "back": return "Back"
        case "details": return "Options"
        case "favorite": return "Favorite"
        case "previousSection": return "Previous category"
        default: return "Next category"
        }
    }
    static func profileName(for controller: GCController) -> String {
        let name = (controller.vendorName ?? controller.productCategory).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Default" : String(name.prefix(64))
    }
    static func profiles(_ defaults: UserDefaults = LCUtils.appGroupUserDefault) -> [String: [String: String]] {
        defaults.dictionary(forKey: storageKey) as? [String: [String: String]] ?? [:]
    }
    static func command(_ button: String, profile: String, defaults: UserDefaults = LCUtils.appGroupUserDefault) -> String? {
        profiles(defaults)[profile]?[button]
    }
    static func set(_ action: String?, button: String, profile: String, defaults: UserDefaults = LCUtils.appGroupUserDefault) {
        var all = profiles(defaults)
        var map = all[profile] ?? [:]
        map[button] = action
        if map.isEmpty { all.removeValue(forKey: profile) } else { all[profile] = map }
        defaults.set(all, forKey: storageKey)
    }
    static func remove(_ profile: String, defaults: UserDefaults = LCUtils.appGroupUserDefault) {
        var all = profiles(defaults); all.removeValue(forKey: profile); defaults.set(all, forKey: storageKey)
    }
}

struct LiveBoardControllerMappingSettings: View {
    @State private var profile = "Default"
    @State private var revision = 0
    private let buttons = ["A", "B", "X", "Y", "L", "R", "Menu"]
    private var knownProfiles: [String] { ["Default"] + LiveBoardControllerMapping.profiles().keys.filter { $0 != "Default" }.sorted() }
    var body: some View {
        Form {
            Section("Controller profile") {
                Picker("Profile", selection: $profile) { ForEach(knownProfiles, id: \.self) { Text($0).tag($0) } }
                TextField("Controller vendor name", text: Binding(get: { profile == "Default" ? "" : profile }, set: { profile = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Default" : String($0.prefix(64)) }))
                    .textInputAutocapitalization(.words)
                Text("A controller uses the profile matching its GameController vendor name. Create a separate name for each model; use Default as the fallback.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                ForEach(buttons, id: \.self) { button in
                    Picker(button, selection: actionBinding(button)) {
                        Text(defaultTitle(button)).tag("")
                        ForEach(LiveBoardControllerMapping.actions, id: \.self) { Text(LiveBoardControllerMapping.title($0)).tag($0) }
                    }
                }
            } header: {
                Text("Library buttons")
            } footer: {
                Text("These mappings only control Strata library navigation. The running guest keeps its original button layout. Existing A/B and X/Y swap settings remain the fallback when a profile has no custom mapping.")
            }
            Section {
                Button("Restore this profile") { LiveBoardControllerMapping.remove(profile); revision += 1 }
                    .disabled(LiveBoardControllerMapping.profiles()[profile] == nil)
            }
        }
        .navigationTitle("Controller Mapping")
        .onChange(of: profile) { _ in revision += 1 }
        .id(revision)
    }
    private func defaultTitle(_ button: String) -> String {
        let swapAB = LCUtils.appGroupUserDefault.bool(forKey: "ZNBetaSwapAB")
        let swapXY = LCUtils.appGroupUserDefault.bool(forKey: "ZNBetaSwapXY")
        switch button {
        case "A": return swapAB ? "Back (A/B swap)" : "Confirm (A/B swap)"
        case "B": return swapAB ? "Confirm (A/B swap)" : "Back (A/B swap)"
        case "X": return swapXY ? "Favorite (X/Y swap)" : "Options (X/Y swap)"
        case "Y": return swapXY ? "Options (X/Y swap)" : "Favorite (X/Y swap)"
        case "L": return "Previous category"
        case "R": return "Next category"
        default: return "Options"
        }
    }
    private func actionBinding(_ button: String) -> Binding<String> {
        Binding(get: { LiveBoardControllerMapping.command(button, profile: profile) ?? "" }, set: { LiveBoardControllerMapping.set($0.isEmpty ? nil : $0, button: button, profile: profile); revision += 1 })
    }
}
