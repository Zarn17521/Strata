import SwiftUI
import Security
import ImageIO

private struct StrataSGDBGame: Decodable, Identifiable {
    let id: Int
    let name: String
}
private struct StrataSGDBAsset: Decodable, Identifiable {
    let id: Int
    let url: URL
    let thumb: URL?
    let width: Int?
    let height: Int?
    var title: String { "\(width ?? 0) × \(height ?? 0)" }
}
private struct StrataSGDBEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: [T]
}
struct StrataArtworkOnlineRequest: Identifiable {
    let key: String
    let title: String
    let kind: LiveBoardArtworkStore.Kind
    let mode: String
    var id: String { key + kind.rawValue + mode }
}

/// Stores the user supplied token in Keychain and speaks only to SteamGridDB's v2 API.
enum StrataSteamGridDB {
    private static let service = "ZN.Strata.SteamGridDB"
    private static let account = "api-key"
    static func apiKey() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
        return value
    }
    static func setAPIKey(_ value: String) throws {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        guard !clean.isEmpty else { SecItemDelete(query as CFDictionary); return }
        let data = Data(clean.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        } else if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    private static func request<T: Decodable>(_ path: String, key: String, type: T.Type) async throws -> [T] {
        guard let url = URL(string: "https://www.steamgriddb.com/api/v2/" + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 1_000_000 else { throw URLError(.badServerResponse) }
        let envelope = try JSONDecoder().decode(StrataSGDBEnvelope<T>.self, from: data)
        guard envelope.success else { throw URLError(.cannotParseResponse) }
        return Array(envelope.data.prefix(20))
    }
    fileprivate static func search(_ title: String, key: String) async throws -> [StrataSGDBGame] {
        guard let term = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) else { throw URLError(.badURL) }
        return try await request("search/autocomplete/\(term)", key: key, type: StrataSGDBGame.self)
    }
    fileprivate static func assets(gameID: Int, background: Bool, key: String) async throws -> [StrataSGDBAsset] {
        let endpoint = background ? "heroes" : "grids"
        return try await request("\(endpoint)/game/\(gameID)", key: key, type: StrataSGDBAsset.self)
    }
    fileprivate static func download(_ asset: StrataSGDBAsset) async throws -> UIImage {
        var request = URLRequest(url: asset.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (file, response) = try await URLSession.shared.download(for: request)
        defer { try? FileManager.default.removeItem(at: file) }
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? Int.max
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), size <= 12 * 1024 * 1024,
              let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: 1600] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
        return UIImage(cgImage: image)
    }
}

struct StrataSteamGridDBKeySettings: View {
    @State private var key = StrataSteamGridDB.apiKey() ?? ""
    @State private var saved = false
    @State private var error: String?
    var body: some View {
        Form {
            Section("API key") {
                SecureField("SteamGridDB API key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save API key") { do { try StrataSteamGridDB.setAPIKey(key); saved = true } catch { self.error = error.localizedDescription } }
                Button("Remove API key", role: .destructive) { do { try StrataSteamGridDB.setAPIKey(""); key = ""; saved = false } catch { error = error.localizedDescription } }.disabled(key.isEmpty)
            }
            Section { Text("The key is stored in this app’s Keychain and is sent only to SteamGridDB when you search or download artwork. It is not saved in shared preferences or exported with a skin.").font(.footnote).foregroundStyle(.secondary) }
            if saved { Section { Label("Saved securely", systemImage: "checkmark.shield.fill").foregroundStyle(.green) } }
        }
        .navigationTitle("SteamGridDB")
        .alert("SteamGridDB", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct StrataSteamGridDBArtworkSearch: View {
    let title: String
    let background: Bool
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var games: [StrataSGDBGame] = []
    @State private var assets: [StrataSGDBAsset] = []
    @State private var selectedGame: StrataSGDBGame?
    @State private var selectedAsset: Int?
    @State private var automatic = true
    @State private var busy = false
    @State private var error: String?
    init(title: String, background: Bool, onSelect: @escaping (UIImage) -> Void) { self.title = title; self.background = background; self.onSelect = onSelect; _query = State(initialValue: title) }
    var body: some View {
        NavigationView {
            Form {
                Section("Find a game") {
                    TextField("Game title", text: $query).textInputAutocapitalization(.words)
                    Button(busy ? "Searching…" : "Search SteamGridDB") { Task { await search() } }.disabled(busy || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || StrataSteamGridDB.apiKey() == nil)
                    Toggle("Select the first artwork automatically", isOn: $automatic)
                    if StrataSteamGridDB.apiKey() == nil { Text("Add an API key in Settings → SteamGridDB first.").font(.footnote).foregroundStyle(.secondary) }
                }
                if !games.isEmpty { Section("Matching games") { ForEach(games) { game in Button { Task { await load(game) } } label: { HStack { Text(game.name); Spacer(); if selectedGame?.id == game.id { Image(systemName: "checkmark") } } } } } }
                if !assets.isEmpty { Section(background ? "Background artwork" : "Cover artwork") {
                    ForEach(assets) { asset in Button { selectedAsset = asset.id } label: { HStack { VStack(alignment: .leading) { Text("Artwork #\(asset.id)"); Text(asset.title).font(.caption).foregroundStyle(.secondary) }; Spacer(); if selectedAsset == asset.id { Image(systemName: "checkmark.circle.fill") } } } }
                    Button(busy ? "Downloading…" : "Use Selected Artwork") { Task { await useSelected() } }.disabled(busy || selectedAsset == nil)
                } }
            }
            .navigationTitle("SteamGridDB Artwork")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .overlay { if busy { ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .alert("SteamGridDB", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }.navigationViewStyle(.stack)
    }
    @MainActor private func search() async {
        guard let key = StrataSteamGridDB.apiKey() else { return }
        busy = true; defer { busy = false }
        do { games = try await StrataSteamGridDB.search(query, key: key); assets = []; selectedGame = nil; selectedAsset = nil }
        catch { self.error = error.localizedDescription }
    }
    @MainActor private func load(_ game: StrataSGDBGame) async {
        guard let key = StrataSteamGridDB.apiKey() else { return }
        busy = true; defer { busy = false }
        do { selectedGame = game; assets = try await StrataSteamGridDB.assets(gameID: game.id, background: background, key: key); selectedAsset = automatic ? assets.first?.id : nil }
        catch { self.error = error.localizedDescription }
    }
    @MainActor private func useSelected() async {
        guard let id = selectedAsset, let asset = assets.first(where: { $0.id == id }) else { return }
        busy = true; defer { busy = false }
        do { let image = try await StrataSteamGridDB.download(asset); onSelect(image); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
