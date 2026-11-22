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
    var launchWithMetalHUD: ((LCAppModel) -> Void)? = nil
    @StateObject private var controller = LiveBoardControllerInput()
    @StateObject private var artwork = LiveBoardArtworkStore()
    @ObservedObject private var customization = LiveBoardAppCustomization.shared
    @AppStorage("LiveBoardModeLibraries", store: LCUtils.appGroupUserDefault) private var savedLibrary = "{}"
    @State private var selectedKey = ""
    @State private var category: String?
    @State private var editingLibrary = false
    @State private var newCategory = ""
    @State private var visible = false
    @State private var busy = false
    @State private var choosingCover = false
    @State private var coverKey = ""
    @State private var artworkError: String?
    @Environment(\.scenePhase) private var phase
    private var libraries: [String: LiveBoardModeLibrary] { LiveBoardLibraryCache.decode(savedLibrary) }
    @AppStorage(LiveBoardSharedCategories.enabledKey, store: LCUtils.appGroupUserDefault) private var universalCategories = true
    @AppStorage("LiveBoardConsoleSounds", store: LCUtils.appGroupUserDefault) private var sounds = true
    @AppStorage("StrataSwitchboardAMOLEDDark", store: LCUtils.appGroupUserDefault) private var darkMode = false
    @AppStorage("StrataNxSkinEnabled", store: LCUtils.appGroupUserDefault) private var skinEnabled = false
    @AppStorage("StrataSwitchboardLandscape", store: LCUtils.appGroupUserDefault) private var landscapeMode = false
    private var foreground: Color { darkMode ? .white : .black }
    private var background: Color { darkMode ? .black : .white }
    private var buttonSurface: Color { darkMode ? Color(white: 0.13) : Color(white: 0.92) }
    private var tilePlaceholder: Color { darkMode ? Color(white: 0.10) : Color(white: 0.95) }
    @StateObject private var audio = LiveBoardNavigationAudio()
    private var library: LiveBoardModeLibrary { _ = universalCategories; return LiveBoardSharedCategories.library(libraries, mode: "switchboard") }
    private var filtered: [LCAppModel] { let state = library; return apps.filter { !state.hidden.contains(liveBoardAppKey($0)) && (category == nil || state.assignments[liveBoardAppKey($0)] == category) } }
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
                    categoryStrip.padding(.horizontal, margin).padding(.top, 4)
                    Spacer(minLength: 4)
                    TabView(selection: $selectedKey) {
                        ForEach(items, id: \.self) { app in
                            gameTile(app, size: tile)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .tag(liveBoardAppKey(app))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: tile + 70)
                    .accessibilityIdentifier("switchboard.pages")
                    .onChange(of: selectedKey) { _ in
                        if sounds && phase == .active { audio.play() }
                    }
                    if filtered.isEmpty { Text("No apps here. Add apps or change this category.").foregroundStyle(.secondary).padding(.horizontal, margin) }
                    Spacer(minLength: 4)
                    shortcutButtons.frame(maxWidth: .infinity).padding(.top, 12)
                    Spacer(minLength: 4)
                    Divider().overlay(foreground.opacity(0.15))
                    HStack {
                        Image(systemName: "gamecontroller.fill").foregroundStyle(.secondary)
                        Spacer()
                        if controller.connected {
                            HStack(spacing: 18) { Label("Options", systemImage: controller.detailsSymbol); Label("Open", systemImage: controller.confirmSymbol) }
                        }
                    }.font(.subheadline).padding(.horizontal, margin).padding(.vertical, 10)
                }
            }
        }.foregroundStyle(foreground)
        .preferredColorScheme(darkMode ? .dark : .light)
        .background(LiveBoardOrientationLock(mask: landscapeMode ? .landscape : .portrait))
        .onAppear { visible = true; selectedKey = filtered.first.map(liveBoardAppKey) ?? ""; bind() }
        .onDisappear { visible = false; controller.stop(); audio.stop() }
        .onChange(of: phase) { value in if value == .active { busy = false; bind() } else { controller.stop() } }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.pauseNotification)) { _ in controller.stop() }
        .onReceive(NotificationCenter.default.publisher(for: LiveBoardControllerInput.resumeNotification)) { _ in busy = false; bind() }
        .sheet(isPresented: $choosingCover, onDismiss: bind) {
            LiveBoardWallpaperPicker { image in
                if let image { do { try artwork.save(image, for: coverKey, kind: .cover, mode: "switchboard") } catch { artworkError = error.localizedDescription } }
                choosingCover = false
            }
        }
        .alert("Artwork", isPresented: Binding(get: { artworkError != nil }, set: { if !$0 { artworkError = nil } })) { Button("OK") { artworkError = nil } } message: { Text(artworkError ?? "") }
        .onChange(of: filtered.map(liveBoardAppKey)) { keys in if !keys.contains(selectedKey) { selectedKey = keys.first ?? "" } }
        .sheet(isPresented: $editingLibrary, onDismiss: bind) {
            NavigationView {
                Form {
                    Section("Categories") {
                        HStack { TextField("New category", text: $newCategory); Button("Add") { update { _ = $0.addCategory(newCategory) }; newCategory = "" } }
                        ForEach(library.categories, id: \.self) { value in HStack { Text(value); Spacer(); Button("Remove") { update { $0.removeCategory(value) }; if category == value { category = nil } } } }
                    }
                    Section { Toggle("Same categories in every interface", isOn: Binding(get: { universalCategories }, set: { LiveBoardSharedCategories.setEnabled($0); universalCategories = $0 })); Toggle("Navigation sounds", isOn: $sounds) }
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
    private func gameTile(_ app: LCAppModel, size tile: CGFloat) -> some View {
        let key = liveBoardAppKey(app)
        let isSelected = key == liveBoardAppKey(selected ?? app)
        let radius = tile * 0.035
        return Button {
                                        if selectedKey == key { activate(app) } else { selectedKey = key }
                                    } label: {
                                        VStack(spacing: 8) {
                                            // Name sits above the selected tile only; space is reserved so the row never jumps.
                                            Text(customization.name(app)).font(.system(size: max(15, tile * 0.075), weight: .medium))
                                                .foregroundStyle(foreground).lineLimit(1)
                                                .minimumScaleFactor(0.6).frame(width: tile + 10).opacity(isSelected ? 1 : 0)
                                            ZStack {
                                                tilePlaceholder
                                                if let cover = artwork.image(for: key, kind: .cover, mode: "switchboard") {
                                                    Image(uiImage: cover).resizable().scaledToFill()
                                                } else { LiveBoardIconImage(app: app, dark: darkMode).scaledToFit() }
                                            }
                                            .frame(width: tile, height: tile)
                                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                                            .padding(5)
                                            .overlay(RoundedRectangle(cornerRadius: radius + 5, style: .continuous)
                                                .strokeBorder(foreground, lineWidth: isSelected ? 3 : 0))
                                            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                                        }.frame(width: tile + 10)
                                    }.buttonStyle(.plain).id(key)
                                    // Drag-to-reorder omitted to keep swipe navigation responsive.
                                    .accessibilityLabel(customization.name(app))
                                    .accessibilityIdentifier("switchboard.tile." + key)
                                    .contextMenu {
                                        Button("Launch", systemImage: "play.fill") { activate(app) }
                                        if !(app.appInfo is StrataPhoneAppInfo) && !(app.appInfo is BuiltInSideStoreAppInfo) {
                                            if let launchWithJIT { Button("Launch with JIT", systemImage: "bolt.fill") { controller.stop(); launchWithJIT(app) } }
                                            if let launchMultitask { Button("Multitask", systemImage: "rectangle.on.rectangle") { controller.stop(); launchMultitask(app) } }
                                            if let launchInGameMode { Button("Request Game Mode", systemImage: "gamecontroller.fill") { controller.stop(); launchInGameMode(app) } }
                                            if let launchWithMetalHUD { Button("Launch with Metal HUD", systemImage: "gauge.with.dots.needle.67percent") { controller.stop(); launchWithMetalHUD(app) } }
                                        }
                                        Button("App settings", systemImage: "gearshape") { controller.stop(); manage(app) }
                                        Button("Choose cover artwork", systemImage: "photo") { coverKey = key; choosingCover = true; controller.stop() }
                                        StrataArrangeMenus(app: app, visible: filtered, all: apps, categories: library.categories, current: library.assignments[key]) { value in update { $0.assignments[key] = value } }
                                        Button("Hide", systemImage: "eye.slash") { update { _ = $0.hidden.insert(key) } }
                                    }
    }

    // The system status bar already displays time, Wi-Fi and battery.
    // Keep only Strata's wordmark to avoid a duplicated status bar.
    private var statusBar: some View {
        Text("STRATA")
            .font(.headline.weight(.semibold))
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                Button("All") { category = nil }.opacity(category == nil ? 1 : 0.55)
                ForEach(library.visibleCategories(apps), id: \.self) { value in Button(value) { category = value }.opacity(category == value ? 1 : 0.55) }
            }.font(.subheadline.weight(.semibold)).buttonStyle(.plain)
        }
    }
    private var shortcutButtons: some View {
        // Three equal-sized, icon-only toggles under the single selected cover.
        // Long-press the first two buttons for the previous management shortcuts.
        HStack(spacing: 20) {
            roundButton("tshirt.fill",
                        label: skinEnabled ? "Disable NxNative skin" : "Enable NxNative skin",
                        tint: skinEnabled ? .purple : .gray) {
                skinEnabled.toggle()
            }
            .accessibilityIdentifier("switchboard.toggle.skin")
            .contextMenu {
                Button("Manage apps", systemImage: "square.grid.2x2.fill") {
                    controller.stop(); openManagement()
                }
            }
            roundButton(landscapeMode ? "iphone" : "iphone.landscape",
                        label: landscapeMode ? "Switch to portrait" : "Switch to landscape",
                        tint: .orange) {
                landscapeMode.toggle()
            }
            .accessibilityIdentifier("switchboard.toggle.orientation")
            .contextMenu {
                Button("Interface settings", systemImage: "slider.horizontal.3") {
                    controller.stop(); openInterface()
                }
            }
            roundButton(darkMode ? "moon.fill" : "moon",
                        label: darkMode ? "Disable AMOLED dark mode" : "Enable AMOLED dark mode",
                        tint: .cyan) {
                darkMode.toggle()
            }
            .accessibilityIdentifier("switchboard.toggle.darkMode")
        }.buttonStyle(.plain)
    }
    private func roundButton(_ symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(Circle().fill(buttonSurface))
        }.accessibilityLabel(label)
    }

    private func activate(_ app: LCAppModel) {
        guard !busy else { return }; busy = true; controller.stop(); launch(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { busy = false }
    }
    private func bind() {
        guard visible, !editingLibrary, !choosingCover, !busy else { return }
        controller.onCommand = { command in
            let items = filtered
            let index = items.firstIndex { liveBoardAppKey($0) == selectedKey } ?? 0
            switch command {
            case .left: if index > 0 { selectedKey = liveBoardAppKey(items[index - 1]) }
            case .right: if index + 1 < items.count { selectedKey = liveBoardAppKey(items[index + 1]) }
            case .confirm: if let app = selected { activate(app) }
            case .details: if let app = selected { controller.stop(); manage(app) }
            case .back: openInterface()
            default: break
            }
        }; controller.start()
    }
}
