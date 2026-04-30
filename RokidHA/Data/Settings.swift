import Foundation
import Combine

final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    // MARK: - Persistence keys
    private enum Key {
        static let haURL           = "ha_url"
        static let haToken         = "ha_token"
        static let dashboardItems  = "dashboard_items"
        static let glassesFormat   = "glasses_format"
        static let autoReconnect   = "auto_reconnect"
    }

    // MARK: - Published properties

    @Published var haURL: String {
        didSet { UserDefaults.standard.set(haURL, forKey: Key.haURL) }
    }

    @Published var haToken: String {
        didSet { UserDefaults.standard.set(haToken, forKey: Key.haToken) }
    }

    @Published var dashboardItems: [DashboardItem] {
        didSet {
            if let data = try? JSONEncoder().encode(dashboardItems) {
                UserDefaults.standard.set(data, forKey: Key.dashboardItems)
            }
        }
    }

    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: Key.glassesFormat) }
    }

    @Published var autoReconnect: Bool {
        didSet { UserDefaults.standard.set(autoReconnect, forKey: Key.autoReconnect) }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        haURL          = ud.string(forKey: Key.haURL)    ?? "http://homeassistant.local:8123"
        haToken        = ud.string(forKey: Key.haToken)  ?? ""
        autoReconnect  = ud.object(forKey: Key.autoReconnect) as? Bool ?? true

        if let raw = ud.string(forKey: Key.glassesFormat),
           let fmt = GlassesFormat(rawValue: raw) {
            glassesFormat = fmt
        } else {
            glassesFormat = .compact
        }

        if let data = ud.data(forKey: Key.dashboardItems),
           let items = try? JSONDecoder().decode([DashboardItem].self, from: data) {
            dashboardItems = items
        } else {
            dashboardItems = []
        }
    }

    // MARK: - Helpers

    func addDashboardItem(_ entityId: String) {
        guard !dashboardItems.contains(where: { $0.entityId == entityId }) else { return }
        dashboardItems.append(DashboardItem(entityId: entityId))
    }

    func removeDashboardItem(_ entityId: String) {
        dashboardItems.removeAll { $0.entityId == entityId }
    }

    func toggleAlert(for entityId: String) {
        if let idx = dashboardItems.firstIndex(where: { $0.entityId == entityId }) {
            dashboardItems[idx].alertOnChange.toggle()
        }
    }

    func moveDashboardItems(from source: IndexSet, to destination: Int) {
        dashboardItems.move(fromOffsets: source, toOffset: destination)
    }

    /// Converts the stored HTTP(S) URL to a WebSocket URL + path.
    var websocketURL: URL? {
        var urlString = haURL.trimmingCharacters(in: .whitespaces)
        if urlString.hasPrefix("https://") {
            urlString = "wss://" + urlString.dropFirst("https://".count)
        } else if urlString.hasPrefix("http://") {
            urlString = "ws://" + urlString.dropFirst("http://".count)
        }
        if !urlString.hasSuffix("/api/websocket") {
            urlString = urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        + "/api/websocket"
        }
        return URL(string: urlString)
    }
}
