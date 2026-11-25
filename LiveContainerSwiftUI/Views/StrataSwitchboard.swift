import SwiftUI

struct StrataSwitchboard: View {
    let apps: [LCAppModel]
    let launch: (LCAppModel) -> Void
    let manage: (LCAppModel) -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    var launchWithJIT: ((LCAppModel) -> Void)? = nil
    var launchMultitask: ((LCAppModel) -> Void)? = nil
    var launchInGameMode: ((LCAppModel) -> Void)? = nil
    var launchInGameModeWithJIT: ((LCAppModel) -> Void)? = nil
    var launchWithMetalHUD: ((LCAppModel) -> Void)? = nil
    @StateObject private var controller = LiveBoardControllerInput()
    @StateObject private var artwork = LiveBoardArtworkStore()
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    @AppStorage("LiveBoardModeLibraries", store: LCUtils.appGroupUserDefault) private var savedLibrary = "{}"
    @AppStorage("ZNLibraryPresentation", store: LCUtils.appGroupUserDefault) private var presentation = "Switchboard"
    @State private var selectedKey = ""
    @State private var category: String?
    @State private var recentOnly = false
    @State private var editingLibrary = false
    @State private var newCategory = ""
    @State private var visible = false
    @AppStorage("ZNLastSeenWhatsNew", store: LCUtils.appGroupUserDefault) private var lastSeenWhatsNew = ""
    @State private var showingWhatsNew = false
    @State private var busy = false
    @State private var thermalConstrained = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    @State private var choosingCover = false
    @State private var onlineArtwork: StrataArtworkOnlineRequest?
    @State private var coverKey = ""
    @State private var artworkError: String?
    @State private var shortcutProfilesApp: LiveBoardAppearanceSelection?
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var libraries: [String: LiveBoardModeLibrary] { LiveBoardLibraryCache.decode(savedLibrary) }
    @AppStorage(LiveBoardSharedCategories.enabledKey, store: LCUtils.appGroupUserDefault) private var universalCategories = true
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @AppStorage("ZNBetaLowMemory", store: LCUtils.appGroupUserDefault) private var lowMemory = false
    @AppStorage("StrataSwitchboardAMOLEDDark", store: LCUtils.appGroupUserDefault) private var darkMode = false
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var nxSkinEnabled = true
    private var foreground: Color { darkMode ? .white : .black }
    private var background: Color { darkMode ? .black : .white }
    private var buttonSurface: Color { darkMode ? Color(white: 0.13) : Color(white: 0.92) }
    private var tilePlaceholder: Color { darkMode ? Color(white: 0.10) : Color(white: 0.95) }
    @StateObject private var audio = LiveBoardNavigationAudio()
    private var library: LiveBoardModeLibrary { _ = universalCategories; return LiveBoardSharedCategories.library(libraries, mode: "switchboard") }
    private var filtered: [LCAppModel] {
        let state = library
        let visible = apps.filter { !state.hidden.contains(liveBoardAppKey($0)) && (category == nil || state.assignments[liveBoardAppKey($0)] == category) }
        return recentOnly ? LiveBoardRecentGames.sorted(visible) : visible
    }
    private var selected: LCAppModel? { filtered.first { liveBoardAppKey($0) == selectedKey } ?? filtered.first }
    private func update(_ change: (inout LiveBoardModeLibrary) -> Void) {
        var all = libraries; var state = library; change(&state); LiveBoardSharedCategories.store(state, mode: "switchboard", into: &all)
        if let data = try? JSONEncoder().encode(all), let value = String(data: data, encoding: .utf8) { savedLibrary = value }
    }
    var body: some View {
        GeometryReader { geo in
            // One centered square cover per page. Swipe to navigate games.
            let margin = max(28, geo.safeAreaInsets.leading + 20)
            let tile = max(96, min(geo.size.height * 0.46, geo.size.width - margin * 2 - 10))
            let items = filtered
            ZStack {
                // Pure black OLED pixels in dark mode, pure white in light mode.
                background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    statusBar.padding(.horizontal, margin).padding(.top, 10)
                    // All / Games / Tools and AMOLED moon share one row.
                    categoryStrip.padding(.horizontal, margin).padding(.top, 4)
                    Spacer(minLength: 4)
                    libraryContent(items: items, tile: tile, width: geo.size.width - margin * 2)
                        .frame(height: tile + 70)
                        .onChange(of: selectedKey) { _ in
                            if sounds && phase == .active && visible && !busy { audio.play() }
                        }
                    if filtered.isEmpty { Text("No apps here. Add apps or change this category.").foregroundStyle(.secondary).padding(.horizontal, margin) }
                    Spacer(minLength: 4)
                    shortcutButtons.frame(maxWidth: .infinity).padding(.top, 12)
                    Spacer(minLength: 4)
                    Divider().overlay(foreground.opacity(0.15))
                    HStack {
                        Image(systemName: "gamecontroller.fill").foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            ForEach(["Switchboard", "Cinematic", "Shelf"], id: \.self) { name in
                                Button { if presentation != name { presentation = name; audio.play(.confirm) } } label: {
                                    if presentation == name { Label(name, systemImage: "checkmark") } else { Text(name) }
                                }
                            }
                        } label: { Label("Layout", systemImage: "square.grid.2x2") }
                        .accessibilityIdentifier("switchboard.libraryLayout")
                        if controller.connected {
                            HStack(spacing: 18) { Label("Options", systemImage: controller.detailsSymbol); Label("Open", systemImage: controller.confirmSymbol) }
                        }
                    }.font(.subheadline).padding(.horizontal, margin).padding(.vertical, 10)
                }

                // Keep the launcher unobstructed. The skin is a separate preview sheet,
                // not a guest input overlay: drawing it here hid every app and action.
            }
        }.foregroundStyle(foreground)
        .preferredColorScheme(darkMode ? .dark : .light)
        .background(LiveBoardOrientationLock(mask: .portrait))
        .onAppear { if !["Switchboard", "Cinematic", "Shelf"].contains(presentation) { presentation = "Switchboard" }; visible = true; artwork.resumeDecoding(); selectedKey = filtered.first.map(liveBoardAppKey) ?? ""; if lastSeenWhatsNew != ZNWhatsNewView.releaseID { showingWhatsNew = true } else { bind() } }
        .onDisappear { visible = false; controller.stop(); audio.stop(); trimPresentationCaches(pause: true) }
        .onChange(of: phase) { value in
            if value == .active { busy = false; artwork.resumeDecoding(); bind() }
            else { controller.stop(); audio.stop(); trimPresentationCaches(pause: true) }
        }
        .onChange(of: lowMemory) { _ in trimPresentationCaches(pause: busy || !visible || phase != .active) }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            thermalConstrained = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
            if thermalConstrained {
                if ProcessInfo.processInfo.thermalState == .critical { audio.stop() }
                trimPresentationCaches(pause: busy || !visible || phase != .active)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // Evict transient launcher data and invalidate queued decode results.
            // Keep the visible library usable so it can reload artwork on demand.
            controller.stop()
            audio.stop()
            trimPresentationCaches(pause: busy || !visible || phase != .active)
            if visible && phase == .active && !busy { bind() }
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardArtworkStore.trimNotification)) { _ in
            trimPresentationCaches(pause: busy || !visible || phase != .active)
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.pauseNotification)) { _ in controller.stop() }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.resumeNotification)) { _ in busy = false; if visible && phase == .active { artwork.resumeDecoding(); bind() } }
        .sheet(isPresented: $showingWhatsNew, onDismiss: {
            lastSeenWhatsNew = ZNWhatsNewView.releaseID
            bind()
        }) {
            NavigationView {
                ZNWhatsNewView().toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") { showingWhatsNew = false }
                    }
                }
            }.navigationViewStyle(.stack)
        }
        .sheet(isPresented: $choosingCover, onDismiss: bind) {
            LiveBoardWallpaperPicker { image in
                if let image { do { try artwork.save(image, for: coverKey, kind: .cover, mode: "switchboard") } catch { artworkError = error.localizedDescription } }
                choosingCover = false
            }
        }
        .sheet(item: $onlineArtwork, onDismiss: bind) { request in
            StrataSteamGridDBArtworkSearch(title: request.title, background: false) { image in
                do { try artwork.save(image, for: request.key, kind: .cover, mode: "switchboard") }
                catch { artworkError = error.localizedDescription }
                onlineArtwork = nil
            }
        }
        .sheet(item: $shortcutProfilesApp, onDismiss: bind) { selection in
            LiveBoardShortcutProfilesSheet(app: selection.app) { action in
                launchShortcut(selection.app, action)
            }
        }
        .alert("Artwork", isPresented: Binding(get: { artworkError != nil }, set: { if !$0 { artworkError = nil } })) { Button("OK") { artworkError = nil } } message: { Text(artworkError ?? "") }
        .onChange(of: filtered.map(liveBoardAppKey)) { keys in if !keys.contains(selectedKey) { selectedKey = keys.first ?? "" } }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardRecentGames.changed)) { _ in if !filtered.contains(where: { liveBoardAppKey($0) == selectedKey }) { selectedKey = filtered.first.map(liveBoardAppKey) ?? "" } }
        .sheet(isPresented: $editingLibrary, onDismiss: bind) {
            NavigationView {
                Form {
                    Section("Categories") {
                        HStack { TextField("New category", text: $newCategory); Button("Add") { update { _ = $0.addCategory(newCategory) }; newCategory = "" } }
                        ForEach(library.categories, id: \.self) { value in HStack { Text(value); Spacer(); Button("Remove") { update { $0.removeCategory(value) }; if category == value { category = nil } } } }
                    }
                    Section { Toggle("Navigation sounds", isOn: $sounds) }
                    Section("Hidden apps") {
                        ForEach(apps.filter { library.hidden.contains(liveBoardAppKey($0)) }, id: \.self) { app in
                            Button("Show \(customization.name(app))") { update { _ = $0.hidden.remove(liveBoardAppKey(app)) } }
                        }
                    }
                }.navigationTitle("Switchboard Library")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editingLibrary = false } } }
            }
        }.onChange(of: editingLibrary) { value in if value { controller.stop() } }
    }
    @ViewBuilder private func libraryContent(items: [LCAppModel], tile: CGFloat, width: CGFloat) -> some View {
        switch presentation {
        case "Cinematic":
            VStack(spacing: 4) {
                if let selected {
                    gameTile(selected, size: max(72, tile * 0.68))
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(items, id: \.self) { app in
                                compactTile(app, size: 48).id(liveBoardAppKey(app))
                            }
                        }.padding(.horizontal, 12)
                    }
                    .onChange(of: selectedKey) { key in proxy.scrollTo(key, anchor: .center) }
                }.frame(height: 76)
            }
        case "Shelf":
            let columns = 2
            let size = max(48, min(132, (width - CGFloat(columns + 1) * 12) / CGFloat(columns)))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 12) {
                        ForEach(items, id: \.self) { app in
                            gameTile(app, size: size).id(liveBoardAppKey(app))
                        }
                    }.padding(12)
                }
                .onChange(of: selectedKey) { key in proxy.scrollTo(key, anchor: .center) }
            }
        default:
            TabView(selection: $selectedKey) {
                ForEach(items, id: \.self) { app in
                    gameTile(app, size: tile)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(liveBoardAppKey(app))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityIdentifier("switchboard.pages")
        }
    }

    private func compactTile(_ app: LCAppModel, size: CGFloat) -> some View {
        let key = liveBoardAppKey(app)
        return Button { selectedKey = key } label: {
            VStack(spacing: 2) {
                Group {
                    if let cover = artwork.image(for: key, kind: .cover, mode: "switchboard", thumbnail: true) {
                        Image(uiImage: cover).resizable().scaledToFill()
                    } else if artwork.hasArtwork(for: key, kind: .cover, mode: "switchboard") {
                        tilePlaceholder
                    } else {
                        LiveBoardIconImage(app: app, dark: darkMode).scaledToFit()
                    }
                }.frame(width: size, height: size).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(foreground, lineWidth: selectedKey == key ? 2 : 0))
                Text(customization.name(app)).font(.caption2).lineLimit(1).frame(width: size + 12)
            }
        }.buttonStyle(.plain)
    }

    private func gameTile(_ app: LCAppModel, size tile: CGFloat) -> some View {
        let key = liveBoardAppKey(app)
        let isSelected = key == liveBoardAppKey(selected ?? app)
        let radius = tile * 0.035

        // The title must stay outside the context-menu source view.
        // Otherwise UIKit lifts the title together with the artwork, causing
        // the duplicated title to overlap STRATA during a long press.
        return VStack(spacing: 8) {
            Text(customization.name(app))
                .font(.system(size: max(15, tile * 0.075), weight: .bold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: tile + 10)
                .opacity(isSelected || presentation == "Shelf" ? 1 : 0)

            // Long press raises only this cover button (including its border).
            Button {
                if selectedKey == key { activate(app) } else { selectedKey = key }
            } label: {
                ZStack {
                    tilePlaceholder
                    if let cover = artwork.image(for: key, kind: .cover, mode: "switchboard") {
                        Image(uiImage: cover).resizable().scaledToFill()
                    } else if !artwork.hasArtwork(for: key, kind: .cover, mode: "switchboard") {
                        LiveBoardIconImage(app: app, dark: darkMode).scaledToFit()
                    }
                }
                .frame(width: tile, height: tile)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: radius + 5, style: .continuous)
                        .strokeBorder(foreground, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                .scaleEffect(isSelected ? 1.0 : 0.93)
                .opacity(isSelected ? 1.0 : 0.80)
                .animation((reduceMotion || lowMemory || thermalConstrained) ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(customization.name(app))
            .accessibilityIdentifier("switchboard.tile." + key)
            .contextMenu {
                Button("Launch default shortcut", systemImage: "play.fill") { activate(app) }
                if !(app.appInfo is StrataPhoneAppInfo) && !(app.appInfo is BuiltInSideStoreAppInfo) {
                    Button("Shortcut Profiles…", systemImage: "square.stack.3d.up") { controller.stop(); shortcutProfilesApp = LiveBoardAppearanceSelection(app: app) }
                    if let launchWithJIT {
                        Button("Launch with JIT", systemImage: "bolt.fill") {
                            prepareForLaunch(app, using: launchWithJIT)
                        }
                    }
                    if let launchMultitask {
                        Button("Multitask", systemImage: "rectangle.on.rectangle") {
                            prepareForLaunch(app, using: launchMultitask)
                        }
                    }
                    if let launchInGameMode {
                        Button("Request Game Mode", systemImage: "gamecontroller.fill") {
                            prepareForLaunch(app, using: launchInGameMode)
                        }
                    }
                    if let launchInGameModeWithJIT {
                        Button("Request Game Mode + JIT", systemImage: "bolt.circle.fill") {
                            prepareForLaunch(app, using: launchInGameModeWithJIT)
                        }
                    }
                    if let launchWithMetalHUD {
                        Button("Launch with Metal HUD", systemImage: "gauge.with.dots.needle.67percent") {
                            prepareForLaunch(app, using: launchWithMetalHUD)
                        }
                    }
                }
                Button("App settings", systemImage: "gearshape") { controller.stop(); manage(app) }
                Button("Choose cover artwork", systemImage: "photo") {
                    coverKey = key; choosingCover = true; controller.stop()
                }
                Button("Search cover on SteamGridDB", systemImage: "sparkles") {
                    onlineArtwork = StrataArtworkOnlineRequest(key: key, title: customization.name(app), kind: .cover, mode: "switchboard"); controller.stop()
                }
                StrataArrangeMenus(
                    app: app, visible: filtered, all: apps,
                    categories: library.categories, current: library.assignments[key]
                ) { value in update { $0.assignments[key] = value } }
                Button("Hide", systemImage: "eye.slash") {
                    update { _ = $0.hidden.insert(key) }
                }
            }
        }
        .frame(width: tile + 10)
        .id(key)
    }

    // The system status bar already displays time, Wi-Fi and battery.
    // Keep only Strata's wordmark to avoid a duplicated status bar.
    private var statusBar: some View {
        // Personalized fantasy wordmark: a gold angular Z with a green,
        // slanted Link-style cap, followed by a carved jade N.
        HStack(alignment: .bottom, spacing: 3) {
            ZNInitials(darkMode: darkMode)
                .frame(width: 74, height: 43)
            Text("’s")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .padding(.bottom, 2)
            Text("LIBRARY")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .tracking(1.25)
                .padding(.leading, 3)
                .padding(.bottom, 4)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ZN's Library")
    }
    private var categoryStrip: some View {
        // Categories have the whole top row; AMOLED controls live on the
        // shortcut rail at the far right, not beside All / Games / Tools.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                Button("All") { category = nil; recentOnly = false }.opacity(category == nil && !recentOnly ? 1 : 0.55)
                Button("Recently Played") { category = nil; recentOnly = true }.opacity(recentOnly ? 1 : 0.55)
                ForEach(library.visibleCategories(apps), id: \.self) { value in
                    Button(value) { category = value; recentOnly = false }.opacity(category == value && !recentOnly ? 1 : 0.55)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
    }
    private var shortcutButtons: some View {
        // Keep each real action within an equally wide column. The small
        // captions are visual labels only; tap and long-press actions stay on
        // their existing icon controls.
        HStack(spacing: 6) {
            shortcutCell("Apps") {
                roundButton("plus", label: "Manage apps", tint: .red) {
                    controller.stop(); openManagement()
                }
                .accessibilityIdentifier("switchboard.manageApps")
            }

            shortcutCell("Skin") {
                skinShortcut
                    .accessibilityIdentifier("switchboard.toggle.skin")
            }

            shortcutCell("Rotation") {
                if let selected {
                    // The exact same per-app LCOrientationLock property used
                    // by App Settings > Orientation. No second global toggle.
                    StrataAppRotationShortcut(app: selected, surface: buttonSurface)
                        .accessibilityIdentifier("switchboard.toggle.gameOrientation")
                } else {
                    roundButton("iphone.gen3", label: "Select an app to set its orientation", tint: .gray) {}
                        .disabled(true)
                }
            }

            shortcutCell("Settings") {
                roundButton("gearshape.fill", label: "Open ZN Settings", tint: .purple) {
                    controller.stop()
                    NotificationCenter.default.post(name: .strataOpenSettings, object: nil)
                }
                .accessibilityIdentifier("switchboard.open.settings")
            }

            shortcutCell("Dark") {
                roundButton(darkMode ? "moon.fill" : "moon",
                            label: darkMode ? "Disable AMOLED dark mode" : "Enable AMOLED dark mode",
                            tint: .cyan) {
                    darkMode.toggle()
                }
                .accessibilityIdentifier("switchboard.toggle.darkMode")
            }
        }
        // ONE continuous outline around all five icon+label columns.
        // The stroke and captions share the dark/light foreground.
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(foreground, lineWidth: 1.5)
                .allowsHitTesting(false)
        )
        .padding(.horizontal, 12)
        .buttonStyle(.plain)
    }

    private func shortcutCell<Content: View>(_ caption: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 5) {
            content()
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
    // Two mutually exclusive gestures: a short tap updates the shared
    // NxNative guest skin setting; holding never accidentally toggles it.
    // Use the same preference as Settings > NxNative Controller Skins.
    private var skinShortcut: some View {
        Image(systemName: "tshirt.fill")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(nxSkinEnabled ? Color.purple : Color.gray)
            .frame(width: 50, height: 50)
            .background(Circle().fill(buttonSurface))
            .contentShape(Circle())
            .gesture(
                LongPressGesture(minimumDuration: 0.55)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first(let didHold):
                            if didHold { openNxSkinSettings() }
                        case .second:
                            nxSkinEnabled.toggle()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(nxSkinEnabled
                ? "NxNative controller skin on. Tap to disable; hold for settings"
                : "NxNative controller skin off. Tap to enable; hold for settings")
            .accessibilityAction { nxSkinEnabled.toggle() }
            .accessibilityAction(named: Text("Open NxNative Controller Skin Settings")) {
                openNxSkinSettings()
            }
    }
    private func openNxSkinSettings() {
        controller.stop()
        NotificationCenter.default.post(name: .strataOpenNxNativeSkinSettings, object: nil)
    }

    private func roundButton(_ symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(Circle().fill(buttonSurface))
        }.accessibilityLabel(label)
    }

    private func trimPresentationCaches(pause: Bool) {
        artwork.trimTransientImages(pause: pause)
        LiveBoardIconStore.invalidate()
        customization.trimTransientImages()
    }
    private func activate(_ app: LCAppModel) {
        launchShortcut(app, LiveBoardShortcutProfiles.defaultProfile(for: app)?.action ?? .normal)
    }
    private func launchShortcut(_ app: LCAppModel, _ action: LiveBoardShortcutAction) {
        switch action {
        case .normal: prepareForLaunch(app, using: launch)
        case .jit: if let launchWithJIT { prepareForLaunch(app, using: launchWithJIT) }
        case .multitask: if let launchMultitask { prepareForLaunch(app, using: launchMultitask) }
        case .gameMode: if let launchInGameMode { prepareForLaunch(app, using: launchInGameMode) }
        case .gameModeJIT: if let launchInGameModeWithJIT { prepareForLaunch(app, using: launchInGameModeWithJIT) }
        case .metalHUD: if let launchWithMetalHUD { prepareForLaunch(app, using: launchWithMetalHUD) }
        }
    }
    private func prepareForLaunch(_ app: LCAppModel, using action: (LCAppModel) -> Void) {
        guard !busy else { return }
        busy = true
        controller.stop()
        audio.stop()
        trimPresentationCaches(pause: true)
        action(app)
        // Recover if a launch is cancelled while the library remains visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            busy = false
            if visible && phase == .active { artwork.resumeDecoding(); bind() }
        }
    }
    private func changeCategory(_ delta: Int) {
        let categories = library.visibleCategories(apps)
        let count = categories.count + 2
        let current = category.flatMap { categories.firstIndex(of: $0).map { $0 + 2 } } ?? (recentOnly ? 1 : 0)
        let index = (current + delta + count) % count
        recentOnly = index == 1
        category = index >= 2 ? categories[index - 2] : nil
    }
    private func bind() {
        guard visible, !showingWhatsNew, !editingLibrary, !choosingCover, !busy else { return }
        controller.onCommand = { command in
            let items = filtered
            let index = items.firstIndex { liveBoardAppKey($0) == selectedKey } ?? 0
            switch command {
            case .left: if index > 0 { selectedKey = liveBoardAppKey(items[index - 1]) }
            case .right: if index + 1 < items.count { selectedKey = liveBoardAppKey(items[index + 1]) }
            case .confirm: if let app = selected { activate(app) }
            case .details: audio.play(.confirm); if let app = selected { controller.stop(); manage(app) }
            case .previousSection: changeCategory(-1)
            case .nextSection: changeCategory(1)
            case .back: audio.play(.back); openInterface()
            default: break
            }
        }; controller.start()
    }
}



// Observes the SELECTED game model so changes in App Settings immediately
// update this icon, and a tap persists through LCAppInfo.orientationLock.
private struct StrataAppRotationShortcut: View {
    @ObservedObject var app: LCAppModel
    let surface: Color

    private var mode: LCOrientationLock { app.uiOrientationLock }

    private var symbol: String {
        // Render the same phone silhouette for both forced orientations.
        // A physical 90-degree turn makes Landscape unmistakably horizontal,
        // independently of SF Symbol artwork variants on different iOS builds.
        mode == .Disabled ? "arrow.triangle.2.circlepath" : "iphone"
    }
    private var modeName: String {
        switch mode {
        case .Landscape: return "Landscape"
        case .Portrait: return "Portrait"
        default: return "Auto"
        }
    }
    var body: some View {
        Button {
            // Mirror all three values from the actual App Settings picker:
            // Disabled (Auto) -> Landscape -> Portrait -> Disabled.
            switch app.uiOrientationLock {
            case .Disabled: app.uiOrientationLock = .Landscape
            case .Landscape: app.uiOrientationLock = .Portrait
            default: app.uiOrientationLock = .Disabled
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .rotationEffect(.degrees(mode == .Landscape ? 90 : 0))
                .foregroundStyle(.orange)
                .frame(width: 50, height: 50)
                .background(Circle().fill(surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App orientation: " + modeName + ". Tap to change for " + app.displayName)
        .accessibilityHint("Changes this app's Orientation Lock in App Settings. Applies on next launch.")
    }
}

// MARK: - ZN's Library hand-drawn vector initials
private func znScaledPath(_ p: Path, in rect: CGRect) -> Path {
    p.applying(CGAffineTransform(a: rect.width / 100, b: 0, c: 0,
                                d: rect.height / 100, tx: rect.minX, ty: rect.minY))
}

struct ZNInitials: View {
    let darkMode: Bool
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ZStack(alignment: .topLeading) {
                ZNFantasyZ()
                    .fill(LinearGradient(
                        colors: darkMode
                            ? [Color(red: 1, green: 0.90, blue: 0.61),
                               Color(red: 0.85, green: 0.58, blue: 0.20)]
                            : [Color(red: 0.76, green: 0.45, blue: 0.09),
                               Color(red: 0.51, green: 0.29, blue: 0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: FillStyle(eoFill: true))
                    .frame(width: 32, height: 30)
                    .offset(x: 3, y: 12)
                ZNLinkCap()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.32, green: 0.82, blue: 0.30),
                                 Color(red: 0.07, green: 0.42, blue: 0.18)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 30, height: 19)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -1, y: 0)
                Capsule()
                    .fill(Color(red: 0.95, green: 0.76, blue: 0.30))
                    .frame(width: 21, height: 2.5)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 6, y: 14)
            }
            .frame(width: 38, height: 43, alignment: .topLeading)
            ZNFantasyN()
                .fill(LinearGradient(
                    colors: darkMode
                        ? [Color(red: 0.59, green: 0.96, blue: 0.78),
                           Color(red: 0.16, green: 0.67, blue: 0.46)]
                        : [Color(red: 0.11, green: 0.55, blue: 0.40),
                           Color(red: 0.04, green: 0.34, blue: 0.23)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 30)
                .padding(.bottom, 1)
        }
        .accessibilityHidden(true)
    }
}

private struct ZNFantasyZ: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 5, y: 36))
        p.addQuadCurve(to: CGPoint(x: 20, y: 6), control: CGPoint(x: 14, y: 25))
        p.addLine(to: CGPoint(x: 91, y: 6))
        p.addLine(to: CGPoint(x: 100, y: 0))
        p.addLine(to: CGPoint(x: 91, y: 29))
        p.addLine(to: CGPoint(x: 85, y: 29))
        p.addLine(to: CGPoint(x: 87, y: 18))
        p.addLine(to: CGPoint(x: 77, y: 18))
        p.addLine(to: CGPoint(x: 28, y: 87))
        p.addLine(to: CGPoint(x: 91, y: 87))
        p.addLine(to: CGPoint(x: 99, y: 74))
        p.addLine(to: CGPoint(x: 97, y: 100))
        p.addLine(to: CGPoint(x: 4, y: 100))
        p.addLine(to: CGPoint(x: 11, y: 86))
        p.addLine(to: CGPoint(x: 66, y: 18))
        p.addLine(to: CGPoint(x: 29, y: 18))
        p.closeSubpath()
        // Small carved cuts like the supplied angular Z reference.
        p.move(to: CGPoint(x: 63, y: 51))
        p.addLine(to: CGPoint(x: 70, y: 45))
        p.addLine(to: CGPoint(x: 66, y: 59))
        p.closeSubpath()
        p.move(to: CGPoint(x: 50, y: 71))
        p.addLine(to: CGPoint(x: 56, y: 63))
        p.addLine(to: CGPoint(x: 55, y: 76))
        p.closeSubpath()
        return znScaledPath(p, in: rect)
    }
}

private struct ZNFantasyN: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: 10, y: 10, width: 14, height: 80))
        p.addRect(CGRect(x: 76, y: 10, width: 14, height: 80))
        p.move(to: CGPoint(x: 19, y: 10))
        p.addLine(to: CGPoint(x: 35, y: 10))
        p.addLine(to: CGPoint(x: 83, y: 89))
        p.addLine(to: CGPoint(x: 66, y: 89))
        p.closeSubpath()
        p.addRect(CGRect(x: 2, y: 5, width: 31, height: 8))
        p.addRect(CGRect(x: 3, y: 88, width: 31, height: 9))
        p.addRect(CGRect(x: 67, y: 5, width: 31, height: 8))
        p.addRect(CGRect(x: 67, y: 88, width: 31, height: 9))
        return znScaledPath(p, in: rect)
    }
}

private struct ZNLinkCap: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 14, y: 69))
        p.addCurve(to: CGPoint(x: 57, y: 18),
                   control1: CGPoint(x: 23, y: 38),
                   control2: CGPoint(x: 43, y: 14))
        p.addCurve(to: CGPoint(x: 92, y: 63),
                   control1: CGPoint(x: 73, y: 19),
                   control2: CGPoint(x: 89, y: 46))
        p.addQuadCurve(to: CGPoint(x: 73, y: 77),
                       control: CGPoint(x: 90, y: 78))
        p.addQuadCurve(to: CGPoint(x: 21, y: 78),
                       control: CGPoint(x: 44, y: 68))
        p.addQuadCurve(to: CGPoint(x: 4, y: 34),
                       control: CGPoint(x: 5, y: 65))
        p.addQuadCurve(to: CGPoint(x: 28, y: 52),
                       control: CGPoint(x: 18, y: 41))
        p.addLine(to: CGPoint(x: 14, y: 69))
        p.closeSubpath()
        return znScaledPath(p, in: rect)
    }
}
