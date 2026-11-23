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

 
// Built-in skin variants are available without importing a portrait or landscape PNG.
private struct StrataNxPortraitSkinSettings: View {
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault)
    private var enabled = true
    @AppStorage("StrataNxSkinStyle", store: LCUtils.appGroupUserDefault)
    private var style = "pearl"

    private var dark: Bool { style == "amoled" }

    var body: some View {
        Form {
            Section {
                Toggle("Enable NxNative Skin", isOn: $enabled)
                    .accessibilityIdentifier("settings.nxnative.skinEnabled")
            } footer: {
                Text("Both styles are built into Strata. No PNG import, download, or separate game IPA is needed. Restart a running NxNative game after changing skin settings.")
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
                Text("A single choice applies to both Portrait and Landscape. AMOLED Dark uses a nearly black shell and translucent-looking graphite buttons; Pearl Light uses a white pearl shell and metallic trim.")
            }

            Section("Portrait & Landscape") {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: false)
                            .frame(width: 96, height: 208)
                        Text("Portrait")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        StrataNxBuiltInSkinPreview(dark: dark, landscape: true)
                            .frame(maxWidth: 232)
                            .aspectRatio(1792.0/1008.0, contentMode: .fit)
                        Text("Landscape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
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

// Faithful SwiftUI preview: same normalized portrait / landscape centers as
// the zero-download Core Graphics built-in skins. It never draws game content.
private struct StrataNxBuiltInSkinPreview: View {
    let dark: Bool
    let landscape: Bool

    private var shell: Color {
        dark ? Color(red: 0.008, green: 0.010, blue: 0.014)
             : Color(red: 0.973, green: 0.973, blue: 0.956)
    }
    private var keyTop: Color {
        dark ? Color(red: 0.37, green: 0.41, blue: 0.46) : .white
    }
    private var keyBottom: Color {
        dark ? Color(red: 0.13, green: 0.16, blue: 0.20)
             : Color(red: 0.82, green: 0.84, blue: 0.82)
    }
    private var labelColor: Color { dark ? .white : Color(white: 0.35) }

    private var facePoints: [(String, CGFloat, CGFloat)] {
        landscape
        ? [("A", 0.8836, 0.6185), ("B", 0.8381, 0.6983),
           ("X", 0.8381, 0.5376), ("Y", 0.7925, 0.6185)]
        : [("A", 0.8746, 0.8371), ("B", 0.7472, 0.8953),
           ("X", 0.7485, 0.7729), ("Y", 0.6172, 0.8371)]
    }
    private var shoulderPoints: [(String, CGFloat)] {
        landscape
        ? [("L", 0.1430), ("ZL", 0.2146), ("R", 0.8126), ("ZR", 0.8628)]
        : [("L", 0.119), ("ZL", 0.283), ("R", 0.719), ("ZR", 0.879)]
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: landscape ? 13 : 17)
                    .fill(shell)
                    .overlay(RoundedRectangle(cornerRadius: landscape ? 13 : 17)
                        .strokeBorder(dark ? Color.white.opacity(0.23) : Color.gray.opacity(0.40)))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(dark ? Color(white: 0.34) : Color(white: 0.3), lineWidth: 1.5))
                    .frame(width: w * (landscape ? 863.0/1792.0 : 847.0/923.0),
                           height: h * (landscape ? 574.0/1008.0 : 661.0/2000.0))
                    .position(x: w * 0.50, y: h * (landscape ? 456.0/1008.0 : 468.5/2000.0))

                // Correct left D-pad, left stick and RIGHT look stick above ABXY.
                dpad(w: w, h: h)
                    .position(x: w * (landscape ? 0.1590 : 0.2490),
                              y: h * (landscape ? 0.3620 : 0.6460))
                analog(w: w)
                    .position(x: w * (landscape ? 0.1590 : 0.2438),
                              y: h * (landscape ? 0.6161 : 0.8379))
                analog(w: w)
                    .position(x: w * (landscape ? 0.8401 : 0.7466),
                              y: h * (landscape ? 0.3613 : 0.6449))

                ForEach(facePoints.indices, id: \.self) { index in
                    let point = facePoints[index]
                    key(point.0, w: w, h: h)
                        .position(x: w * point.1, y: h * point.2)
                }
                ForEach(shoulderPoints.indices, id: \.self) { index in
                    let item = shoulderPoints[index]
                    shoulder(item.0, w: w, h: h)
                        .position(x: w * item.1,
                                  y: h * (landscape ? 0.1827 : 0.504))
                }
                key("−", w: w, h: h, small: true)
                    .position(x: w * (landscape ? 0.4122 : 0.3452),
                              y: h * (landscape ? 0.7982 : 0.9363))
                key("⚙", w: w, h: h, small: true)
                    .position(x: w * 0.4999, y: h * (landscape ? 0.7982 : 0.9363))
                key("+", w: w, h: h, small: true)
                    .position(x: w * (landscape ? 0.5869 : 0.6559),
                              y: h * (landscape ? 0.7982 : 0.9363))
                Text("ZN")
                    .font(.system(size: landscape ? 9 : 11, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 0.73, green: 0.53, blue: 0.18))
                    .position(x: w * (landscape ? 0.12 : 0.12),
                              y: h * (landscape ? 0.80 : 0.94))
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dark ? "AMOLED Dark controller skin preview" : "Pearl Light controller skin preview")
    }

    private func surface() -> LinearGradient {
        LinearGradient(colors: [keyTop, keyBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private func key(_ title: String, w: CGFloat, h: CGFloat, small: Bool = false) -> some View {
        let diameter = w * (landscape ? (small ? 0.026 : 0.040) : (small ? 0.068 : 0.095))
        return Circle()
            .fill(surface())
            .overlay(Circle().strokeBorder(dark ? Color.gray.opacity(0.65) : Color.gray.opacity(0.4),
                                            lineWidth: 0.75))
            .frame(width: diameter, height: diameter)
            .overlay(Text(title)
                .font(.system(size: max(4, diameter * 0.42), weight: .semibold))
                .foregroundStyle(labelColor))
    }
    private func shoulder(_ title: String, w: CGFloat, h: CGFloat) -> some View {
        let width = w * (landscape ? 0.044 : 0.126)
        let height = h * (landscape ? 0.036 : 0.022)
        return RoundedRectangle(cornerRadius: 2)
            .fill(surface())
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.gray.opacity(0.5)))
            .frame(width: width, height: height)
            .overlay(Text(title).font(.system(size: max(4, height * 0.67), weight: .semibold))
                .foregroundStyle(labelColor))
    }
    private func analog(w: CGFloat) -> some View {
        let diameter = w * (landscape ? 114.0/1792.0 : 140.0/923.0)
        return Circle()
            .fill(keyBottom)
            .overlay(Circle().strokeBorder(dark ? Color.gray : Color(white: 0.5), lineWidth: 1))
            .frame(width: diameter, height: diameter)
            .overlay(Circle().fill(surface())
                .frame(width: diameter * 0.68, height: diameter * 0.68)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.27))))
    }
    private func dpad(w: CGFloat, h: CGFloat) -> some View {
        let width = w * (landscape ? 130.0/1792.0 : 182.0/923.0)
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(surface())
                .frame(width: width * 0.40, height: width)
            RoundedRectangle(cornerRadius: 3)
                .fill(surface())
                .frame(width: width, height: width * 0.40)
        }
        .overlay(Circle().fill(keyBottom).frame(width: width * 0.13))
        .frame(width: width, height: width)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray.opacity(0.25)))
    }
}
