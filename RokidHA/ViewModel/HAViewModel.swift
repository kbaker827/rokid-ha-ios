import Foundation
import Combine

@MainActor
final class HAViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var connectionState: HAConnectionState = .disconnected
    @Published private(set) var allEntities: [HAEntity] = []
    @Published private(set) var recentAlerts: [String] = []
    @Published private(set) var glassesClientCount = 0

    // MARK: - Dependencies

    let settings = SettingsStore.shared
    private let wsClient     = HAWebSocketClient()
    private let glassesServer = GlassesServer()

    // MARK: - Timers / tasks

    private var hudTimer: Timer?
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Init / deinit

    init() {
        wsClient.delegate = self
        glassesServer.start()
        startHUDTimer()
    }

    deinit {
        hudTimer?.invalidate()
        reconnectTask?.cancel()
    }

    // MARK: - Connect / Disconnect

    func connect() {
        reconnectTask?.cancel()
        guard let url = settings.websocketURL else {
            connectionState = .error("Invalid URL")
            return
        }
        guard !settings.haToken.isEmpty else {
            connectionState = .error("No access token")
            return
        }
        connectionState = .connecting
        wsClient.connect(url: url, token: settings.haToken)
    }

    func disconnect() {
        reconnectTask?.cancel()
        wsClient.disconnect()
        connectionState = .disconnected
    }

    // MARK: - Dashboard entities (pinned + resolved)

    var dashboardEntities: [HAEntity] {
        settings.dashboardItems.compactMap { item in
            allEntities.first { $0.entityId == item.entityId }
        }
    }

    // MARK: - Entity lookup

    func entity(for id: String) -> HAEntity? {
        allEntities.first { $0.entityId == id }
    }

    // MARK: - Glasses HUD

    private func startHUDTimer() {
        hudTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pushHUD() }
        }
    }

    private func pushHUD() {
        let entities = dashboardEntities
        guard !entities.isEmpty else { return }
        glassesServer.broadcastHUD(entities: entities, format: settings.glassesFormat)
        glassesClientCount = glassesServer.clientCount
    }

    // MARK: - Alert helper

    private func postAlert(_ text: String) {
        recentAlerts.insert(text, at: 0)
        if recentAlerts.count > 20 { recentAlerts.removeLast() }
        glassesServer.broadcastAlert(text: text)
    }

    // MARK: - Auto-reconnect

    private func scheduleReconnect() {
        guard settings.autoReconnect else { return }
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            connect()
        }
    }

    // MARK: - Alert text builder

    private func alertText(for entity: HAEntity, previous: HAEntity?) -> String? {
        // Only alert if dashboardItem has alertOnChange = true
        guard settings.dashboardItems.first(where: { $0.entityId == entity.entityId })?.alertOnChange == true else {
            return nil
        }
        // Suppress if state didn't change
        if let prev = previous, prev.state == entity.state { return nil }

        let name  = entity.friendlyName
        let state = entity.displayState

        switch entity.domain {
        case "binary_sensor":
            switch entity.deviceClass {
            case "door", "garage_door":
                let emoji = entity.state == "on" ? "🚪" : "🚪"
                return "\(emoji) \(name): \(state)"
            case "window":
                return "🪟 \(name): \(state)"
            case "motion", "occupancy":
                return entity.state == "on" ? "🏃 Motion: \(name)" : nil
            case "presence":
                return entity.state == "on" ? "🏠 \(name) is Home" : "👋 \(name) left"
            case "smoke":
                return entity.state == "on" ? "🔥 SMOKE DETECTED: \(name)!" : "✅ \(name): Clear"
            case "carbon_monoxide":
                return entity.state == "on" ? "⚠️ CO DETECTED: \(name)!" : "✅ \(name): Clear"
            case "moisture", "flood":
                return entity.state == "on" ? "💧 WATER: \(name)!" : "✅ \(name): Dry"
            case "lock":
                return "🔒 \(name): \(state)"
            default:
                return "\(name): \(state)"
            }
        case "lock":
            return "🔒 \(name): \(state)"
        case "cover":
            return "🏠 \(name): \(state)"
        case "climate":
            return "🌡 \(name): \(state)"
        case "light", "switch":
            return "💡 \(name): \(state)"
        default:
            return "\(name): \(state)"
        }
    }
}

// MARK: - HAWebSocketClientDelegate

extension HAViewModel: HAWebSocketClientDelegate {

    nonisolated func clientDidConnect() {
        Task { @MainActor [weak self] in
            self?.connectionState = .authenticating
        }
    }

    nonisolated func clientDidAuthenticate() {
        Task { @MainActor [weak self] in
            self?.connectionState = .connected
            self?.glassesServer.broadcastStatus(text: "HA Connected")
        }
    }

    nonisolated func clientDidDisconnect(error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let err = error {
                self.connectionState = .error(err.localizedDescription)
            } else {
                self.connectionState = .disconnected
            }
            self.scheduleReconnect()
        }
    }

    nonisolated func clientDidReceiveStates(_ entities: [HAEntity]) {
        Task { @MainActor [weak self] in
            self?.allEntities = entities.sorted {
                $0.domain < $1.domain || ($0.domain == $1.domain && $0.friendlyName < $1.friendlyName)
            }
            self?.pushHUD()
        }
    }

    nonisolated func clientDidReceiveStateChange(entity: HAEntity) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previous = self.allEntities.first { $0.entityId == entity.entityId }
            if let idx = self.allEntities.firstIndex(where: { $0.entityId == entity.entityId }) {
                self.allEntities[idx] = entity
            } else {
                self.allEntities.append(entity)
            }
            if let text = self.alertText(for: entity, previous: previous) {
                self.postAlert(text)
            }
            // Refresh HUD if this entity is on the dashboard
            if self.settings.dashboardItems.contains(where: { $0.entityId == entity.entityId }) {
                self.pushHUD()
            }
        }
    }
}
