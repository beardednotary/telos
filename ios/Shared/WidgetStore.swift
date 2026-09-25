import Foundation

/// What the app hands the home screen widget and the Shortcuts action,
/// through the App Group both processes share. Compiled into Runner (which
/// writes it, from Dart) and ExpeditionWidget (which reads it), so the two
/// sides can never disagree about its shape.
///
/// It holds only what a door into a run needs: the recent dispatches, and
/// when the squad now out comes back. Never resources, levels or loot - a
/// widget that showed the guild would be a place to check on it.
enum WidgetStore {
    static let group = "group.com.dahvio.telos"

    /// One recent dispatch, exactly as SEND AGAIN offers it.
    struct Dispatch: Codable, Hashable {
        /// Redeploy.key in Dart; how a tap finds this dispatch again.
        var key: String
        /// "MOSSWOOD VERGE"
        var title: String
        /// "25 MIN · KAEL, MIRA"
        var subtitle: String
        /// The sector's accent as 0xAARRGGBB, as content.dart stores it.
        var accent: UInt32
    }

    /// The squad that is out, if any.
    struct Run: Codable, Hashable {
        var sectorName: String
        var accent: UInt32
        var endsAt: Date
    }

    private static let dispatchesKey = "dispatches"
    private static let runKey = "run"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    static func dispatches() -> [Dispatch] {
        guard let data = defaults?.data(forKey: dispatchesKey) else { return [] }
        return (try? JSONDecoder().decode([Dispatch].self, from: data)) ?? []
    }

    static func run() -> Run? {
        guard let data = defaults?.data(forKey: runKey) else { return nil }
        return try? JSONDecoder().decode(Run.self, from: data)
    }

    static func write(dispatches: [Dispatch], run: Run?) {
        guard let defaults else { return }
        defaults.set(try? JSONEncoder().encode(dispatches), forKey: dispatchesKey)
        if let run {
            defaults.set(try? JSONEncoder().encode(run), forKey: runKey)
        } else {
            defaults.removeObject(forKey: runKey)
        }
    }

    // MARK: - Links

    /// telos://dispatch/<key>, or telos://dispatch/latest.
    static func url(for key: String) -> URL {
        var parts = URLComponents()
        parts.scheme = "telos"
        parts.host = "dispatch"
        parts.path = "/" + key
        return parts.url ?? URL(string: "telos://dispatch/latest")!
    }

    /// The dispatch key a widget link carries, or nil for any other URL.
    static func key(from url: URL) -> String? {
        guard url.scheme == "telos", url.host == "dispatch" else { return nil }
        let key = String(url.path.dropFirst())
        return key.isEmpty ? nil : key
    }
}
