import SwiftUI
import UniformTypeIdentifiers

/// ZN release version, read from Info.plist. Retain internal build metadata for compatibility.
enum StrataVersion {
    static var marketing: String { Bundle.main.object(forInfoDictionaryKey: "StrataMarketingVersion") as? String ?? "0.1.0" }
    static var revision: Int? { (Bundle.main.object(forInfoDictionaryKey: "StrataRevision") as? NSNumber)?.intValue }
    static var channel: String? { Bundle.main.object(forInfoDictionaryKey: "StrataBuildChannel") as? String }
    static var display: String { marketing }
    static var full: String { "ZN " + display + (channel.map { " · " + $0 } ?? "") }
}

extension Notification.Name {
    /// Any interface posts this to open the Settings app.
    static let strataOpenSettings = Notification.Name("StrataOpenSettings")
    /// Switchboard skin long-press opens the actual NxNative Skin settings page.
    static let strataOpenNxNativeSkinSettings = Notification.Name("StrataOpenNxNativeSkinSettings")
    /// Settings posts this to show the app-management list.
    static let strataOpenAppManagement = Notification.Name("StrataOpenAppManagement")
}

/// One place for Strata settings: search and grouped sections that open
/// the existing settings screens, without an intermediate Interface page.
struct StrataSettingsApp: View {
    let close: () -> Void
    var initialDestination: String? = nil
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var query = ""
    @State private var errorInfo: String?
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @AppStorage("StrataResumeAfterSystemClose", store: LCUtils.appGroupUserDefault) private var resumeAfterSystemClose = false
    @AppStorage("StrataKeepGuestAlive", store: LCUtils.appGroupUserDefault) private var keepGuestAlive = false
    @AppStorage("StrataSeamlessSwitching", store: LCUtils.appGroupUserDefault) private var seamlessSwitching = true
    @AppStorage("ZNBetaLowMemory", store: LCUtils.appGroupUserDefault) private var lowMemory = false
    @AppStorage(StrataMemoryOverlay.key, store: LCUtils.appGroupUserDefault) private var memoryOverlay = false
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var nxSkinEnabled = true

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let tint: Color
        let section: String
        let keywords: String
        let destination: () -> AnyView
    }

    private var allApps: [LCAppModel] { sharedModel.apps + sharedModel.hiddenApps }

    private var entries: [Entry] {
        [
            Entry(id: "jit", title: "JIT", symbol: "bolt.fill", tint: .yellow, section: "Performance", keywords: "jit enabler stikjit debugger script universal localdevvpn pairing") { AnyView(LiveBoardJITSetup()) },
            Entry(id: "memory", title: "Memory & Signing", symbol: "memorychip", tint: .green, section: "Performance", keywords: "ram memory limit bypass entitlement increased capability apple id") { AnyView(StrataMemorySettings()) },
            Entry(id: "framegen", title: "Frame Generation", symbol: "square.3.layers.3d", tint: .purple, section: "Performance", keywords: "fps frame generation metal 120hz") { AnyView(StrataFrameGenSettings(apps: sharedModel.apps)) },
            Entry(id: "storage", title: "Storage", symbol: "internaldrive", tint: .gray, section: "Performance", keywords: "storage space size cache data") { AnyView(LCStorageManagementView()) },
            Entry(id: "switcher", title: "App Switcher", symbol: "rectangle.stack", tint: .indigo, section: "Interface", keywords: "switcher three finger multitask pinned running cards") { AnyView(StrataSwitcherSettings(apps: allApps)) },
            Entry(id: "portraitskin", title: "NxNative Controller Skins", symbol: "photo.on.rectangle", tint: .gray, section: "Interface", keywords: "portrait landscape pearl light amoled dark black graphite glass built-in nxnative controller skin") { AnyView(StrataNxPortraitSkinSettings()) },
            Entry(id: "recentgames", title: "Recently Played", symbol: "clock.arrow.circlepath", tint: .orange, section: "Interface", keywords: "recent played history last launched clear") { AnyView(LiveBoardRecentGamesSettings()) },
            Entry(id: "sounds", title: "Navigation Sounds", symbol: "speaker.wave.2.fill", tint: .pink, section: "Interface", keywords: "classic soft arcade selection confirm back preview sound effects") { AnyView(StrataNavigationSoundSettings()) },
            Entry(id: "realcontroller", title: "ZN Real Controller Engine", symbol: "gamecontroller.fill", tint: .blue, section: "Interface", keywords: "controller haptic mechanical click animation bluetooth touch neon") { AnyView(ZNRealControllerSettings()) },
            Entry(id: "controllermapping", title: "Controller Mapping", symbol: "gamecontroller", tint: .cyan, section: "Interface", keywords: "bluetooth controller profile custom map buttons swap a b x y gamepad library navigation") { AnyView(LiveBoardControllerMappingSettings()) },
            Entry(id: "steamgriddb", title: "SteamGridDB", symbol: "square.stack.3d.up", tint: .indigo, section: "Interface", keywords: "artwork covers backgrounds api key automatic search steam grid") { AnyView(StrataSteamGridDBKeySettings()) },
            Entry(id: "iphone", title: "iPhone Apps", symbol: "iphone", tint: .blue, section: "Apps", keywords: "iphone native ios apps shortcut url add") { AnyView(StrataPhoneAppsView()) },
            Entry(id: "extensions", title: "App Extensions", symbol: "puzzlepiece.extension", tint: .teal, section: "Apps", keywords: "extensions share widgets plugins helper") { AnyView(StrataExtensionsView(apps: sharedModel.apps)) },
            Entry(id: "sources", title: "Sources", symbol: "books.vertical", tint: .orange, section: "Apps", keywords: "sources repositories install altstore") { AnyView(LCSourcesView()) },
            Entry(id: "tweaks", title: "Tweaks", symbol: "wrench.and.screwdriver", tint: .pink, section: "Apps", keywords: "tweaks dylib inject") { AnyView(LCTweaksView()) },
            Entry(id: "runtime", title: "Runtime Manager", symbol: "shippingbox.fill", tint: .brown, section: "System", keywords: "runtime guests files backups restore containers hostjit") { if #available(iOS 16.0, *) { return AnyView(runtimeCenter) } else { return AnyView(Text("Requires iOS 16 or later.")) } },
            Entry(id: "refresh", title: "Refresh", symbol: "arrow.triangle.2.circlepath", tint: .cyan, section: "System", keywords: "refresh sidestore expiry certificate vpn shortcut automation") { AnyView(StrataAutoRefreshSettings()) },
            Entry(id: "identity", title: "Signing Identity", symbol: "signature", tint: .mint, section: "System", keywords: "signing identity certificate localsigner keychain") { if #available(iOS 16.0, *) { return AnyView(StrataIdentitySettings()) } else { return AnyView(Text("Requires iOS 16 or later.")) } },
            Entry(id: "advanced", title: "Advanced (LiveContainer)", symbol: "gearshape.2", tint: .gray, section: "System", keywords: "advanced livecontainer settings multitask jit enabler data management") { AnyView(LCSettingsView()) },
            Entry(id: "about", title: "About ZN", symbol: "info.circle", tint: .blue, section: "About", keywords: "about version credits github") { AnyView(StrataAboutView()) },
        ]
    }

    @available(iOS 16.0, *)
    private var runtimeCenter: some View {
        StrataRuntimeCenter(apps: allApps, launch: { app in Task { do {
            if app.uiIsLocked && !sharedModel.isHiddenAppUnlocked { guard try await LCUtils.authenticateUser() else { return } }
            try await app.runApp()
        } catch { errorInfo = error.localizedDescription } } }, manage: { _ in openManagement() })
    }

    private var matches: [Entry] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return entries }
        return entries.filter { $0.title.localizedCaseInsensitiveContains(text) || $0.keywords.localizedCaseInsensitiveContains(text) || $0.section.localizedCaseInsensitiveContains(text) }
    }

    @State private var path: [String] = []

    var body: some View {
        if #available(iOS 16.0, *) {
            if initialDestination == "portraitskin" {
                // Switchboard Skin long-press lands DIRECTLY on the built-in
                // skin selector. Never briefly show the generic Settings list.
                NavigationStack {
                    StrataNxPortraitSkinSettings()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { close() }
                            }
                        }
                }
            } else {
                // Ordinary Settings opens on its searchable root page.
                NavigationStack(path: $path) {
                    content.navigationDestination(for: String.self) { id in destination(id) }
                }
                .onAppear {
                    if let initialDestination, path.isEmpty { path = [initialDestination] }
                }
            }
        } else if initialDestination == "portraitskin" {
            // iOS 15 fallback: open the requested detail screen directly.
            NavigationView {
                StrataNxPortraitSkinSettings()
                    .navigationTitle("NxNative Controller Skins")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { close() }
                        }
                    }
            }.navigationViewStyle(.stack)
        } else {
            NavigationView { content }.navigationViewStyle(.stack)
        }
    }

    private var content: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    StrataSettingsIcon.image.resizable().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ZN").font(.title2.weight(.semibold))
                        Text(StrataVersion.display + (StrataVersion.channel.map { " · " + $0 } ?? "")).font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.version")
                    }
                }.padding(.vertical, 4)
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search settings", text: $query).autocapitalization(.none).disableAutocorrection(true).submitLabel(.search).accessibilityIdentifier("settings.search") }
            }
            if query.isEmpty { mainSections } else {
                Section("Results") {
                    ForEach(matches) { entry in link(entry.id) }
                    if matches.isEmpty { Text("No settings match “\(query)”.").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { close() }.accessibilityIdentifier("settings.done") } }
        .alert("Launch", isPresented: Binding(get: { errorInfo != nil }, set: { if !$0 { errorInfo = nil } })) { Button("OK") { errorInfo = nil } } message: { Text(errorInfo ?? "") }
    }

    @ViewBuilder private var mainSections: some View {
        Section {
            link("sounds")
            link("controllermapping")
            link("steamgriddb")
            Toggle(isOn: $nxSkinEnabled) { row("NxNative Controller Skin", symbol: "gamecontroller.fill", tint: .cyan) }
                .accessibilityIdentifier("settings.nxnative.skin")
            link("portraitskin")
            link("recentgames")
            link("switcher")
        } header: {
            Text("Interface")
        } footer: {
            Text("NxNative Controller Skin uses the imported portrait/landscape artwork and maps its buttons to NxNative touch controls. Enable or disable here or by tapping the launcher shirt icon. Relaunch the game to apply the change.")
        }
        Section("Apps") {
            actionRow("Manage Apps", symbol: "square.stack.3d.up", tint: .blue, id: "settings.manage") { openManagement() }
            link("iphone"); link("extensions"); link("sources"); link("tweaks")
        }
        Section {
            Toggle(isOn: $seamlessSwitching) { row("Seamless app switching", symbol: "rectangle.stack.fill", tint: .indigo) }
        } header: { Text("Multitasking") } footer: { Text("Each app runs in its own process, full screen. Switching returns to it where you left it instead of restarting it. Turn off for apps that misbehave; HostJIT, Classic Mode and Request Game Mode always run inside Strata.") }
        Section {
            Toggle(isOn: $keepGuestAlive) { row("Keep running app alive", symbol: "moon.zzz.fill", tint: .teal) }
            Toggle(isOn: $resumeAfterSystemClose) { row("Reopen app after iOS closes it", symbol: "arrow.uturn.backward.circle.fill", tint: .green) }
        } header: { Text("Background") } footer: { Text("Keep alive plays silent audio while you're in another app so the game isn't suspended. Uses more battery.") }
        Section {
            link("jit"); link("memory")
            Toggle(isOn: $lowMemory) { row("Low Memory Mode", symbol: "memorychip", tint: .green) }
                .accessibilityIdentifier("settings.lowMemoryMode")
            Toggle(isOn: Binding(get: { memoryOverlay }, set: { memoryOverlay = $0; StrataMemoryOverlay.shared.apply() })) { row("Memory overlay", symbol: "gauge.with.needle", tint: .green) }
            link("framegen"); link("storage")
        } header: { Text("Performance") } footer: { Text("Low Memory Mode reduces artwork memory. Relaunch NxNative to apply the skin change. The overlay shows memory usage, limits and peaks for each process.") }
        Section("System") { link("runtime"); link("refresh"); link("identity"); link("advanced") }
        Section("About") {
            link("about")
            valueRow("Version", StrataVersion.full)
            valueRow("Runtime", "LiveContainer nightly 9d6ea09")
        }
    }

    @ViewBuilder private func destination(_ id: String) -> some View {
        if let entry = entries.first(where: { $0.id == id }) { entry.destination().navigationTitle(entry.title) }
    }
    private func open(_ id: String) { path.append(id) }

    private func openManagement() {
        close()
        NotificationCenter.default.post(name: .strataOpenAppManagement, object: nil)
    }
    @ViewBuilder private func link(_ id: String) -> some View {
        if let entry = entries.first(where: { $0.id == id }) {
            if #available(iOS 16.0, *) {
                actionRow(entry.title, symbol: entry.symbol, tint: entry.tint, id: "settings.row." + id, chevron: true) { open(id) }
            } else {
                NavigationLink { entry.destination().navigationTitle(entry.title) } label: { row(entry.title, symbol: entry.symbol, tint: entry.tint) }
                    .accessibilityIdentifier("settings.row." + id)
            }
        }
    }
    /// A full-width row that looks like a settings cell (no blue link text).
    private func actionRow(_ title: String, symbol: String, tint: Color, id: String, chevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                row(title, symbol: symbol, tint: tint)
                Spacer(minLength: 8)
                if chevron { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(minLength: 12); Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
    }
    private func row(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 29, height: 29).background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title).foregroundStyle(.primary)
        }
    }
}

/// Three short system-sound cues. Samples are generated on demand and released after preview.
private struct StrataNavigationSoundSettings: View {
    @AppStorage("ZNBetaSoundStyle", store: LCUtils.appGroupUserDefault) private var style = "classic"
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var enabled = true
    @StateObject private var audio = LiveBoardNavigationAudio()
    var body: some View {
        Form {
            Section("Style") {
                Picker("Sound style", selection: $style) {
                    Text("Classic").tag("classic")
                    Text("Soft").tag("soft")
                    Text("Arcade").tag("arcade")
                }.pickerStyle(.segmented)
                Button { audio.play(.selection, preview: true) } label: { Label("Preview style", systemImage: "play.circle") }
            }
            Section("Preview cues") {
                Button { audio.play(.selection, preview: true) } label: { Label("Selection", systemImage: "arrow.up.arrow.down") }
                Button { audio.play(.confirm, preview: true) } label: { Label("Confirmation", systemImage: "checkmark.circle") }
                Button { audio.play(.back, preview: true) } label: { Label("Back", systemImage: "arrow.uturn.backward.circle") }
            }
            Section { Toggle("Navigation sounds", isOn: $enabled) }
            Section { Text("Sound effects are generated only when previewed or used. Navigation sounds remain available in Low Memory Mode when sufficient memory is available. Serious or critical thermal pressure suppresses playback; audio objects are released when this screen closes or a game launches.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Navigation Sounds")
        .onChange(of: style) { _ in audio.stop() }
        .onDisappear { audio.stop() }
    }
}

/// Gear icon shared by the Settings header and the built-in Settings app tile.
enum StrataSettingsIcon {
    static let uiImage: UIImage = {
        let size = CGSize(width: 180, height: 180)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor(white: 0.58, alpha: 1).cgColor, UIColor(white: 0.36, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let config = UIImage.SymbolConfiguration(pointSize: 112, weight: .regular)
            if let gear = UIImage(systemName: "gearshape.fill", withConfiguration: config)?.withTintColor(UIColor(white: 0.93, alpha: 1), renderingMode: .alwaysOriginal) {
                gear.draw(in: CGRect(x: (size.width - gear.size.width) / 2, y: (size.height - gear.size.height) / 2, width: gear.size.width, height: gear.size.height))
            }
        }
    }()
    static var image: Image { Image(uiImage: uiImage) }
}

/// Settings as an app in every interface. It reuses the iPhone-app entry type, which already skips
/// guest-only launch options (JIT, Game Mode, Multitask); launching it opens the Settings app.
final class StrataSettingsAppInfo: StrataPhoneAppInfo {
    override func iconIsDarkIcon(_ isDarkIcon: Bool) -> UIImage! { StrataSettingsIcon.uiImage }
}

@MainActor enum StrataBuiltInSettings {
    static let entryID = UUID(uuidString: "5E771465-5E77-4465-8000-5E7714655E77")!
    static let model: LCAppModel? = {
        let folder = LCPath.docPath.appendingPathComponent("Strata3/LauncherEntries/settings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let info: [String: Any] = ["CFBundleIdentifier": "com.strata.builtin.settings", "CFBundleDisplayName": "Settings", "CFBundleName": "Settings", "CFBundleShortVersionString": StrataVersion.marketing, "CFBundleExecutable": "Settings"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0).write(to: folder.appendingPathComponent("Info.plist"), options: .atomic)
            let entry = StrataPhoneAppEntry(id: entryID, name: "Settings", target: "", shortcut: false)
            return LCAppModel(appInfo: StrataSettingsAppInfo(entry: entry, path: folder.path))
        } catch { return nil }
    }()
}

 
// Built-in skin variants are available without importing a portrait or landscape PNG.
struct StrataNxPortraitSkinSettings: View {
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault)
    private var enabled = true
    @AppStorage("StrataNxSkinStyle", store: LCUtils.appGroupUserDefault)
    private var style = "pearl"
    @AppStorage("ZNCustomSkinThemeID", store: LCUtils.appGroupUserDefault)
    private var themeID = ""
    @AppStorage("StrataNxDisplayLayout", store: LCUtils.appGroupUserDefault)
    private var displayLayout = "wide"

    private var dark: Bool { style == "amoled" }
    private let originalSkins = [
        StrataNxBuiltInSkin(id: "pearl", title: "Pearl Light"),
        StrataNxBuiltInSkin(id: "amoled", title: "AMOLED Dark")
    ]

    private var availableSkins: [StrataNxBuiltInSkin] { originalSkins + StrataNxBuiltInSkin.all }
    private var activeTheme: StrataNxBuiltInSkin {
        availableSkins.first { $0.id == themeID } ?? originalSkins[dark ? 1 : 0]
    }
    private var finishSelection: Binding<String> {
        Binding(get: { activeTheme.id }, set: { finish in
            themeID = finish
            style = finish
        })
    }
    private let themeGridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Form {
            Section {
                Toggle("Enable NxNative Skin", isOn: $enabled)
                    .accessibilityIdentifier("settings.nxnative.skinEnabled")
            } footer: {
                Text(StrataNxPhotoSkinsBundled()
                     ? "Exact photo-based Pearl Light and AMOLED Dark skins are packaged in this build. Restart NxNative to apply."
                     : "Photo assets are not yet embedded in this build. The previous vector fallback is temporary until all four skin images are added to the repository and rebuilt.")
            }

            Section {
                NavigationLink(destination: ZNRealControllerSettings()) {
                    Label("ZN Real Controller Engine", systemImage: "gamecontroller.fill")
                        .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("settings.nxnative.realControllerEngine")
            } footer: {
                Text("Customize button animation, haptic feedback, mechanical click sounds and physical controller auto-hide.")
            }

            Section {
                skinChoices([("Classic", "classic"), ("Wide", "wide"), ("Full Screen", "full")], selection: $displayLayout)
                .accessibilityIdentifier("settings.nxnative.displayLayout")
            } header: {
                Text("Game Display")
            } footer: {
                Text("Classic and Wide show the selected controller skin with mapped touch controls. Full Screen keeps the largest uncropped 16:9 game view and native touch mapping; the bezel is hidden, while the selected theme colors the press feedback. Restart NxNative to apply. Render scale is unchanged.")
            }

            Section("Portrait & Landscape") {
                Group {
                if displayLayout == "full" {
                    Label("Full Screen keeps NxNative's native control positions and touch mapping. The selected theme still colors press feedback; shell artwork stays hidden so it cannot cover the game.", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: false, layout: displayLayout, theme: activeTheme)
                            .frame(width: 96, height: 208)
                        Text("Portrait")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: true, layout: displayLayout, theme: activeTheme)
                            .frame(maxWidth: 232)
                            .aspectRatio(displayLayout == "wide" ? 852.0/393.0 : 1792.0/1008.0, contentMode: .fit)
                        Text("Landscape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                }
                }
                .frame(height: 240)
            }

            Section {
                skinChoices([("Pearl Light", "pearl"), ("AMOLED Dark", "amoled")], selection: finishSelection)
                .accessibilityIdentifier("settings.nxnative.builtinStyle")

                HStack {
                    Text("\(availableSkins.count) built-in skins")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Selected: \(activeTheme.title)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: themeGridColumns, spacing: 10) {
                    ForEach(availableSkins) { item in
                        builtInThemeCard(item)
                    }
                }

                Label("Touch mapping and press effects are shared by all built-in skins. Full Screen keeps native touch mapping and themed press feedback.",
                      systemImage: "gamecontroller.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Built-in Skin")
            } footer: {
                Text("Choose a picture to apply its theme. Choose Pearl Light or AMOLED Dark to use the original skins. Restart NxNative to apply.")
            }
        }
        .navigationTitle("NxNative Controller Skins")
        .onAppear {
            if LCUtils.appGroupUserDefault.string(forKey: "ZNCustomSkinThemeID") == nil {
                themeID = style
            }
        }
    }

    private func skinChoices(_ options: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let (label, value) = options[index]
                let selected = selection.wrappedValue == value
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .background(selected ? Color.accentColor.opacity(0.22) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func builtInThemeCard(_ theme: StrataNxBuiltInSkin) -> some View {
        let original = originalSkins.contains { $0.id == theme.id }
        let cardDark = original ? theme.id == "amoled" : dark
        let selected = activeTheme.id == theme.id
        Button {
            if original { style = theme.id }
            themeID = theme.id
            enabled = true
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 5) {
                        StrataNxBuiltInSkinPreview(dark: cardDark, landscape: false, layout: "classic",
                                                  theme: theme)
                            .aspectRatio(923.0 / 2000.0, contentMode: .fit)
                        StrataNxBuiltInSkinPreview(dark: cardDark, landscape: true, layout: "classic", theme: theme)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    }
                    .padding(5)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .padding(7)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

                Text(theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.accentColor : Color.gray.opacity(0.20), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.nxnative.theme." + theme.id)
    }
}

private struct StrataNxBuiltInSkinPreview: View {
    let dark: Bool
    let landscape: Bool
    let layout: String
    let theme: StrataNxBuiltInSkin

    var body: some View {
        Group {
            if let image = StrataNxSkinPreviewImageForTheme(!landscape, dark, layout, theme.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dark ? Color.black : Color(white: 0.96))
                    .overlay(Text("Skin image unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.title), \(landscape ? "Landscape" : "Portrait") controller skin preview")
    }
}


// Guest settings are read once when the NxNative skin is installed.
struct ZNRealControllerSettings: View {
    @AppStorage("ZNRealAnimate", store: LCUtils.appGroupUserDefault) private var animate = true
    @AppStorage("ZNRealHaptic", store: LCUtils.appGroupUserDefault) private var haptic = false
    @AppStorage("ZNRealSound", store: LCUtils.appGroupUserDefault) private var sound = false
    @AppStorage("ZNRealReleaseSound", store: LCUtils.appGroupUserDefault) private var releaseSound = false
    @AppStorage("ZNRealAutoHide", store: LCUtils.appGroupUserDefault) private var autoHide = true
    @AppStorage("ZNRealIntensity", store: LCUtils.appGroupUserDefault) private var intensity = 0.65
    @AppStorage("ZNRealVolume", store: LCUtils.appGroupUserDefault) private var volume = 0.25
    var body: some View {
        Form {
            Section {
                Toggle("Button Animation", isOn: $animate)
                Toggle("Haptic Feedback", isOn: $haptic)
                HStack { Text("Haptic Intensity"); Spacer(); Text("\(Int(intensity * 100))%").monospacedDigit() }
                Slider(value: $intensity, in: 0...1).disabled(!haptic)
            } header: { Text("Touch feedback") } footer: {
                Text("Native game input is sent first. Turn off the game's own haptics if you notice duplicate feedback.")
            }
            Section {
                Toggle("Mechanical Sound", isOn: $sound)
                Toggle("Release click", isOn: $releaseSound).disabled(!sound)
                HStack { Text("Sound Volume"); Spacer(); Text("\(Int(volume * 100))%").monospacedDigit() }
                Slider(value: $volume, in: 0...1).disabled(!sound)
            } header: { Text("Sound") } footer: {
                Text("Original short synthesized clicks; the game audio session is not explicitly reconfigured.")
            }
            Section {
                Toggle("Bluetooth Auto-Hide", isOn: $autoHide)
            } header: { Text("Physical controller") } footer: {
                Text("Enabled by default. When a supported physical gamepad connects, Classic and Wide use a simplified button-free shell with the Settings gear; Full Screen hides the native touch controls. Touch controls return after the last controller disconnects. Relaunch NxNative to apply changed settings.")
            }
        }.navigationTitle("ZN Real Controller Engine")
    }
}
