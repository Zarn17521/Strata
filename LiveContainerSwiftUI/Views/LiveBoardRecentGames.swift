import Foundation

/// Small, bounded launch history shared by all library layouts.
/// A game is recorded only after the existing launch path returns successfully.
enum LiveBoardRecentGames {
    private static let key = "LiveBoardRecentlyPlayed"
    private static let limit = 200
    private static var defaults: UserDefaults { LCUtils.appGroupUserDefault }
    static let changed = Notification.Name("StrataRecentlyPlayedChanged")

    static func timestamps() -> [String: TimeInterval] {
        defaults.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
    }

    static func record(_ app: LCAppModel, at date: Date = Date()) {
        guard !(app.appInfo is StrataPhoneAppInfo),
              !(app.appInfo is BuiltInSideStoreAppInfo),
              !(app.appInfo is StrataSettingsAppInfo) else { return }
        var history = timestamps()
        history[liveBoardAppKey(app)] = date.timeIntervalSince1970
        if history.count > limit {
            let retained = history.sorted { $0.value > $1.value }.prefix(limit)
            history = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
        defaults.set(history, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }

    @MainActor static func sorted(_ apps: [LCAppModel]) -> [LCAppModel] {
        let history = timestamps()
        return apps.filter { history[liveBoardAppKey($0)] != nil }
            .sorted {
                let left = history[liveBoardAppKey($0)] ?? 0
                let right = history[liveBoardAppKey($1)] ?? 0
                if left == right { return LiveBoardAppCustomization.shared.name($0).localizedCaseInsensitiveCompare(LiveBoardAppCustomization.shared.name($1)) == .orderedAscending }
                return left > right
            }
    }

    static func clear() { defaults.removeObject(forKey: key); NotificationCenter.default.post(name: changed, object: nil) }
}
