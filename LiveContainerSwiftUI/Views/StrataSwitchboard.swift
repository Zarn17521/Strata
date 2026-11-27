import SwiftUI

struct StrataSwitchboard: View {
    let apps: [LCAppModel]
    let launch: (LCAppModel) -> Void
    let manage: (LCAppModel) -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    var canAddGame: Bool = true
    private let addGameKey = "__zn_library_add_game__"
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
    @State private var pendingLaunch: Task<Void, Never>?
    @State private var thermalConstrained = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    @State private var showingSkinSettings = false
    @State private var showingJITSettings = false
    @State private var choosingCover = false
    @State private var onlineArtwork: StrataArtworkOnlineRequest?
    @State private var coverKey = ""
    @State private var artworkError: String?
    @State private var shelfOptionsApp: LiveBoardAppearanceSelection?
    @State private var pendingShelfAction: (() -> Void)?
    @State private var shortcutProfilesApp: LiveBoardAppearanceSelection?
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var libraries: [String: LiveBoardModeLibrary] { LiveBoardLibraryCache.decode(savedLibrary) }
    @AppStorage(LiveBoardSharedCategories.enabledKey, store: LCUtils.appGroupUserDefault) private var universalCategories = true
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @AppStorage("ZNBetaLowMemory", store: LCUtils.appGroupUserDefault) private var lowMemory = false
    @AppStorage("StrataSwitchboardAMOLEDDark", store: LCUtils.appGroupUserDefault) private var darkMode = false
    @AppStorage("ZNLibraryHomeLandscape", store: LCUtils.appGroupUserDefault) private var homeLandscape = false
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var nxSkinEnabled = true
    @AppStorage("ZNCompactPerformanceHUD", store: LCUtils.appGroupUserDefault) private var compactHUD = true
    @AppStorage("ZNAutoBuiltInJIT", store: LCUtils.appGroupUserDefault) private var autoBuiltInJIT = false
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var jitProvider = JITEnablerType.BuiltIn.rawValue
    @AppStorage("ZNAutoGameMode", store: LCUtils.appGroupUserDefault) private var autoGameMode = false
    private var builtInJITEnabled: Bool { autoBuiltInJIT && jitProvider == JITEnablerType.BuiltIn.rawValue }
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
    private var selected: LCAppModel? {
        if selectedKey == addGameKey { return nil }
        return filtered.first { liveBoardAppKey($0) == selectedKey } ?? filtered.first
    }
    private func orderedPageKeys(_ items: [LCAppModel]) -> [String] {
        let games = items.map(liveBoardAppKey)
        guard canAddGame else { return games }
        return presentation == "Switchboard" ? [addGameKey] + games : games + [addGameKey]
    }
    private func reconcileSelection(_ keys: [String], preferNewGame: Bool = false) {
        if selectedKey == addGameKey && canAddGame && !preferNewGame { return }
        if !keys.contains(selectedKey) {
            if presentation == "Switchboard" && canAddGame && !preferNewGame {
                selectedKey = addGameKey
            } else {
                selectedKey = keys.first ?? (canAddGame ? addGameKey : "")
            }
        }
    }
    private func addGame() {
        guard canAddGame, !busy else { return }
        controller.stop()
        openManagement()
    }
    private func update(_ change: (inout LiveBoardModeLibrary) -> Void) {
        var all = libraries; var state = library; change(&state); LiveBoardSharedCategories.store(state, mode: "switchboard", into: &all)
        if let data = try? JSONEncoder().encode(all), let value = String(data: data, encoding: .utf8) { savedLibrary = value }
    }
    var body: some View {
        GeometryReader { geo in
            // One centered square cover per page. Swipe to navigate games.
            let landscape = geo.size.width > geo.size.height
            let margin = landscape ? CGFloat(16) : max(16, geo.safeAreaInsets.leading + 12)
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
                    if landscape {
                        let railWidth = min(CGFloat(214), geo.size.width * 0.32)
                        let contentWidth = max(96, geo.size.width - margin * 2 - railWidth - 12)
                        HStack(spacing: 12) {
                            libraryContent(items: items, tile: max(64, min(tile, geo.size.height - (presentation == "Switchboard" ? 218 : 190))), width: contentWidth)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            shortcutButtons(landscape: true).frame(width: railWidth)
                        }
                        .padding(.horizontal, margin)
                        .frame(maxHeight: .infinity)
                    } else {
                        libraryContent(items: items, tile: tile, width: geo.size.width - margin * 2)
                            .frame(height: tile + (presentation == "Switchboard" ? 98 : 70))
                        if filtered.isEmpty && !canAddGame { Text("No apps here. Add apps or change this category.").foregroundStyle(.secondary).padding(.horizontal, margin) }
                        Spacer(minLength: 4)
                        shortcutButtons(landscape: false).frame(maxWidth: .infinity).padding(.top, 12)
                    }
                    Spacer(minLength: 4)
                    Divider().overlay(foreground.opacity(0.15))
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(controller.connected ? Color.green : Color.gray)
                            .accessibilityLabel(controller.connected ? "Controller connected" : "Controller disconnected")
                        Spacer()
                        Menu {
                            ForEach(["Switchboard", "Cinematic", "Shelf"], id: \.self) { name in
                                Button { if presentation != name { presentation = name } } label: {
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
        .background(LiveBoardOrientationLock(mask: homeLandscape ? .landscape : .portrait,
                                             active: visible && !busy))
        .onChange(of: selectedKey) { _ in
            if sounds && phase == .active && visible && !busy { audio.play() }
        }
        .onAppear {
            if !["Switchboard", "Cinematic", "Shelf"].contains(presentation) { presentation = "Switchboard" }
            visible = true
            if !busy && phase == .active { artwork.resumeDecoding() }
            reconcileSelection(filtered.map(liveBoardAppKey))
            if lastSeenWhatsNew != ZNWhatsNewView.releaseID { showingWhatsNew = true } else { bind() }
        }
        .onDisappear {
            visible = false
            cancelPendingLaunch()
            controller.stop()
            audio.stop()
            trimPresentationCaches(pause: true)
        }
        .onChange(of: phase) { value in
            if value == .active { busy = false; artwork.resumeDecoding(); bind() }
            else {
                cancelPendingLaunch()
                controller.stop()
                audio.stop()
                trimPresentationCaches(pause: true)
            }
        }
        .onChange(of: lowMemory) { _ in trimPresentationCaches(pause: busy || !visible || phase != .active) }
        .onChange(of: filtered.map(liveBoardAppKey)) { keys in
            reconcileSelection(keys)
        }
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
            trimPresentationCaches(pause: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.pauseNotification)) { _ in controller.stop() }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.resumeNotification)) { _ in
            cancelPendingLaunch()
            busy = false
            if visible && phase == .active { artwork.resumeDecoding(); bind() }
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.launchFailedNotification)) { _ in
            cancelPendingLaunch()
            busy = false
            if visible && phase == .active { artwork.resumeDecoding(); bind() }
        }
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
        .fullScreenCover(isPresented: $showingJITSettings, onDismiss: bind) {
            LiveBoardJITSetup()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
        .fullScreenCover(isPresented: $showingSkinSettings, onDismiss: bind) {
            NavigationView {
                StrataNxPortraitSkinSettings()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSkinSettings = false }
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
        .sheet(item: $shelfOptionsApp, onDismiss: {
            let action = pendingShelfAction
            pendingShelfAction = nil
            if let action { action() } else { bind() }
        }) { selection in
            NavigationView {
                Form {
                    appOptions(selection.app, perform: { action in
                        pendingShelfAction = action
                        shelfOptionsApp = nil
                    })
                }
                .navigationTitle(customization.name(selection.app))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { shelfOptionsApp = nil }
                    }
                }
            }.navigationViewStyle(.stack)
        }
        .sheet(item: $shortcutProfilesApp, onDismiss: bind) { selection in
            LiveBoardShortcutProfilesSheet(app: selection.app) { action in
                launchShortcut(selection.app, action)
            }
        }
        .alert("Artwork", isPresented: Binding(get: { artworkError != nil }, set: { if !$0 { artworkError = nil } })) { Button("OK") { artworkError = nil } } message: { Text(artworkError ?? "") }
        .onChange(of: canAddGame) { _ in reconcileSelection(filtered.map(liveBoardAppKey)) }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardRecentGames.changed)) { _ in reconcileSelection(filtered.map(liveBoardAppKey)) }
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
                        .id(liveBoardAppKey(selected))
                } else if canAddGame {
                    addGameTile(size: max(72, tile * 0.68))
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(items, id: \.self) { app in
                                compactTile(app, size: 48).id(liveBoardAppKey(app))
                            }
                            if canAddGame {
                                Button { selectedKey = addGameKey } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 25, weight: .semibold))
                                            .frame(width: 48, height: 48)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(buttonSurface))
                                        Text("Add Game").font(.caption2).lineLimit(1)
                                    }
                                }.buttonStyle(.plain).id(addGameKey)
                            }
                        }.padding(.horizontal, 12)
                    }
                    .onAppear { if !selectedKey.isEmpty { proxy.scrollTo(selectedKey, anchor: .center) } }
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
                            gameTile(app, size: size, shelf: true).id(liveBoardAppKey(app))
                        }
                        if canAddGame { addGameTile(size: size).id(addGameKey) }
                    }.padding(12)
                }
                .onAppear { if !selectedKey.isEmpty { proxy.scrollTo(selectedKey, anchor: .center) } }
                .onChange(of: selectedKey) { key in proxy.scrollTo(key, anchor: .center) }
            }
        default:
            VStack(spacing: 4) {
                TabView(selection: $selectedKey) {
                    if canAddGame {
                        addGameTile(size: tile)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(addGameKey)
                    }
                    ForEach(items, id: \.self) { app in
                        gameTile(app, size: tile)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(liveBoardAppKey(app))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("switchboard.pages")
                if presentation == "Switchboard" {
                    pageIndicator(items: items)
                }
            }
        }
    }

    // The permanent first page is Home (Add Game). Keep its house visible
    // even when a large library needs a sliding window of ordinary game dots.
    @ViewBuilder private func pageIndicator(items: [LCAppModel]) -> some View {
        let keys = orderedPageKeys(items)
        let games = items.map(liveBoardAppKey)
        if !keys.isEmpty {
            let current = keys.firstIndex(of: selectedKey) ?? 0
            let selectedGame = games.firstIndex(of: selectedKey) ?? 0
            let count = min(canAddGame ? 6 : 7, games.count)
            let start = max(0, min(selectedGame - count / 2, games.count - count))
            HStack(spacing: 8) {
                if canAddGame {
                    Button {
                        selectedKey = addGameKey
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(foreground.opacity(selectedKey == addGameKey ? 1 : 0.32))
                            .frame(width: 22, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    .accessibilityLabel("Home, Add Game")
                    .accessibilityAddTraits(selectedKey == addGameKey ? .isSelected : [])
                    .accessibilityIdentifier("switchboard.homePage")
                }
                ForEach(start..<(start + count), id: \.self) { index in
                    Circle()
                        .fill(foreground.opacity(selectedKey == games[index] ? 1 : 0.32))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule().fill(foreground.opacity(darkMode ? 0.075 : 0.035)) }
            }
            .overlay { Capsule().strokeBorder(foreground.opacity(0.22), lineWidth: 0.75) }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Library page")
            .accessibilityValue("\(current + 1) of \(keys.count)")
            .accessibilityIdentifier("switchboard.pageIndicator")
        }
    }

    // Keep tile identity and scroll state while dropping the image views and
    // their retained last-ready bitmaps during guest launch or backgrounding.
    @ViewBuilder
    private func tileArtwork(_ app: LCAppModel, key: String, thumbnail: Bool = false, shelf: Bool = false) -> some View {
        if busy || phase == .background {
            tilePlaceholder
        } else {
            LiveBoardCoverImage(store: artwork, key: key, app: app, darkMode: darkMode, thumbnail: thumbnail, shelf: shelf)
                .id(key)
        }
    }

    private func compactTile(_ app: LCAppModel, size: CGFloat) -> some View {
        let key = liveBoardAppKey(app)
        return Button { selectedKey = key } label: {
            VStack(spacing: 2) {
                Group {
                    tileArtwork(app, key: key, thumbnail: true)
                }.frame(width: size, height: size).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(foreground, lineWidth: selectedKey == key ? 2 : 0))
                Text(customization.name(app)).font(.caption2).lineLimit(1).frame(width: size + 12)
            }
        }.buttonStyle(.plain)
    }

    private func addGameTile(size tile: CGFloat) -> some View {
        let radius = tile * 0.035
        return VStack(spacing: 8) {
            Text("Add Game")
                .font(.system(size: max(15, tile * 0.075), weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: tile + 10)
            Button(action: addGame) {
                VStack(spacing: max(6, tile * 0.04)) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: tile * 0.23, weight: .semibold))
                    Text("Manage Apps")
                        .font(.system(size: max(10, tile * 0.045), weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(foreground)
                .frame(width: tile, height: tile)
                .background(tilePlaceholder)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(5)
                .overlay(RoundedRectangle(cornerRadius: radius + 5, style: .continuous)
                    .strokeBorder(foreground.opacity(selectedKey == addGameKey ? 1 : 0.45),
                                  lineWidth: selectedKey == addGameKey ? 3 : 1))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("Add Game")
            .accessibilityHint("Opens Manage Apps to import or manage games.")
            .accessibilityIdentifier("switchboard.addGame")
        }.frame(width: tile + 10)
    }

    private func gameTile(_ app: LCAppModel, size tile: CGFloat, shelf: Bool = false) -> some View {
        let key = liveBoardAppKey(app)
        let isSelected = selected.map(liveBoardAppKey) == key
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
                    tileArtwork(app, key: key, shelf: shelf)
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
                Button("Options…", systemImage: "ellipsis.circle") {
                    controller.stop()
                    shelfOptionsApp = LiveBoardAppearanceSelection(app: app)
                }
            }
        }
        .frame(width: tile + 10)
    }

    @ViewBuilder private func appOptions(_ app: LCAppModel, perform: @escaping (@escaping () -> Void) -> Void) -> some View {
        let key = liveBoardAppKey(app)
                Button("Launch default shortcut", systemImage: "play.fill") {
                    perform { launchShortcut(app, LiveBoardShortcutProfiles.defaultProfile(for: app)?.action ?? .normal) }
                }
                if !(app.appInfo is StrataPhoneAppInfo) && !(app.appInfo is BuiltInSideStoreAppInfo) {
                    Button("Shortcut Profiles…", systemImage: "square.stack.3d.up") { perform { controller.stop(); shortcutProfilesApp = LiveBoardAppearanceSelection(app: app) } }
                    if let launchWithJIT {
                        Button("Launch with JIT", systemImage: "bolt.fill") {
                            perform { prepareForLaunch(app, using: launchWithJIT) }
                        }
                    }
                    if let launchMultitask {
                        Button("Multitask", systemImage: "rectangle.on.rectangle") {
                            perform { prepareForLaunch(app, using: launchMultitask) }
                        }
                    }
                    if let launchInGameMode {
                        Button("Request Game Mode", systemImage: "gamecontroller.fill") {
                            perform { prepareForLaunch(app, using: launchInGameMode) }
                        }
                    }
                    if let launchInGameModeWithJIT {
                        Button("Request Game Mode + JIT", systemImage: "bolt.circle.fill") {
                            perform { prepareForLaunch(app, using: launchInGameModeWithJIT) }
                        }
                    }
                }
                Button("App settings", systemImage: "gearshape") { perform { controller.stop(); manage(app) } }
                Button("Choose cover artwork", systemImage: "photo") {
                    perform { coverKey = key; choosingCover = true; controller.stop() }
                }
                Button("Search cover on SteamGridDB", systemImage: "sparkles") {
                    perform { onlineArtwork = StrataArtworkOnlineRequest(key: key, title: customization.name(app), kind: .cover, mode: "switchboard"); controller.stop() }
                }
                StrataArrangeMenus(
                    app: app, visible: filtered, all: apps,
                    categories: library.categories, current: library.assignments[key]
                ) { value in update { $0.assignments[key] = value } }
                Button("Hide", systemImage: "eye.slash") {
                    perform { update { _ = $0.hidden.insert(key) } }
                }
    }

    private var statusBar: some View {
        HStack(spacing: 4) {
            // Match the monochrome app branding; the launcher wordmark
            // scales within its own space, leaving all three shortcuts tappable.
            Text("Zn’s Library")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(foreground)
                .frame(height: 44, alignment: .leading)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("switchboard.libraryWordmark")
            Spacer(minLength: 0)
            // Header shortcuts keep the dock focused on gameplay controls.
            // Low Memory Mode remains available in Settings > Performance.
            Button {
                darkMode.toggle()
            } label: {
                Image(systemName: darkMode ? "moon.fill" : "moon")
                    .font(.system(size: 29, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(foreground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(darkMode ? "Disable AMOLED dark mode" : "Enable AMOLED dark mode")
            .accessibilityValue(darkMode ? "On" : "Off")
            .accessibilityIdentifier("switchboard.toggle.darkMode")
            Button {
                homeLandscape.toggle()
            } label: {
                ZNLibraryRotateIcon(landscape: homeLandscape)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(foreground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("Library rotation")
            .accessibilityValue(homeLandscape ? "Landscape" : "Portrait")
            .accessibilityHint("Changes library orientation only, not game orientation.")
            .accessibilityIdentifier("switchboard.toggle.homeOrientation")
            Button {
                controller.stop()
                NotificationCenter.default.post(name: .strataOpenSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 29, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(foreground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open ZN Settings")
            .accessibilityIdentifier("switchboard.open.settings")
        }
    }
    private var categoryStrip: some View {
        // Categories retain their own row; AMOLED controls live in the header.
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
    private func shortcutButtons(landscape: Bool) -> some View {
        // Keep each real action within an equally wide column. The small
        // captions are visual labels only; tap and long-press actions stay on
        // their existing icon controls.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 5),
                                 count: landscape ? 2 : 5), spacing: 10) {
            shortcutCell("Skin") {
                skinShortcut
                    .accessibilityIdentifier("switchboard.toggle.skin")
            }

            shortcutCell("Game Rotation") {
                if let selected, !(selected.appInfo is StrataPhoneAppInfo), !(selected.appInfo is BuiltInSideStoreAppInfo), !(selected.appInfo is StrataSettingsAppInfo) {
                    // The exact same per-app LCOrientationLock property used
                    // by App Settings > Orientation. No second global toggle.
                    StrataAppRotationShortcut(app: selected, surface: buttonSurface, foreground: foreground)
                        .accessibilityIdentifier("switchboard.toggle.gameOrientation")
                } else {
                    roundButton("iphone.gen3", label: "Select an app to set its orientation") {}
                        .disabled(true)
                }
            }

            shortcutCell("Zn’s HUD") {
                Button { compactHUD.toggle() } label: {
                    Image(systemName: "gauge")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(compactHUD ? foreground : foreground.opacity(0.4))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(buttonSurface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zn’s HUD")
                .accessibilityValue(compactHUD ? "On" : "Off")
                .accessibilityHint("Applies on the next game launch.")
                .accessibilityIdentifier("switchboard.toggle.znHUD")
            }
            shortcutCell("Built-in JIT") {
                jitShortcut
            }
            shortcutCell("Game Mode") {
                Button { autoGameMode.toggle() } label: {
                    Image(systemName: autoGameMode ? "gamecontroller.fill" : "gamecontroller")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(autoGameMode ? foreground : foreground.opacity(0.4))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(buttonSurface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Automatic Game Mode request")
                .accessibilityValue(autoGameMode ? "On" : "Off")
                .accessibilityHint("Requests iOS Game Mode on a new guest launch. iOS decides activation.")
                .accessibilityIdentifier("switchboard.toggle.gameMode")
            }
        }
        // ONE continuous outline around the five gameplay shortcuts.
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
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .frame(minHeight: 24, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }
    private func toggleBuiltInJIT() {
        if builtInJITEnabled {
            autoBuiltInJIT = false
        } else {
            jitProvider = JITEnablerType.BuiltIn.rawValue
            autoBuiltInJIT = true
        }
    }
    private func openJITSettings() {
        controller.stop()
        showingJITSettings = true
    }
    private var jitShortcut: some View {
        Image(systemName: builtInJITEnabled ? "bolt.fill" : "bolt.slash")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(builtInJITEnabled ? foreground : foreground.opacity(0.4))
            .frame(width: 50, height: 50)
            .background(Circle().fill(buttonSurface))
            .contentShape(Circle())
            .gesture(
                LongPressGesture(minimumDuration: 0.55)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first(let held): if held { openJITSettings() }
                        case .second: toggleBuiltInJIT()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Automatic built-in JIT")
            .accessibilityValue(builtInJITEnabled ? "On" : "Off")
            .accessibilityHint("Tap to toggle automatic JIT. Hold for JIT setup.")
            .accessibilityAction { toggleBuiltInJIT() }
            .accessibilityAction(named: Text("Open JIT settings")) { openJITSettings() }
            .accessibilityIdentifier("switchboard.toggle.builtInJIT")
    }
    // Two mutually exclusive gestures: a short tap updates the shared
    // NxNative guest skin setting; holding never accidentally toggles it.
    // Use the same preference as Settings > NxNative Controller Skins.
    private var skinShortcut: some View {
        Image(systemName: nxSkinEnabled ? "tshirt.fill" : "tshirt")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(foreground)
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
        showingSkinSettings = true
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(foreground)
                .frame(width: 50, height: 50)
                .background(Circle().fill(buttonSurface))
        }.accessibilityLabel(label)
    }

    private func trimPresentationCaches(pause: Bool) {
        artwork.trimTransientImages(pause: pause)
        LiveBoardIconStore.invalidate()
        customization.trimTransientImages()
        StrataNxTrimSkinPreviewCache()
    }
    private func activate(_ app: LCAppModel) {
        // Ordinary cover taps/controller confirms follow the dock only.
        // Saved profiles are still available from the explicit shortcut menu.
        prepareForLaunch(app, using: launch)
    }
    private func launchShortcut(_ app: LCAppModel, _ action: LiveBoardShortcutAction) {
        switch action {
        case .normal: prepareForLaunch(app, using: launch)
        case .jit: if let launchWithJIT { prepareForLaunch(app, using: launchWithJIT) }
        case .multitask: if let launchMultitask { prepareForLaunch(app, using: launchMultitask) }
        case .gameMode: if let launchInGameMode { prepareForLaunch(app, using: launchInGameMode) }
        case .gameModeJIT: if let launchInGameModeWithJIT { prepareForLaunch(app, using: launchInGameModeWithJIT) }
        case .metalHUD: prepareForLaunch(app, using: launch) // Legacy profile fallback
        }
    }
    private func cancelPendingLaunch() {
        guard let pendingLaunch else { return }
        pendingLaunch.cancel()
        self.pendingLaunch = nil
        busy = false
    }

    private func prepareForLaunch(_ app: LCAppModel, using action: @escaping (LCAppModel) -> Void) {
        guard !busy, visible, phase == .active else { return }
        busy = true
        controller.stop()
        audio.stop()
        let before = LCUtils.appGroupUserDefault.bool(forKey: StrataMemoryOverlay.key)
            ? LCUtils.strataLauncherMemorySample() : nil
        trimPresentationCaches(pause: true)
        pendingLaunch = Task { @MainActor in
            let remaining = await artwork.waitForLaunchDecodeDrain()
            guard !Task.isCancelled else { return }
            pendingLaunch = nil
            if let before {
                let after = LCUtils.strataLauncherMemorySample()
                saveLaunchMemorySample(before: before, after: after, pendingDecodes: remaining)
            }
            // Decode stays paused until the existing return or failure signal.
            action(app)
        }
    }

    private func saveLaunchMemorySample(before: [AnyHashable: Any],
                                        after: [AnyHashable: Any], pendingDecodes: Int) {
        guard let root = LCSharedUtils.appGroupPath() else { return }
        let directory = root.appendingPathComponent("Library/StrataDiagnostics", isDirectory: true)
        let sample: [String: Any] = [
            "schema": 1, "sampledAt": Date().timeIntervalSince1970,
            "beforeTrim": before, "beforeHandoff": after, "pendingDecodes": pendingDecodes
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: sample) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("launcher-memory.json"), options: .atomic)
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
        guard visible, !showingWhatsNew, !showingJITSettings, !showingSkinSettings, !editingLibrary, !choosingCover, !busy else { return }
        controller.onCommand = { command in
            let items = filtered
            let keys = orderedPageKeys(items)
            let index = keys.firstIndex(of: selectedKey) ?? 0
            switch command {
            case .left: if index > 0 { selectedKey = keys[index - 1] }
            case .right: if index + 1 < keys.count { selectedKey = keys[index + 1] }
            case .confirm:
                if selectedKey == addGameKey { addGame() }
                else if let app = selected { activate(app) }
            case .details: audio.play(.confirm); if let app = selected { controller.stop(); manage(app) }
            case .previousSection: changeCategory(-1)
            case .nextSection: changeCategory(1)
            case .back: audio.play(.back); openInterface()
            default: break
            }
        }; controller.start()
    }
}

/// Keeps the currently displayed cover alive while a newly selected cover is
/// being decoded. A mapped image uses a neutral placeholder instead of briefly
/// falling back to the app icon, which caused the visible cover/icon flicker.
private struct LiveBoardCoverImage: View {
    @ObservedObject var store: LiveBoardArtworkStore
    let key: String
    let app: LCAppModel
    let darkMode: Bool
    var thumbnail = false
    var shelf = false
    @State private var lastReady: UIImage?

    var body: some View {
        let loaded = store.image(for: key, kind: .cover, mode: "switchboard", thumbnail: thumbnail, shelf: shelf)
        Group {
            if let image = loaded ?? lastReady {
                Image(uiImage: image).resizable().scaledToFill()
            } else if store.hasArtwork(for: key, kind: .cover, mode: "switchboard", thumbnail: thumbnail, shelf: shelf) {
                Rectangle().fill(darkMode ? Color(white: 0.10) : Color(white: 0.95))
            } else {
                LiveBoardIconImage(app: app, dark: darkMode).scaledToFit()
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: key) { _ in refresh() }
        .onChange(of: store.revision) { _ in refresh() }
    }

    private func refresh() {
        if let image = store.cachedImage(for: key, kind: .cover, mode: "switchboard", thumbnail: thumbnail, shelf: shelf) {
            lastReady = image
        } else if !store.hasArtwork(for: key, kind: .cover, mode: "switchboard", thumbnail: thumbnail, shelf: shelf) {
            // The app icon is already an available replacement when the game
            // has no custom image, so don't retain the previous game's cover.
            lastReady = nil
        }
    }
}



// Observes the SELECTED game model so changes in App Settings immediately
// update this icon, and a tap persists through LCAppInfo.orientationLock.
private struct StrataAppRotationShortcut: View {
    @ObservedObject var app: LCAppModel
    let surface: Color
    let foreground: Color

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
        Menu {
            // Only persist this selected guest's existing setting. Do not
            // request UIKit geometry or touch the library preference here.
            Button { app.uiOrientationLock = .Disabled } label: {
                if mode == .Disabled { Label("Auto", systemImage: "checkmark") } else { Text("Auto") }
            }
            Button { app.uiOrientationLock = .Portrait } label: {
                if mode == .Portrait { Label("Portrait", systemImage: "checkmark") } else { Text("Portrait") }
            }
            Button { app.uiOrientationLock = .Landscape } label: {
                if mode == .Landscape { Label("Landscape", systemImage: "checkmark") } else { Text("Landscape") }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .rotationEffect(.degrees(mode == .Landscape ? 90 : 0))
                .foregroundStyle(foreground)
                .frame(width: 50, height: 50)
                .background(Circle().fill(surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Game rotation for " + app.displayName)
        .accessibilityValue(modeName)
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


// Monochrome two-arrow phone rotation glyph, matching the header reference.
// Only the phone rotates to show the current library orientation.
private struct ZNLibraryRotateIcon: View {
    let landscape: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Path { p in
                    // Upper clockwise arrow.
                    p.move(to: CGPoint(x: 7, y: 7))
                    p.addQuadCurve(to: CGPoint(x: 28, y: 12), control: CGPoint(x: 21, y: -3))
                    p.move(to: CGPoint(x: 23, y: 9))
                    p.addLine(to: CGPoint(x: 28, y: 12))
                    p.addLine(to: CGPoint(x: 30, y: 6))
                    // Lower clockwise arrow.
                    p.move(to: CGPoint(x: 25, y: 25))
                    p.addQuadCurve(to: CGPoint(x: 4, y: 20), control: CGPoint(x: 11, y: 35))
                    p.move(to: CGPoint(x: 9, y: 23))
                    p.addLine(to: CGPoint(x: 4, y: 20))
                    p.addLine(to: CGPoint(x: 2, y: 26))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 32, height: 32)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.7)
                        .strokeBorder(lineWidth: 1.8)
                        .frame(width: 12, height: 19)
                        .overlay(alignment: .bottom) {
                            Capsule().frame(width: 4.5, height: 1.5).padding(.bottom, 3)
                        }
                }
                .rotationEffect(.degrees(landscape ? 90 : 0))
            }
            .frame(width: 32, height: 32)
            .scaleEffect(side / 32)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}
