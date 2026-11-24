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
        } header: { Text("Performance") } footer: { Text("The overlay shows memory used and the limit for ZN, each app and each helper (RAM donor) process, with peaks.") }
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

 
// Built-in skin variants are available without importing a portrait or landscape PNG.
private struct StrataNxPortraitSkinSettings: View {
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault)
    private var enabled = true
    @AppStorage("StrataNxSkinStyle", store: LCUtils.appGroupUserDefault)
    private var style = "pearl"
    @AppStorage("StrataNxDisplayLayout", store: LCUtils.appGroupUserDefault)
    private var displayLayout = "wide"

    private var dark: Bool { style == "amoled" }

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
                Picker("Controller Skin", selection: $style) {
                    Text("Pearl Light").tag("pearl")
                    Text("AMOLED Dark").tag("amoled")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.nxnative.builtinStyle")

                HStack(spacing: 10) {
                    skinStyleCard(name: "Pearl Light", value: "pearl",
                                  detail: "Pearl white · warm silver")
                    skinStyleCard(name: "AMOLED Dark", value: "amoled",
                                  detail: "Wii U graphite · smoked glass")
                }
            } header: {
                Text("Built-in Skins")
            } footer: {
                Text("Both styles use the user's original portrait and landscape photo geometry. AMOLED Dark keeps the same controls, with OLED black and graphite buttons plus white glyphs. The input remapping and lower-left ZN logo are identical.")
            }

            Section {
                Picker("Display Size", selection: $displayLayout) {
                    Text("Classic").tag("classic")
                    Text("Wide").tag("wide")
                    Text("Full Screen").tag("full")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.nxnative.displayLayout")
            } header: {
                Text("Game Display")
            } footer: {
                Text("Wide (default) enlarges the 16:9 game area and moves the landscape controls outward. Portrait uses the full screen width. Classic retains the original shell. Full Screen uses the largest uncropped 16:9 viewport with native translucent controls instead of the photo skin. Restart NxNative to apply. Render scale is unchanged.")
            }

            Section("Portrait & Landscape") {
                if displayLayout == "full" {
                    Label("Full Screen uses NxNative's own transparent controls; their appearance depends on the game.", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: false, layout: displayLayout)
                            .frame(width: 96, height: 208)
                        Text("Portrait")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: true, layout: displayLayout)
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

            Section {
                Label("Touch mapping, low-latency pearl/graphite press feedback and the small ZN logo are included with both styles.",
                      systemImage: "gamecontroller.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
            } footer: {
                Text("Existing imported artwork files, if any, are left untouched on disk. These two built-in styles do not require them.")
            }
        }
        .navigationTitle("NxNative Controller Skins")
    }

    @ViewBuilder
    private func skinStyleCard(name: String, value: String, detail: String) -> some View {
        Button {
            style = value
            enabled = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: style == value ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(style == value ? Color.accentColor : Color.secondary)
                    Spacer()
                    Circle()
                        .fill(value == "amoled" ? Color(white: 0.13) : Color(white: 0.94))
                        .frame(width: 23, height: 23)
                        .overlay(Circle().strokeBorder(Color.gray.opacity(0.5)))
                }
                Text(name).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style == value ? Color.accentColor : Color.gray.opacity(0.19),
                              lineWidth: style == value ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.nxnative.style." + value)
    }
}

// The preview is rendered by the same Core Graphics photo pipeline as
// the NxNative overlay. This prevents Settings from showing the obsolete
// synthetic vector-controller design when bundled user images are available.
private struct StrataNxBuiltInSkinPreview: View {
    let dark: Bool
    let landscape: Bool
    let layout: String

    var body: some View {
        GeometryReader { geo in
            if let image = StrataNxSkinPreviewImageForLayout(!landscape, dark, layout) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dark ? Color.black : Color(white: 0.96))
                    .overlay(Text("Skin image unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dark ? "AMOLED Dark controller skin preview"
                                 : "Pearl Light controller skin preview")
    }
}
