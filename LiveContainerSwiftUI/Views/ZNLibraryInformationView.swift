import SwiftUI
import UIKit

enum ZNLibraryInformationPage: String, Identifiable {
    case guide, about
    var id: String { rawValue }
    var title: String { self == .guide ? "Zn Library Guide" : "About Me" }
}

private struct ZNGuideTopic: Identifiable {
    let id: String
    let title: String
    let icon: String
    let subtitle: String
    let instructions: [String]
    var note: String? = nil
}

private let znGuideTopics: [ZNGuideTopic] = [
    .init(id: "start", title: "Getting Started", icon: "house.fill",
          subtitle: "Add games and navigate your library",
          instructions: [
            "Open the Add Game card to enter Manage Apps. Import your own IPA or TIPA using the available import options.",
            "Switchboard: swipe left or right between cards. Add Game is the first page. The house in the page indicator returns to it.",
            "Use Layout to switch between Switchboard, Cinematic and Shelf. All, Recently Played and Games filter your library.",
            "The moon in the header changes the library appearance. The controller indicator at the bottom turns green when a supported controller is connected."
          ]),
    .init(id: "rotation", title: "Screen Rotation", icon: "iphone.gen3",
          subtitle: "Library and game rotation are separate",
          instructions: [
            "Tap the rotating phone in the top header to switch the Zn’s Library Home Screen between portrait and landscape. This does not change game orientation.",
            "Select a game, then tap Game Rotation in the dock. Choose Auto, Portrait or Landscape. Each game's orientation is saved independently."
          ]),
    .init(id: "skins", title: "Controller Skins", icon: "tshirt.fill",
          subtitle: "Tap to toggle; hold to customize",
          instructions: [
            "Tap Skin to enable or disable NxNative controller skins. Touch and hold Skin to open NxNative Controller Skins.",
            "Select a theme card to change its shell artwork. Pearl Light and AMOLED Dark are global button styles, independent of the theme.",
            "Classic uses the original console-style proportions. Wide gives a larger 16:9 view. Full Screen hides the shell and keeps native touch controls.",
            "Both portrait and landscape are supported. Relaunch NxNative to apply changes."
          ], note: "These skins are intended for NxNative. Other emulators may use their own controls."),
    .init(id: "engine", title: "ZN Real Controller Engine", icon: "gamecontroller.fill",
          subtitle: "Animation, haptics, mechanical sound and auto-hide",
          instructions: [
            "Hold Skin, then open ZN Real Controller Engine.",
            "Button Animation: enabled by default. Classic and Wide animate individual buttons and analog sticks.",
            "Haptic Feedback: off by default. Enable it and adjust Haptic Intensity (default 65%). Disable duplicate game haptics if needed.",
            "Mechanical Sound and Release Click: off by default. Adjust Sound Volume (default 25%) after enabling sound.",
            "Bluetooth Auto-Hide: enabled by default. A supported controller hides the touch buttons while preserving the shell and Settings gear in Classic and Wide. Disconnect to restore touch controls. Full Screen hides native touch controls.",
            "Tap the in-game Settings gear for its normal menu. Hold it to ask whether to return to the Library. Yes closes the current game; No cancels."
          ], note: "Save your progress before returning Home. Relaunch the game after changing controller settings."),
    .init(id: "hud", title: "Zn’s HUD", icon: "gauge",
          subtitle: "FPS and available process RAM",
          instructions: [
            "Tap Zn’s HUD in the dock to enable or disable the performance readout. Relaunch the game to apply.",
            "Supported Metal surfaces can report presented frames independently of the native game FPS counter. The HUD shows available process RAM next to FPS.",
            "Tap the in-game readout for FPS source, process RAM usage and thermal state."
          ], note: "Presented FPS can differ from internal emulation FPS. Unsupported renderers may show — FPS. Available RAM means process allocation headroom, not total device free memory."),
    .init(id: "jit", title: "Built-in JIT", icon: "bolt.fill",
          subtitle: "Automatic JIT launch and setup",
          instructions: [
            "Tap Built-in JIT to enable or disable automatic Launch with JIT. The bright icon means the preference is enabled; a dim icon means it is disabled.",
            "Touch and hold the icon to open JIT Setup. Select Built-in JIT (LocalDevVPN).",
            "Enable Developer Mode in iPhone Settings, keep app extensions when installing Zn’s Library and import a valid remote pairing file.",
            "Connect LocalDevVPN and Wi-Fi. Set the device IP and remote pairing port to match your working connection. Use Prepare device if needed.",
            "Launch the game. Some iOS versions or guests may require a compatible JIT script in App settings. The first launch may need a developer disk image."
          ], note: "Built-in JIT and Game Mode are independent. OFF stops automatic JIT requests, not a game's existing mandatory JIT requirement or an explicit Launch with JIT. A bright icon is not proof that the debugger has attached."),
    .init(id: "gameMode", title: "Game Mode", icon: "gamecontroller.fill",
          subtitle: "Request system Game Mode independently",
          instructions: [
            "Tap Game Mode in the dock to enable or disable automatic Game Mode requests on normal game launches.",
            "Game Mode does not turn Built-in JIT on. You can also request either mode explicitly in Game Options.",
            "Use iOS Control Center while Zn is active to check the actual system Game Mode state."
          ], note: "iOS decides whether Game Mode activates. It does not raise the app’s RAM limit."),
    .init(id: "options", title: "Game Options", icon: "ellipsis.circle",
          subtitle: "Hold a game card for advanced actions",
          instructions: [
            "Touch and hold a game cover, then select Options….",
            "Launch default shortcut: use the saved launch profile. Shortcut Profiles…: configure launch shortcuts.",
            "Launch with JIT: request JIT. Multitask: open using the supported multitask path.",
            "Request Game Mode and Request Game Mode + JIT: explicitly request the selected launch mode.",
            "App settings: manage the individual guest’s configuration. Choose cover artwork: import a local image. Search cover on SteamGridDB: find online covers.",
            "Use the available organization actions to manage the library or Hide an item."
          ], note: "Available options depend on the selected app and supported launch methods."),
    .init(id: "art", title: "SteamGridDB", icon: "photo",
          subtitle: "Find and customize game cover artwork",
          instructions: [
            "Obtain your personal API key from SteamGridDB.",
            "Open Zn Settings → SteamGridDB, enter the API key and tap Save API key.",
            "Hold a game card → Options… → Search cover on SteamGridDB. Search for its title, select the matching game and choose artwork.",
            "The API key is stored in this app’s Keychain and sent to SteamGridDB when searching."
          ]),
    .init(id: "emu", title: "Emulator Setup", icon: "cpu",
          subtitle: "Helper Processes Support and compatibility",
          instructions: [
            "For compatible emulators that rely on helper processes, hold their game card → Options… → App settings.",
            "Enable Helper Processes Support if the emulator requires it, then relaunch. The option is unavailable for 32-bit guests.",
            "Enable or configure JIT only when required by that emulator. If it fails, check the pairing file, VPN connection and guest compatibility."
          ], note: "Helper Processes Support is recommended for emulators that need it (for example, compatible MeloNX or MeloCafe builds). It does not guarantee extra RAM or bypass iOS memory limits. Not every launch mode uses the helper-process hooks."),
    .init(id: "boot", title: "Boot Intro & Loading", icon: "play.rectangle",
          subtitle: "Startup animation and shader progress",
          instructions: [
            "A supported game shows the Zn’s Library startup intro on its cold launch, once per guest process.",
            "If supported native shader or pipeline progress is detected, the logo remains visible while loading. The intro and sound do not repeat.",
            "Unsupported loading indicators are not replaced with invented progress. The intro dismisses normally."
          ]),
    .init(id: "help", title: "Troubleshooting", icon: "wrench.and.screwdriver",
          subtitle: "JIT, performance and controller tips",
          instructions: [
            "JIT failed: check Developer Mode, pairing, LocalDevVPN, Wi-Fi and the guest’s JIT script requirements.",
            "Low memory or crashes: reduce in-game rendering settings and close other apps when appropriate. HUD memory is not a guarantee against jetsam.",
            "Touch controls missing: check Bluetooth Auto-Hide and disconnect a connected controller if you want touch controls.",
            "After changing skin, HUD or launch settings, relaunch the guest. For feedback, use the email in About Me."
          ])
]

struct ZNLibraryInformationView: View {
    let page: ZNLibraryInformationPage
    let darkMode: Bool
    @Environment(\.dismiss) private var dismiss
    private var foreground: Color { darkMode ? .white : .black }
    private var surface: Color { Color(white: darkMode ? 0.12 : 0.95) }

    var body: some View {
        NavigationView {
            Group {
                if page == .guide { guide }
                else { about }
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(foreground)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(darkMode ? .dark : .light)
    }

    private var guide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Text("Zn’s Library").font(.system(size: 32, weight: .heavy, design: .rounded))
                    Text("Welcome to Zn’s Library").font(.headline)
                    Text("Your games. Your controls. Your experience.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                VStack(spacing: 0) {
                    ForEach(znGuideTopics) { topic in
                        NavigationLink(destination: ZNGuideDetail(topic: topic, darkMode: darkMode)) {
                            HStack(spacing: 12) {
                                Image(systemName: topic.icon)
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 42, height: 42)
                                    .background(foreground.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topic.title).font(.headline)
                                    Text(topic.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if topic.id != znGuideTopics.last?.id { Divider().padding(.leading, 66) }
                    }
                }
                .background(surface, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(16)
        }
        .foregroundStyle(foreground)
        .background((darkMode ? Color.black : Color.white).ignoresSafeArea())
    }

    private var about: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 8) {
                    Group {
                        if let profile = UIImage(named: "AboutMeProfile") {
                            Image(uiImage: profile)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 136, height: 136)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .strokeBorder(foreground.opacity(0.16), lineWidth: 1)
                                }
                                .accessibilityLabel("Developer and daughter")
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 78, weight: .regular))
                                .foregroundStyle(foreground)
                                .frame(width: 136, height: 136)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.bottom, 6)
                    Text("Pyae Sone Phyo").font(.title2.bold())
                    Text("Min Pyae Zn").font(.subheadline).foregroundStyle(.secondary)
                    Text("Developer of Zn’s Library").font(.caption).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                Divider()
                Text("My name is Pyae Sone Phyo, but most people know me as Min Pyae Zn.")
                Text("Zn’s Library is my very first fork project, created at the age of 23 with the help of ChatGPT AI.")
                Text("This project is especially meaningful to me because I created it as a gift for my beloved daughter on her 6th birthday. ❤️")
                Text("As this is my first project, there may be some bugs and errors. I kindly ask for your patience and understanding.")
                Text("If you have any suggestions, feedback, or ideas for improvement, please feel free to contact me.")
                if let email = URL(string: "mailto:Minpyaezn17521@gmail.com") {
                    Link(destination: email) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Contact Me").font(.headline)
                                Text("Minpyaezn17521@gmail.com").font(.footnote)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption)
                        }
                        .padding(14)
                        .background(surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(foreground)
                }
                Divider()
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill").font(.title2).foregroundStyle(Color.red)
                    Text("Made with love, dedicated to my daughter.").italic()
                        .multilineTextAlignment(.center)
                    Text("Zn’s Library").font(.title2.weight(.heavy)).foregroundStyle(Color.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .font(.body)
            .padding(20)
        }
        .foregroundStyle(foreground)
        .background((darkMode ? Color.black : Color.white).ignoresSafeArea())
    }
}

private struct ZNGuideDetail: View {
    let topic: ZNGuideTopic
    let darkMode: Bool
    private var foreground: Color { darkMode ? .white : .black }
    private var surface: Color { Color(white: darkMode ? 0.12 : 0.95) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: topic.icon).font(.system(size: 38, weight: .semibold))
                    Text(topic.subtitle).font(.headline).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
                illustration
                ForEach(Array(topic.instructions.enumerated()), id: \.offset) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(entry.offset + 1))
                            .font(.caption.bold().monospacedDigit())
                            .frame(width: 26, height: 26)
                            .background(surface, in: Circle())
                        Text(entry.element).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let note = topic.note {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                        Text(note).font(.footnote)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(surface, in: RoundedRectangle(cornerRadius: 12))
                }
                if topic.id == "art", let url = URL(string: "https://www.steamgriddb.com/") {
                    Link("Open SteamGridDB", destination: url).font(.headline)
                }
            }
            .padding(18)
        }
        .foregroundStyle(foreground)
        .background((darkMode ? Color.black : Color.white).ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var illustration: some View {
        switch topic.id {
        case "rotation":
            HStack(spacing: 12) {
                example("arrow.triangle.2.circlepath", "Header", "Library Rotation")
                example("iphone.gen3", "Dock", "Game Rotation")
            }
        case "skins":
            HStack(spacing: 12) {
                example("tshirt.fill", "Tap", "Enable / Disable")
                example("hand.tap", "Hold", "Skin Settings")
            }
            HStack(spacing: 12) {
                controllerExample(dark: false, hidden: false, label: "Pearl Light")
                controllerExample(dark: true, hidden: false, label: "AMOLED Dark")
            }
        case "engine":
            VStack(spacing: 10) {
                controllerExample(dark: false, hidden: false, label: "Touch Controls Visible")
                controllerExample(dark: false, hidden: true, label: "Bluetooth Auto-Hide")
            }
        case "hud":
            VStack(spacing: 8) {
                Text("30 FPS · 2.09 GiB Avail").font(.system(.headline, design: .monospaced))
                    .padding(12).foregroundStyle(Color.white)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                Text("Example performance readout").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(12).background(surface, in: RoundedRectangle(cornerRadius: 12))
        case "jit", "gameMode":
            HStack(spacing: 12) {
                example(topic.icon, "Enabled", "Bright icon")
                example(topic.id == "jit" ? "bolt.slash" : "gamecontroller", "Disabled", "Dim icon", dim: true)
            }
        case "emu":
            HStack {
                Text("Helper Processes Support").font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "switch.2").font(.title2).foregroundStyle(.green)
            }.padding(14).background(surface, in: RoundedRectangle(cornerRadius: 12))
            Text("Example: enable in App settings when required.").font(.caption).foregroundStyle(.secondary)
        case "options":
            VStack(alignment: .leading, spacing: 10) {
                Label("Options…", systemImage: "ellipsis.circle").font(.headline)
                Divider()
                Label("App settings", systemImage: "gearshape")
                Label("Search cover on SteamGridDB", systemImage: "sparkles")
            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(surface, in: RoundedRectangle(cornerRadius: 12))
        default:
            EmptyView()
        }
    }

    private func example(_ icon: String, _ title: String, _ caption: String, dim: Bool = false) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.title.weight(.semibold))
                .foregroundStyle(foreground.opacity(dim ? 0.4 : 1))
            Text(title).font(.subheadline.bold())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func controllerExample(dark: Bool, hidden: Bool, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                VStack(spacing: 7) {
                    if !hidden {
                        Image(systemName: "plus")
                        Image(systemName: "circle.circle.fill")
                    }
                }
                .frame(width: 32, height: 74)
                .background(Color.cyan)
                VStack(spacing: 4) {
                    Rectangle().fill(Color.black).frame(height: 55)
                    Image(systemName: "gearshape.fill").font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 74)
                .background(Color(white: dark ? 0.12 : 0.76))
                VStack(spacing: 7) {
                    if !hidden {
                        Image(systemName: "circle.circle.fill")
                        Image(systemName: "circle.grid.cross.fill")
                    }
                }
                .frame(width: 32, height: 74)
                .background(Color.red)
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(dark ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(surface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
