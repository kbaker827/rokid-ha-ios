# Rokid HA HUD


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that connects to **Home Assistant** via WebSocket and streams live entity state to **Rokid AR glasses** (TCP) as a heads-up display.

```
Home Assistant ──WS :8123──▶ iPhone (RokidHA) ──Bluetooth/RokidSDK──▶ Rokid Glasses
```

## What's displayed

### On the Rokid glasses (TCP :8091)

A JSON line is pushed every 10 seconds (or immediately on alert):

```json
{"type":"hud","text":"Front Door: Closed  |  Motion: Clear  |  Temp: 72°F","count":3}
{"type":"alert","text":"🏃 Motion: Living Room"}
{"type":"alert","text":"🚪 Front Door: Open"}
```

### In the app

- **Dashboard** — Pinned entity tiles with live state; recent alerts list; glasses client count
- **Entities** — Full searchable/filterable entity browser; swipe to pin/unpin; swipe to toggle alerts
- **Glasses** — Live format preview on a glasses mockup; raw JSON output
- **Settings** — HA URL + long-lived token; format picker; auto-reconnect toggle

## Display formats

| Format | Description |
|--------|-------------|
| **Compact** | All pinned entities on one line: `Name: State  \|  Name: State` |
| **Multiline** | Each entity on its own line: `• Name: State` |
| **Minimal** | State values only: `Closed \| Clear \| 72°F` |

## Setup

1. Open `RokidHA.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. Grant local network permission when prompted.
5. In **Settings**:
   - Enter your Home Assistant URL (e.g. `http://homeassistant.local:8123`)
   - Paste a [long-lived access token](https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token) from your HA profile
6. Tap **Reconnect** — the status dot turns green when authenticated.
7. Go to **Entities**, search for what you want, and swipe right to pin.
8. Optionally swipe left on pinned entities to toggle change alerts.
9. Connect Rokid glasses to the same Wi-Fi; point TCP client at `<phone-ip>:8091`.

## Home Assistant WebSocket protocol

| Step | Message |
|------|---------|
| Server → Client | `{"type":"auth_required"}` |
| Client → Server | `{"type":"auth","access_token":"<token>"}` |
| Server → Client | `{"type":"auth_ok"}` |
| Client → Server | `{"id":1,"type":"subscribe_events","event_type":"state_changed"}` |
| Client → Server | `{"id":2,"type":"get_states"}` |
| Server → Client | `{"id":2,"type":"result","result":[...entities...]}` |
| Server → Client | `{"type":"event","event":{"data":{"new_state":{...}}}}` |

A ping is sent every 30 seconds to keep the connection alive.

## Alert system

Entities with **alert on change** enabled push an immediate notification to the glasses whenever their state changes. Domain-specific emoji are used:

| Domain / Class | Alert example |
|----------------|--------------|
| Door / window  | 🚪 Front Door: Open |
| Motion         | 🏃 Motion: Living Room |
| Presence       | 🏠 Person is Home |
| Smoke          | 🔥 SMOKE DETECTED: Kitchen! |
| Moisture/flood | 💧 WATER: Basement! |
| CO             | ⚠️ CO DETECTED: Garage! |
| Lock           | 🔒 Front Lock: Unlocked |

## Requirements

- iOS 17.0+
- Xcode 15+
- Home Assistant instance (any version with WebSocket API)
- Long-lived access token from HA user profile
- Rokid AR glasses on the same Wi-Fi network (optional — app works standalone)
