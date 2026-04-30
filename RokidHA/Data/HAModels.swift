import Foundation

// MARK: - Connection state

enum HAConnectionState: Equatable {
    case disconnected, connecting, authenticating, connected, error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected:    return "Disconnected"
        case .connecting:      return "Connecting…"
        case .authenticating:  return "Authenticating…"
        case .connected:       return "Connected"
        case .error(let msg):  return "Error: \(msg)"
        }
    }
}

// MARK: - Entity

struct HAEntity: Identifiable, Equatable {
    let entityId: String
    let state: String
    let friendlyName: String
    let unit: String?
    let deviceClass: String?
    let domain: String
    let lastChanged: Date

    var id: String { entityId }

    // Human-readable state label
    var displayState: String {
        switch domain {
        case "binary_sensor":
            switch deviceClass {
            case "door", "window", "garage_door":
                return state == "on" ? "Open" : "Closed"
            case "motion", "occupancy":
                return state == "on" ? "Detected" : "Clear"
            case "presence":
                return state == "on" ? "Home" : "Away"
            case "lock":
                return state == "on" ? "Unlocked" : "Locked"
            case "moisture", "flood":
                return state == "on" ? "Wet" : "Dry"
            case "smoke", "carbon_monoxide":
                return state == "on" ? "⚠ Detected!" : "Clear"
            case "connectivity":
                return state == "on" ? "Connected" : "Disconnected"
            default:
                return state == "on" ? "On" : "Off"
            }
        case "sensor":
            return unit != nil ? "\(state) \(unit!)" : state
        case "light", "switch", "input_boolean", "automation":
            return state == "on" ? "On" : "Off"
        case "climate":
            return state.replacingOccurrences(of: "_", with: " ").capitalized
        case "lock":
            return state == "locked" ? "Locked" : "Unlocked"
        case "cover":
            return state.replacingOccurrences(of: "_", with: " ").capitalized
        case "media_player":
            return state.replacingOccurrences(of: "_", with: " ").capitalized
        default:
            return state
        }
    }

    var sfSymbol: String {
        switch domain {
        case "sensor":
            switch deviceClass {
            case "temperature":  return "thermometer"
            case "humidity":     return "drop.fill"
            case "pressure":     return "gauge"
            case "power", "energy": return "bolt.fill"
            case "battery":      return "battery.50"
            case "illuminance":  return "sun.max.fill"
            case "co2", "carbon_dioxide": return "aqi.medium"
            default:             return "chart.line.uptrend.xyaxis"
            }
        case "binary_sensor":
            switch deviceClass {
            case "door", "garage_door": return "door.left.hand.closed"
            case "window":       return "window.casement"
            case "motion", "occupancy": return "figure.walk"
            case "presence":     return "person.fill"
            case "smoke":        return "smoke.fill"
            case "moisture", "flood": return "drop.fill"
            case "lock":         return "lock.fill"
            case "connectivity": return "wifi"
            default:             return "sensor.fill"
            }
        case "light":        return "lightbulb.fill"
        case "switch":       return "powerplug.fill"
        case "climate":      return "thermometer.sun.fill"
        case "lock":         return "lock.fill"
        case "cover":        return "blinds.horizontal.closed"
        case "weather":      return "cloud.sun.fill"
        case "media_player": return "speaker.wave.2.fill"
        case "automation":   return "gearshape.2.fill"
        default:             return "square.fill"
        }
    }

    var isAlerting: Bool {
        guard domain == "binary_sensor" else { return false }
        switch deviceClass {
        case "motion", "smoke", "carbon_monoxide", "moisture", "flood":
            return state == "on"
        default:
            return false
        }
    }

    // Parse from HA REST/WebSocket JSON dict
    static func from(dict: [String: Any]) -> HAEntity? {
        guard let entityId = dict["entity_id"] as? String,
              let state    = dict["state"] as? String,
              state != "unavailable", state != "unknown" else { return nil }
        let attrs        = dict["attributes"] as? [String: Any] ?? [:]
        let friendlyName = attrs["friendly_name"] as? String ?? entityId
        let unit         = attrs["unit_of_measurement"] as? String
        let deviceClass  = attrs["device_class"] as? String
        let domain       = entityId.components(separatedBy: ".").first ?? ""
        return HAEntity(entityId: entityId, state: state, friendlyName: friendlyName,
                        unit: unit, deviceClass: deviceClass, domain: domain,
                        lastChanged: Date())
    }
}

// MARK: - Dashboard item

struct DashboardItem: Codable, Identifiable {
    var entityId: String
    var alertOnChange: Bool = false
    var id: String { entityId }
}

// MARK: - Display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case compact, multiline, minimal
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
