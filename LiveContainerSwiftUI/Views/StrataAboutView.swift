import SwiftUI

struct StrataAboutView: View {
    private let repository = URL(string: "https://github.com/Zarn17521/Strata")!
    private let upstream = URL(string: "https://github.com/huzaifahshahid71-ops/Strata")!
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    if let icon = UIImage(contentsOfFile: Bundle.main.bundleURL.appendingPathComponent("AppIcon60x60@2x.png").path) {
                        Image(uiImage: icon).resizable().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    Text("ZN").font(.largeTitle.bold())
                    Text("Version " + StrataVersion.display + (StrataVersion.channel.map { " · " + $0 } ?? "")).font(.subheadline).foregroundStyle(.secondary)
                    Text("Your games. Your library.").font(.subheadline).foregroundStyle(.secondary)
                    Text("Independent community fork of Strata / LiveContainer").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            Section("ZN Project") {
                Link(destination: URL(string: "https://github.com/Zarn17521")!) { Label("Zarn17521 · Fork maintainer", systemImage: "person.crop.circle") }
                Link(destination: repository) { Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right") }.accessibilityIdentifier("strata.about.repository")
                Link(destination: repository.appendingPathComponent("releases")) { Label("Releases & updates", systemImage: "arrow.down.circle") }
                Link(destination: repository.appendingPathComponent("issues")) { Label("Report an issue", systemImage: "ladybug") }
            }
            Section("Original authors & upstream") {
                Link(destination: upstream) { Label("Strata · huzaifahshahid71-ops", systemImage: "arrow.triangle.branch") }
                Link("Original creator", destination: URL(string: "https://github.com/huzaifahshahid71-ops")!).accessibilityIdentifier("strata.about.profile")
                Link("LiveContainer", destination: URL(string: "https://github.com/LiveContainer/LiveContainer")!)
                Link("SideStore", destination: URL(string: "https://github.com/SideStore/SideStore")!)
                Link("StikJIT", destination: URL(string: "https://github.com/StikDebug/StikJIT")!)
                Link("LiveExec32", destination: URL(string: "https://github.com/LiveContainer/LiveExec32")!)
                Link("StosSign", destination: URL(string: "https://github.com/stossy11/StosSign")!)
                Link("MetalFG", destination: URL(string: "https://github.com/dnullptr/MetalFG")!)
                Link("ryC0", destination: URL(string: "https://github.com/Sami-Wali/ryC0")!)
            }
            Section {
                Link(destination: repository.appendingPathComponent("blob/main/LICENSE")) { Label("GNU AGPL v3 · Project license", systemImage: "doc.text") }
                Link(destination: repository.appendingPathComponent("blob/main/THIRD_PARTY_NOTICES.md")) { Label("Third-party licenses & notices", systemImage: "books.vertical") }
                Link(destination: repository.appendingPathComponent("tree/main/Vendor/DependencyNotices")) { Label("Dependency notices", systemImage: "doc.on.doc") }
            } header: {
                Text("Open Source & Licenses")
            } footer: {
                Text("Original authorship, copyright and third-party license terms remain in effect. ZN is not affiliated with or endorsed by upstream projects, Apple or Nintendo.")
            }
        }.navigationTitle("About ZN").navigationBarTitleDisplayMode(.inline)
    }
}

struct StrataCreditsButton: View {
    var location = "strata.about.button"
    @State private var showingAbout = false
    var body: some View {
        Button { showingAbout = true } label: {
            Label("About ZN & GitHub", systemImage: "info.circle").frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier(location)
        .sheet(isPresented: $showingAbout) {
            NavigationView {
                StrataAboutView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingAbout = false } } }
            }.navigationViewStyle(.stack)
        }
    }
}
