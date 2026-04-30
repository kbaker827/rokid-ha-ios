import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: HAViewModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var showTokenField = false

    var body: some View {
        NavigationStack {
            Form {
                // Home Assistant connection
                Section("Home Assistant") {
                    LabeledContent("URL") {
                        TextField("http://homeassistant.local:8123", text: $settings.haURL)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    LabeledContent("Token") {
                        if showTokenField {
                            TextField("Long-lived access token", text: $settings.haToken)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.haToken.isEmpty ? "Not set" : "••••••••")
                                .foregroundStyle(settings.haToken.isEmpty ? .red : .secondary)
                        }
                    }
                    .onTapGesture { showTokenField.toggle() }

                    Button {
                        vm.disconnect()
                        vm.connect()
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                    }

                    Toggle("Auto-reconnect on drop", isOn: $settings.autoReconnect)
                }

                // Display format
                Section("Glasses Display") {
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }

                    LabeledContent("TCP port", value: "8091")
                        .foregroundStyle(.secondary)
                }

                // Dashboard
                Section("Dashboard") {
                    LabeledContent("Pinned entities", value: "\(settings.dashboardItems.count)")
                    Button(role: .destructive) {
                        settings.dashboardItems = []
                    } label: {
                        Label("Clear all pins", systemImage: "pin.slash")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("App",     value: "Rokid HA HUD")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("iOS",     value: "17.0+")
                    Link("Home Assistant WebSocket API",
                         destination: URL(string: "https://developers.home-assistant.io/docs/api/websocket")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HAViewModel())
        .environmentObject(SettingsStore.shared)
}
