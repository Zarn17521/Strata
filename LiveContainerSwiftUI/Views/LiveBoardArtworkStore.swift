import SwiftUI
import ImageIO
import Darwin

/// User-owned artwork stays outside executable guest bundles.
@MainActor final class LiveBoardArtworkStore: ObservableObject {
    enum Kind: String { case cover, portrait, background }
    @Published private(set) var revision = 0
    private let defaults = LCUtils.appGroupUserDefault
    private let cache = NSCache<NSString, UIImage>()
    private var requests: [String: UUID] = [:]
    private struct DecodeJob {
        let id: String
        let token: UUID
        let url: URL
        let maximum: Int
    }
    private var pendingDecodes: [DecodeJob] = []
    private var activeDecodes = 0
    private var constrained: Bool {
        let available = os_proc_available_memory()
        let thermal = ProcessInfo.processInfo.thermalState
        return defaults.bool(forKey: "ZNBetaLowMemory") || thermal == .serious || thermal == .critical || (available > 0 && available < 512 * 1024 * 1024)
    }
    private var decodeConcurrencyLimit: Int {
        let thermal = ProcessInfo.processInfo.thermalState
        return constrained || thermal == .serious || thermal == .critical || ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 2
    }
    private var missing = Set<String>()
    private var mappingCache: [String: String]?

    private var mappings: [String: String] {
        if let mappingCache { return mappingCache }
        let value = defaults.dictionary(forKey: "LiveBoardConsoleArtwork") as? [String: String] ?? [:]
        mappingCache = value; return value
    }
    private var files: LiveBoardArtworkFiles {
        LiveBoardArtworkFiles(
            directory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true),
            legacyDirectory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LiveBoard/Artwork", isDirectory: true))
    }
    // Limits describe evictable cache entries, not a guaranteed process budget.
    static let trimNotification = Notification.Name("ZNTrimLauncherPresentationCaches")
    private var decodingPaused = false
    init() {
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 16
        reloadFromDisk()
    }
    private func imageCost(_ image: UIImage) -> Int {
        if let cg = image.cgImage { return cg.bytesPerRow * cg.height }
        return Int(image.size.width * image.scale * image.size.height * image.scale * 4)
    }
    // Do not delete artwork or mappings. Drop pending tokens so completed
    // background decodes cannot refill an inactive launcher's cache.
    func trimTransientImages(pause: Bool = false) {
        if pause { decodingPaused = true }
        requests.removeAll()
        pendingDecodes.removeAll()
        cache.removeAllObjects()
        // Apply Low Memory Mode limits immediately, rather than waiting for the
        // next image lookup to update NSCache's eviction budget.
        cache.totalCostLimit = constrained ? 4 * 1024 * 1024 : 8 * 1024 * 1024
        cache.countLimit = constrained ? 4 : 8
        revision += 1
    }
    func resumeDecoding() {
        guard decodingPaused else { return }
        decodingPaused = false
        revision += 1
    }
    func reloadFromDisk() {
        mappingCache = nil
        if let migrated = try? files.migrate(mappings) {
            defaults.set(migrated, forKey: "LiveBoardConsoleArtwork"); mappingCache = migrated
        }
        writeIndex()
        cache.removeAllObjects(); requests.removeAll(); pendingDecodes.removeAll(); missing.removeAll(); revision += 1
    }
    private func writeIndex() {
        guard let data = try? JSONSerialization.data(withJSONObject: mappings, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: files.directory.appendingPathComponent("Artwork Index.json"), options: .atomic)
    }
    private func removeUnreferenced(_ filenames: [String], mappings: [String: String]) {
        let retained = Set(mappings.values)
        for filename in Set(filenames) where !retained.contains(filename) {
            if let url = files.existingURL(filename) { try? FileManager.default.removeItem(at: url) }
        }
    }
    func image(for key: String, kind: Kind, mode: String = "bigPicture") -> UIImage? {
        let id = mode + ":" + kind.rawValue + ":" + key
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard !decodingPaused, !missing.contains(id), requests[id] == nil else { return nil }
        guard let filename = mappings[id] ?? (mode == "bigPicture" ? mappings[kind.rawValue + ":" + key] : nil), let url = files.existingURL(filename) else { missing.insert(id); return nil }
        let token = UUID(); requests[id] = token
        let lowMemory = constrained
        let maximum = kind == .background ? (lowMemory ? 1280 : 1920) : (lowMemory ? 640 : 1024)
        cache.totalCostLimit = (lowMemory ? 4 : 16) * 1024 * 1024
        cache.countLimit = lowMemory ? 4 : 16
        guard pendingDecodes.count < (lowMemory ? 4 : 16) else { requests[id] = nil; return nil }
        pendingDecodes.append(DecodeJob(id: id, token: token, url: url, maximum: maximum))
        startPendingDecodes()
        return nil
    }

    // A large library must not decode every cover simultaneously. Each job
    // keeps only a URL until a slot is available, and stale queued jobs are
    // discarded before ImageIO opens a file.
    private func startPendingDecodes() {
        guard !decodingPaused else { return }
        while activeDecodes < decodeConcurrencyLimit && !pendingDecodes.isEmpty {
            let job = pendingDecodes.removeFirst()
            guard requests[job.id] == job.token else { continue }
            activeDecodes += 1
            Task { [weak self] in
                let image = await Task.detached(priority: .utility) { () -> UIImage? in
                    guard let source = CGImageSourceCreateWithURL(job.url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: job.maximum] as CFDictionary) else { return nil }
                    return UIImage(cgImage: cg)
                }.value
                guard let self else { return }
                self.activeDecodes -= 1
                if !self.decodingPaused, self.requests[job.id] == job.token {
                    self.requests[job.id] = nil
                    if let image { self.cache.setObject(image, forKey: job.id as NSString, cost: self.imageCost(image)) }
                    else { self.missing.insert(job.id) }
                    self.revision += 1
                }
                self.startPendingDecodes()
            }
        }
    }

    /// Cache-only lookup; never starts a decode. Used for same-frame fallbacks.
    func cachedImage(for key: String, kind: Kind, mode: String = "bigPicture") -> UIImage? {
        cache.object(forKey: (mode + ":" + kind.rawValue + ":" + key) as NSString)
    }
    /// True when user artwork is assigned (and not known to be unreadable), even if it is still decoding.
    /// Lets the backdrop keep the outgoing image instead of flashing the icon-derived fallback.
    func hasArtwork(for key: String, kind: Kind, mode: String = "bigPicture") -> Bool {
        let id = mode + ":" + kind.rawValue + ":" + key
        if cache.object(forKey: id as NSString) != nil { return true }
        guard !missing.contains(id) else { return false }
        return mappings[id] != nil || (mode == "bigPicture" && mappings[kind.rawValue + ":" + key] != nil)
    }
    /// Starts background decodes so neighbouring selections are ready before the user reaches them.
    func prefetch(_ keys: [String], kinds: [Kind], mode: String = "bigPicture") {
        guard !constrained else { return }
        for key in keys { for kind in kinds { _ = image(for: key, kind: kind, mode: mode) } }
    }

    func save(_ image: UIImage, for key: String, kind: Kind, mode: String = "bigPicture") throws {
        let factor = min(1, 2400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
        try files.prepare()
        let id = mode + ":" + kind.rawValue + ":" + key
        guard let folder = LiveBoardArtworkFiles.folder(mode: mode, kind: kind.rawValue) else { throw CocoaError(.fileWriteInvalidFileName) }
        let filename = folder + "/" + LiveBoardArtworkFiles.filename(key: key)
        guard let url = files.visibleURL(filename) else { throw CocoaError(.fileWriteInvalidFileName) }
        try data.write(to: url, options: .atomic)
        var map = mappings
        var previousFiles = [map[id]].compactMap { $0 }
        if mode == "bigPicture", let legacy = map.removeValue(forKey: kind.rawValue + ":" + key) { previousFiles.append(legacy) }
        map[id] = filename; mappingCache = map; defaults.set(map, forKey: "LiveBoardConsoleArtwork")
        removeUnreferenced(previousFiles, mappings: map)
        writeIndex()
        requests[id] = nil; missing.remove(id); cache.removeObject(forKey: id as NSString); revision += 1
    }
    func remove(for key: String, kind: Kind, mode: String = "bigPicture") {
        let id = mode + ":" + kind.rawValue + ":" + key
        var map = mappings
        var removed = [map.removeValue(forKey: id)].compactMap { $0 }
        if mode == "bigPicture", let legacy = map.removeValue(forKey: kind.rawValue + ":" + key) { removed.append(legacy) }
        mappingCache = map
        defaults.set(map, forKey: "LiveBoardConsoleArtwork")
        removeUnreferenced(removed, mappings: map)
        writeIndex()
        requests[id] = nil; missing.remove(id); cache.removeObject(forKey: id as NSString); revision += 1
    }
}
