import Foundation

// MARK: - Delegate

protocol HAWebSocketClientDelegate: AnyObject {
    func clientDidConnect()
    func clientDidAuthenticate()
    func clientDidDisconnect(error: Error?)
    func clientDidReceiveStates(_ entities: [HAEntity])
    func clientDidReceiveStateChange(entity: HAEntity)
}

// MARK: - Client

@MainActor
final class HAWebSocketClient: NSObject {

    weak var delegate: HAWebSocketClientDelegate?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var nextMessageId = 1
    private var getStatesId   = 0
    private var subscribeId   = 0
    private(set) var isConnected = false

    // MARK: - Connect / Disconnect

    func connect(url: URL, token: String) {
        disconnect()

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: .main)
        task    = session?.webSocketTask(with: url)
        task?.resume()

        self.token = token
        listenForMessage()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task    = nil
        session = nil
        isConnected = false
        nextMessageId = 1
    }

    // MARK: - Private state

    private var token: String = ""

    // MARK: - Send helpers

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func newId() -> Int {
        let id = nextMessageId
        nextMessageId += 1
        return id
    }

    // MARK: - Auth flow

    private func sendAuth() {
        send(["type": "auth", "access_token": token])
    }

    private func subscribeToEvents() {
        subscribeId = newId()
        send(["id": subscribeId, "type": "subscribe_events", "event_type": "state_changed"])
    }

    private func getStates() {
        getStatesId = newId()
        send(["id": getStatesId, "type": "get_states"])
    }

    // MARK: - Ping

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.task?.sendPing { _ in }
            }
        }
    }

    // MARK: - Receive loop

    private func listenForMessage() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor [weak self] in
                    self?.handleDisconnect(error: error)
                }
            case .success(let message):
                Task { @MainActor [weak self] in
                    self?.handle(message: message)
                    self?.listenForMessage()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        var jsonString: String?
        switch message {
        case .string(let s): jsonString = s
        case .data(let d):   jsonString = String(data: d, encoding: .utf8)
        @unknown default:    return
        }
        guard let str = jsonString,
              let data = str.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        handleJSON(obj)
    }

    private func handleJSON(_ obj: [String: Any]) {
        let type = obj["type"] as? String ?? ""

        switch type {
        case "auth_required":
            sendAuth()

        case "auth_ok":
            isConnected = true
            delegate?.clientDidAuthenticate()
            subscribeToEvents()
            getStates()
            startPing()

        case "auth_invalid":
            delegate?.clientDidDisconnect(error: HAError.authInvalid)

        case "result":
            let id = obj["id"] as? Int ?? -1
            if id == getStatesId,
               let result = obj["result"] as? [[String: Any]] {
                let entities = result.compactMap { HAEntity.from(dict: $0) }
                delegate?.clientDidReceiveStates(entities)
            }

        case "event":
            guard let event     = obj["event"] as? [String: Any],
                  let eventData = event["data"] as? [String: Any],
                  let newState  = eventData["new_state"] as? [String: Any],
                  let entity    = HAEntity.from(dict: newState)
            else { return }
            delegate?.clientDidReceiveStateChange(entity: entity)

        default:
            break
        }
    }

    private func handleDisconnect(error: Error?) {
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
        delegate?.clientDidDisconnect(error: error)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HAWebSocketClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {
        Task { @MainActor [weak self] in
            self?.delegate?.clientDidConnect()
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                                reason: Data?) {
        Task { @MainActor [weak self] in
            self?.handleDisconnect(error: nil)
        }
    }
}

// MARK: - Errors

enum HAError: LocalizedError {
    case authInvalid
    case badURL

    var errorDescription: String? {
        switch self {
        case .authInvalid: return "Home Assistant rejected the access token."
        case .badURL:      return "Invalid Home Assistant URL."
        }
    }
}
