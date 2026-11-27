import SwiftUI

enum LiveBoardShortcutAction: String, Codable, CaseIterable, Identifiable {
    case normal, jit, gameMode, gameModeJIT, metalHUD, multitask
    static var selectableActions: [Self] { allCases.filter { $0 != .metalHUD } }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .normal: return "Normal Launch"
        case .jit: return "Launch with JIT"
        case .gameMode: return "Launch with Game Mode"
        case .gameModeJIT: return "Game Mode + JIT"
        case .metalHUD: return "Launch with Metal HUD"
        case .multitask: return "Multitask Launch"
        }
    }
    var symbol: String {
        switch self {
        case .normal: return "play.fill"
        case .jit: return "bolt.fill"
        case .gameMode: return "gamecontroller.fill"
        case .gameModeJIT: return "bolt.circle.fill"
        case .metalHUD: return "gauge.with.dots.needle.67percent"
        case .multitask: return "rectangle.on.rectangle"
        }
    }
}

struct LiveBoardShortcutProfile: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var action: LiveBoardShortcutAction
}

enum LiveBoardShortcutProfiles {
    private static let profilesKey = "StrataPerGameShortcutProfiles"
    private static let defaultsKey = "StrataPerGameDefaultShortcutProfiles"
    private static var defaults: UserDefaults { LCUtils.appGroupUserDefault }
    private static func all() -> [String: [LiveBoardShortcutProfile]] {
        guard let data = defaults.data(forKey: profilesKey),
              let result = try? JSONDecoder().decode([String: [LiveBoardShortcutProfile]].self, from: data) else { return [:] }
        return result
    }
    static func profiles(for app: LCAppModel) -> [LiveBoardShortcutProfile] {
        // Keep old Codable values readable without launching Apple HUD.
        (all()[liveBoardAppKey(app)] ?? []).map { profile in
            var copy = profile
            if copy.action == .metalHUD { copy.action = .normal }
            return copy
        }
    }
    static func defaultID(for app: LCAppModel) -> String? { (defaults.dictionary(forKey: defaultsKey) as? [String: String])?[liveBoardAppKey(app)] }
    static func defaultProfile(for app: LCAppModel) -> LiveBoardShortcutProfile? {
        let profiles = profiles(for: app)
        return profiles.first { $0.id == defaultID(for: app) } ?? profiles.first
    }
    static func save(_ profiles: [LiveBoardShortcutProfile], for app: LCAppModel, defaultID: String?) {
        let key = liveBoardAppKey(app)
        var values = all(); values[key] = profiles
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: profilesKey) }
        var selected = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        selected[key] = profiles.contains(where: { $0.id == defaultID }) ? defaultID : profiles.first?.id
        defaults.set(selected, forKey: defaultsKey)
    }
    static func restore(_ app: LCAppModel) {
        let key = liveBoardAppKey(app)
        var values = all(); values.removeValue(forKey: key)
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: profilesKey) }
        var selected = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        selected.removeValue(forKey: key); defaults.set(selected, forKey: defaultsKey)
    }
}

/// Per-game profile editor and quick-launch panel. Launches use the same host
/// callbacks as the library, preserving existing JIT/Game Mode/HUD cleanup.
struct LiveBoardShortcutProfilesSheet: View {
    let app: LCAppModel
    let launch: (LiveBoardShortcutAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    @StateObject private var controller = LiveBoardControllerInput()
    @State private var profiles: [LiveBoardShortcutProfile] = []
    @State private var defaultID: String?
    @State private var name = ""
    @State private var action: LiveBoardShortcutAction = .normal
    @State private var selectedProfileIndex = 0

    var body: some View {
        NavigationView {
            Form {
                Section("Quick launch") {
                    if let profile = profiles.first(where: { $0.id == defaultID }) ?? profiles.first {
                        Button { launch(profile.action); dismiss() } label: { Label("Launch default · \(profile.action.title)", systemImage: profile.action.symbol) }
                    } else {
                        Text("Create a profile to set a default launch action.").foregroundStyle(.secondary)
                    }
                }
                Section("Profiles for \(customization.name(app))") {
                    ForEach(profiles.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    TextField("Profile name", text: profileNameBinding(index))
                                        .font(.headline).onSubmit { persist() }
                                    Picker("Launch action", selection: profileActionBinding(index)) {
                                        ForEach(LiveBoardShortcutAction.selectableActions) { Text($0.title).tag($0) }
                                    }.labelsHidden()
                                }
                                Spacer()
                                if defaultID == profiles[index].id { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel("Default profile") }
                            }
                            HStack {
                                Button("Set Default") { defaultID = profiles[index].id; persist() }.disabled(defaultID == profiles[index].id)
                                Spacer()
                                Button("Duplicate") { duplicate(index) }
                                Button("Delete", role: .destructive) { remove(index) }
                                Button("Launch") { launch(profiles[index].action); dismiss() }
                            }
                        }
                        .padding(.vertical, 3)
                        .background(index == selectedProfileIndex ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Section("Create profile") {
                    TextField("Profile name", text: $name).textInputAutocapitalization(.words)
                    Picker("Launch action", selection: $action) { ForEach(LiveBoardShortcutAction.selectableActions) { Text($0.title).tag($0) } }
                    Button("Add Profile") {
                        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
                        guard !clean.isEmpty, !profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return }
                        let profile = LiveBoardShortcutProfile(name: clean, action: action)
                        profiles.append(profile); if defaultID == nil { defaultID = profile.id }; name = ""; persist()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section {
                    Button("Restore default launch settings", role: .destructive) { profiles = []; defaultID = nil; LiveBoardShortcutProfiles.restore(app) }
                } footer: { Text("Profiles call the library’s existing launch actions. Multitask is available only where the selected launch path supports it.") }
            }
            .navigationTitle("Shortcut Profiles")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            profiles = LiveBoardShortcutProfiles.profiles(for: app)
            defaultID = LiveBoardShortcutProfiles.defaultID(for: app)
            selectedProfileIndex = profiles.firstIndex(where: { $0.id == defaultID }) ?? 0
            bindController()
        }
        .onDisappear { controller.stop() }
    }

    private func persist() { LiveBoardShortcutProfiles.save(profiles, for: app, defaultID: defaultID) }
    private func bindController() {
        controller.onCommand = { command in
            guard !profiles.isEmpty else { if command == .back { dismiss() }; return }
            switch command {
            case .up: selectedProfileIndex = (selectedProfileIndex - 1 + profiles.count) % profiles.count
            case .down: selectedProfileIndex = (selectedProfileIndex + 1) % profiles.count
            case .confirm: launch(profiles[selectedProfileIndex].action); dismiss()
            case .details: defaultID = profiles[selectedProfileIndex].id; persist()
            case .back: dismiss()
            default: break
            }
        }
        controller.start()
    }
    private func profileNameBinding(_ index: Int) -> Binding<String> {
        Binding(get: { profiles.indices.contains(index) ? profiles[index].name : "" }, set: { value in
            guard profiles.indices.contains(index) else { return }
            profiles[index].name = String(value.prefix(48)); persist()
        })
    }
    private func profileActionBinding(_ index: Int) -> Binding<LiveBoardShortcutAction> {
        Binding(get: { profiles.indices.contains(index) ? profiles[index].action : .normal }, set: { value in
            guard profiles.indices.contains(index) else { return }
            profiles[index].action = value; persist()
        })
    }
    private func duplicate(_ index: Int) {
        guard profiles.indices.contains(index) else { return }
        let source = profiles[index]
        let base = String(source.name.prefix(38))
        var ordinal = 1
        var candidate = base + " Copy"
        while profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(candidate) == .orderedSame }) {
            ordinal += 1
            let suffix = " Copy \(ordinal)"
            candidate = String(base.prefix(48 - suffix.count)) + suffix
        }
        let copy = LiveBoardShortcutProfile(name: candidate, action: source.action)
        profiles.insert(copy, at: index + 1); persist()
    }
    private func remove(_ index: Int) {
        guard profiles.indices.contains(index) else { return }
        let removed = profiles.remove(at: index)
        if removed.id == defaultID { defaultID = profiles.first?.id }
        persist()
    }
}

struct LiveBoardRecentGamesSettings: View {
    @State private var count = LiveBoardRecentGames.timestamps().count
    @State private var confirmClear = false
    var body: some View {
        Form {
            Section("Play history") {
                HStack { Text("Recorded games"); Spacer(); Text("\(count)").foregroundStyle(.secondary) }
                Text("ZN records a timestamp only after a game launch succeeds. Session duration is unavailable from the current host handoff interface.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Clear play history", role: .destructive) { confirmClear = true }.disabled(count == 0)
            }
        }
        .navigationTitle("Recently Played")
        .confirmationDialog("Clear all play history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { LiveBoardRecentGames.clear(); count = 0 }
        }
    }
}
