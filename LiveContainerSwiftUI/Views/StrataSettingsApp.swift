import SwiftUI
import UniformTypeIdentifiers

/// Marketing version plus build revision, e.g. "4.0 (r43)", read from the packaged Info.plist.
enum StrataVersion {
    static var marketing: String { Bundle.main.object(forInfoDictionaryKey: "StrataMarketingVersion") as? String ?? "4.0" }
    static var revision: Int? { (Bundle.main.object(forInfoDictionaryKey: "StrataRevision") as? NSNumber)?.intValue }
    static var channel: String? { Bundle.main.object(forInfoDictionaryKey: "StrataBuildChannel") as? String }
    static var display: String { marketing + (revision.map { " (r\($0))" } ?? "") }
    static var full: String { "Strata " + display + (channel.map { " · " + $0 } ?? "") }
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
    @AppStorage(LiveBoardSharedCategories.enabledKey, store: LCUtils.appGroupUserDefault) private var universalCategories = true
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @AppStorage("StrataResumeAfterSystemClose", store: LCUtils.appGroupUserDefault) private var resumeAfterSystemClose = false
    @AppStorage("StrataKeepGuestAlive", store: LCUtils.appGroupUserDefault) private var keepGuestAlive = false
    @AppStorage("StrataSeamlessSwitching", store: LCUtils.appGroupUserDefault) private var seamlessSwitching = true
    @AppStorage(StrataMemoryOverlay.key, store: LCUtils.appGroupUserDefault) private var memoryOverlay = false
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var nxSkinEnabled = false

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
            Entry(id: "portraitskin", title: "NxNative Controller Skins", symbol: "photo.on.rectangle", tint: .gray, section: "Interface", keywords: "portrait landscape white shell controller skin jpg png import nxnative touch feedback") { AnyView(StrataNxPortraitSkinSettings()) },
            Entry(id: "iphone", title: "iPhone Apps", symbol: "iphone", tint: .blue, section: "Apps", keywords: "iphone native ios apps shortcut url add") { AnyView(StrataPhoneAppsView()) },
            Entry(id: "extensions", title: "App Extensions", symbol: "puzzlepiece.extension", tint: .teal, section: "Apps", keywords: "extensions share widgets plugins helper") { AnyView(StrataExtensionsView(apps: sharedModel.apps)) },
            Entry(id: "sources", title: "Sources", symbol: "books.vertical", tint: .orange, section: "Apps", keywords: "sources repositories install altstore") { AnyView(LCSourcesView()) },
            Entry(id: "tweaks", title: "Tweaks", symbol: "wrench.and.screwdriver", tint: .pink, section: "Apps", keywords: "tweaks dylib inject") { AnyView(LCTweaksView()) },
            Entry(id: "runtime", title: "Runtime Manager", symbol: "shippingbox.fill", tint: .brown, section: "System", keywords: "runtime guests files backups restore containers hostjit") { if #available(iOS 16.0, *) { return AnyView(runtimeCenter) } else { return AnyView(Text("Requires iOS 16 or later.")) } },
            Entry(id: "refresh", title: "Refresh", symbol: "arrow.triangle.2.circlepath", tint: .cyan, section: "System", keywords: "refresh sidestore expiry certificate vpn shortcut automation") { AnyView(StrataAutoRefreshSettings()) },
            Entry(id: "identity", title: "Signing Identity", symbol: "signature", tint: .mint, section: "System", keywords: "signing identity certificate localsigner keychain") { if #available(iOS 16.0, *) { return AnyView(StrataIdentitySettings()) } else { return AnyView(Text("Requires iOS 16 or later.")) } },
            Entry(id: "advanced", title: "Advanced (LiveContainer)", symbol: "gearshape.2", tint: .gray, section: "System", keywords: "advanced livecontainer settings multitask jit enabler data management") { AnyView(LCSettingsView()) },
            Entry(id: "about", title: "About Strata", symbol: "info.circle", tint: .blue, section: "About", keywords: "about version credits github") { AnyView(StrataAboutView()) },
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
            // Value-based navigation: every row pushes its own destination reliably
            // (NavigationView links in a long List could highlight without opening).
            NavigationStack(path: $path) {
                content.navigationDestination(for: String.self) { id in destination(id) }
            }
            .onAppear {
                if let initialDestination, path.isEmpty { path = [initialDestination] }
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
                        Text("Strata").font(.title2.weight(.semibold))
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
            Toggle(isOn: Binding(get: { universalCategories }, set: { LiveBoardSharedCategories.setEnabled($0); universalCategories = $0 })) { row("Same categories everywhere", symbol: "tag.fill", tint: .orange) }
            Toggle(isOn: $sounds) { row("Navigation sounds", symbol: "speaker.wave.2.fill", tint: .pink) }
            Toggle(isOn: $nxSkinEnabled) { row("NxNative Controller Skin", symbol: "gamecontroller.fill", tint: .cyan) }
                .accessibilityIdentifier("settings.nxnative.skin")
            link("portraitskin")
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
            Toggle(isOn: Binding(get: { memoryOverlay }, set: { memoryOverlay = $0; StrataMemoryOverlay.shared.apply() })) { row("Memory overlay", symbol: "gauge.with.needle", tint: .green) }
            link("framegen"); link("storage")
        } header: { Text("Performance") } footer: { Text("The overlay shows memory used and the limit for Strata, each app and each helper (RAM donor) process, with peaks.") }
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

 
/// Imports a transparent portrait controller frame for Strata's own cosmetic
/// NxNative overlay. No game IPA modification, JIT change or input remapping.
private struct StrataNxPortraitSkinSettings: View {
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var enabled = false
    @State private var picking = false
    @State private var pickingLandscape = false
    @State private var imported: UIImage?
    @State private var importedLandscape: UIImage?
    @State private var notice: String?

    private var assetURL: URL? {
        LCSharedUtils.appGroupPath()?
            .appendingPathComponent("Strata3/Skins/NxNativePortrait.png")
    }
    private var landscapeAssetURL: URL? {
        LCSharedUtils.appGroupPath()?
            .appendingPathComponent("Strata3/Skins/NxNativeLandscape.png")
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable NxNative Skin", isOn: $enabled)
            } footer: {
                Text("Experimental: Skin button touches are mapped to NxNative’s existing input targets. Pressed-button and analog feedback are drawn on the artwork. Restart the game after any change; turn Skin OFF if a game has touch issues.")
            }
            Section {
                if let imported {
                    Image(uiImage: imported)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 350)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Label("Default white handheld frame", systemImage: "gamecontroller")
                        .foregroundStyle(.secondary)
                }
                Button("Import White Portrait PNG", systemImage: "photo.badge.plus") {
                    picking = true
                }
                .accessibilityIdentifier("settings.nxnative.portraitImport")
                if imported != nil {
                    Button("Restore Default White Skin", systemImage: "arrow.uturn.backward") {
                        guard let assetURL else { notice = "App Group unavailable"; return }
                        do {
                            try FileManager.default.removeItem(at: assetURL)
                            imported = nil
                        } catch { notice = error.localizedDescription }
                    }
                }
            } header: {
                Text("Portrait Artwork")
            } footer: {
                Text("Import a portrait PNG with a transparent display opening. Strata aspect-fits the live game inside the artwork's black screen and maps the printed buttons to NxNative's actual input. Restart the game to apply changes.")
            }
            Section {
                if let importedLandscape {
                    Image(uiImage: importedLandscape)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 220)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Label("Default red / cyan background", systemImage: "gamecontroller")
                        .foregroundStyle(.secondary)
                }
                Button("Import White Landscape Artwork", systemImage: "photo.badge.plus") {
                    pickingLandscape = true
                }
                .accessibilityIdentifier("settings.nxnative.landscapeImport")
                if importedLandscape != nil {
                    Button("Restore Default Landscape", systemImage: "arrow.uturn.backward") {
                        guard let landscapeAssetURL else { notice = "App Group unavailable"; return }
                        do {
                            try FileManager.default.removeItem(at: landscapeAssetURL)
                            importedLandscape = nil
                        } catch { notice = error.localizedDescription }
                    }
                }
            } header: {
                Text("Landscape Artwork")
            } footer: {
                Text("Import a landscape JPG or PNG. The artwork fills the screen while the live game aspect-fits inside its black display opening. Skin buttons and sticks use the imported layout; restart the game to apply changes.")
            }
        }
        .navigationTitle("NxNative Controller Skins")
        .onAppear(perform: load)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.png]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 8 * 1024 * 1024,
                      let image = UIImage(data: data),
                      image.size.width <= 2048,
                      image.size.height <= 4096,
                      image.size.height > image.size.width,
                      image.cgImage?.alphaInfo != .none
                else { throw NSError(domain: "StrataPortraitSkin", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Choose a portrait PNG with transparency, under 8 MB (max 2048×4096)."]) }
                guard let assetURL else {
                    throw NSError(domain: "StrataPortraitSkin", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "App Group is unavailable."])
                }
                try FileManager.default.createDirectory(
                    at: assetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: assetURL, options: .atomic)
                imported = image
                enabled = true
                notice = "Portrait artwork saved. Restart the NxNative game to apply it."
            } catch { notice = error.localizedDescription }
        }
        .fileImporter(isPresented: $pickingLandscape, allowedContentTypes: [.png, .jpeg]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let bytes = try Data(contentsOf: url)
                guard bytes.count <= 12 * 1024 * 1024,
                      let image = UIImage(data: bytes),
                      image.size.width > image.size.height,
                      image.size.width <= 4096,
                      image.size.height <= 2048,
                      let png = image.pngData(),
                      png.count <= 24 * 1024 * 1024
                else {
                    throw NSError(domain: "StrataLandscapeSkin", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Choose a landscape JPG/PNG under 12 MB (max 4096×2048)."])
                }
                guard let landscapeAssetURL else {
                    throw NSError(domain: "StrataLandscapeSkin", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "App Group is unavailable."])
                }
                try FileManager.default.createDirectory(
                    at: landscapeAssetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try png.write(to: landscapeAssetURL, options: .atomic)
                importedLandscape = image
                enabled = true
                notice = "Landscape artwork saved. Restart the NxNative game to apply it."
            } catch { notice = error.localizedDescription }
        }
        .alert("Controller Skin", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private func load() {
        imported = assetURL.flatMap { UIImage(contentsOfFile: $0.path) }
        importedLandscape = landscapeAssetURL.flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
