import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Appearance-only configuration for the existing NxNative touch controller.
// The guest reads these files through its current LiveContainer data container.
// No guest executable, game profile, save, JIT or memory entitlement is altered.
struct StrataControllerSkinsView: View {
    let apps: [LCAppModel]

    private var nxNativeApps: [LCAppModel] {
        apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            app.bundleIdentifier.lowercased().hasPrefix("org.nxnative")
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                ForEach(nxNativeApps, id: \.self) { app in
                    NavigationLink {
                        StrataControllerSkinGameView(app: app)
                    } label: {
                        HStack(spacing: 12) {
                            Image(uiImage: app.appInfo.iconIsDarkIcon(false) ?? UIImage())
                                .resizable().scaledToFit()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.displayName).lineLimit(2)
                                Text(app.bundleIdentifier).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if nxNativeApps.isEmpty {
                    Text("Install a NxNative IPA in Strata to configure its controller appearance.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("NxNative games")
            } footer: {
                Text("Choose a skin for each game's data container. A new Strata build with the skin hook is required; existing NxNative game IPAs need not be rebuilt.")
            }
        }
        .navigationTitle("Controller Skins")
    }
}

private struct StrataControllerSkinGameView: View {
    @ObservedObject var app: LCAppModel
    @State private var containerIndex = 0
    @State private var style = "original"
    @State private var opacity = 0.70
    @State private var importing = false
    @State private var message: String?
    @State private var importedImage: UIImage?

    private struct SkinPreset: Identifiable {
        let id: String
        let title: String
    }
    private let styles: [SkinPreset] = [
        .init(id: "original", title: "Original NxNative"),
        .init(id: "classic", title: "Classic Dark"),
        .init(id: "neon", title: "Neon Purple"),
        .init(id: "clear", title: "Minimal Transparent"),
        .init(id: "image", title: "Custom Image")
    ]

    private var container: LCContainer? {
        guard app.uiContainers.indices.contains(containerIndex) else { return nil }
        return app.uiContainers[containerIndex]
    }
    private var documents: URL? {
        container?.containerURL.appendingPathComponent("Documents", isDirectory: true)
    }
    private var settingsURL: URL? { documents?.appendingPathComponent("StrataControllerSkin.json") }
    private var imageURL: URL? { documents?.appendingPathComponent("StrataControllerSkin.png") }

    var body: some View {
        Form {
            Section("Game") {
                LabeledContent("App", value: app.displayName)
                if app.uiContainers.isEmpty {
                    Text("Launch this game once to create a data container.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Data container", selection: $containerIndex) {
                        ForEach(app.uiContainers.indices, id: \.self) { index in
                            Text(app.uiContainers[index].name).tag(index)
                        }
                    }
                }
            }
            Section("Controller appearance") {
                Picker("Skin", selection: $style) {
                    ForEach(styles, id: \.id) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .disabled(container == nil)
                if style != "original" {
                    HStack {
                        Text("Opacity")
                        Slider(value: $opacity, in: 0.25...1.0, step: 0.05)
                        Text("\(Int(opacity * 100))%").monospacedDigit()
                    }
                    .disabled(container == nil)
                }
                if style == "image" {
                    if let image = importedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                    Button("Import PNG or JPG", systemImage: "photo.badge.plus") { importing = true }
                        .disabled(container == nil)
                    if importedImage == nil {
                        Text("Choose a transparent PNG skin image. Native touch targets remain in their original positions.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Restore original controller", systemImage: "arrow.uturn.backward") {
                    style = "original"
                    save()
                }
                .disabled(container == nil)
            } footer: {
                Text("Only the appearance of the on-screen controller changes. The existing NxNative 2D/3D buttons and touch hit positions remain unchanged. Images designed for another emulator may not align with those positions.")
            }
        }
        .navigationTitle("Controller Skin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: containerIndex) { _ in load() }
        .onChange(of: style) { _ in save() }
        .onChange(of: opacity) { _ in save() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg, .image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 12 * 1024 * 1024, let image = UIImage(data: data),
                      image.size.width <= 4096, image.size.height <= 4096,
                      let png = image.pngData(), png.count <= 20 * 1024 * 1024
                else { throw NSError(domain: "StrataSkin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose a valid image no larger than 4096 pixels and 12 MB."]) }
                guard let documents, let imageURL else { return }
                try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                try png.write(to: imageURL, options: .atomic)
                importedImage = image
                style = "image"
                save()
            } catch { message = error.localizedDescription }
        }
        .alert("Controller Skins", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func load() {
        importedImage = imageURL.flatMap { UIImage(contentsOfFile: $0.path) }
        guard let settingsURL,
              let data = try? Data(contentsOf: settingsURL),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { style = "original"; opacity = 0.70; return }
        let storedStyle = dict["style"] as? String ?? "original"
        style = styles.contains(where: { $0.id == storedStyle }) ? storedStyle : "original"
        opacity = min(1, max(0.25, dict["opacity"] as? Double ?? 0.70))
    }

    private func save() {
        guard let documents, let settingsURL else { return }
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: [
                "version": 1, "style": style, "opacity": opacity
            ], options: [.sortedKeys])
            try data.write(to: settingsURL, options: .atomic)
        } catch { message = error.localizedDescription }
    }
}
