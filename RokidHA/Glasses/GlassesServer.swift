import Foundation
import Network

// MARK: - Glasses TCP server (port 8091)

@MainActor
final class GlassesServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private(set) var clientCount = 0

    // MARK: - Start / Stop

    func start() {
        guard listener == nil else { return }
        do {
            listener = try NWListener(using: .tcp, on: 8091)
        } catch {
            print("[GlassesServer] Failed to create listener: \(error)")
            return
        }
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[GlassesServer] Listening on :8091")
            case .failed(let err):
                print("[GlassesServer] Listener failed: \(err)")
                Task { @MainActor [weak self] in self?.restart() }
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        clientCount = 0
    }

    private func restart() {
        stop()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            self.start()
        }
    }

    // MARK: - Connection management

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.connections.append(conn)
                    self?.clientCount = self?.connections.count ?? 0
                }
            case .failed, .cancelled:
                Task { @MainActor [weak self] in
                    self?.connections.removeAll { $0 === conn }
                    self?.clientCount = self?.connections.count ?? 0
                }
            default:
                break
            }
        }
        conn.start(queue: .main)
    }

    // MARK: - Broadcast

    private func broadcast(_ text: String) {
        guard !connections.isEmpty else { return }
        let payload = (text + "\n").data(using: .utf8)!
        connections.forEach { conn in
            conn.send(content: payload, completion: .contentProcessed { _ in })
        }
    }

    // MARK: - Public send methods

    /// Push a full HUD snapshot (all pinned entities).
    func broadcastHUD(entities: [HAEntity], format: GlassesFormat) {
        let lines: [String]
        switch format {
        case .compact:
            let parts = entities.prefix(4).map { "\($0.friendlyName): \($0.displayState)" }
            lines = [parts.joined(separator: "  |  ")]
        case .multiline:
            lines = entities.prefix(6).map { "• \($0.friendlyName): \($0.displayState)" }
        case .minimal:
            let parts = entities.prefix(3).map { $0.displayState }
            lines = [parts.joined(separator: " | ")]
        }
        let text = lines.joined(separator: "\n")
        let dict: [String: Any] = ["type": "hud", "text": text, "count": entities.count]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: data, encoding: .utf8) {
            broadcast(str)
        }
    }

    /// Push a state-change alert.
    func broadcastAlert(text: String) {
        let dict: [String: Any] = ["type": "alert", "text": text]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: data, encoding: .utf8) {
            broadcast(str)
        }
    }

    /// Push a raw status message.
    func broadcastStatus(text: String) {
        let dict: [String: Any] = ["type": "status", "text": text]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str  = String(data: data, encoding: .utf8) {
            broadcast(str)
        }
    }
}
