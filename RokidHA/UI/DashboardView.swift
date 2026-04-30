import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: HAViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            List {
                // Connection banner
                Section {
                    ConnectionBanner(state: vm.connectionState) {
                        if vm.connectionState.isConnected {
                            vm.disconnect()
                        } else {
                            vm.connect()
                        }
                    }
                }

                // Pinned entities
                if vm.dashboardEntities.isEmpty {
                    Section("Pinned Entities") {
                        ContentUnavailableView(
                            "No pinned entities",
                            systemImage: "pin.slash",
                            description: Text("Go to Entities to pin items here.")
                        )
                    }
                } else {
                    Section("Pinned Entities") {
                        ForEach(vm.dashboardEntities) { entity in
                            EntityRow(entity: entity, isPinned: true, alertOn: settings.dashboardItems.first(where: { $0.entityId == entity.entityId })?.alertOnChange ?? false)
                        }
                        .onMove { from, to in settings.moveDashboardItems(from: from, to: to) }
                        .onDelete { idx in
                            let ids = idx.map { vm.dashboardEntities[$0].entityId }
                            ids.forEach { settings.removeDashboardItem($0) }
                        }
                    }
                }

                // Recent alerts
                if !vm.recentAlerts.isEmpty {
                    Section("Recent Alerts") {
                        ForEach(vm.recentAlerts.prefix(5), id: \.self) { alert in
                            Text(alert)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Glasses status
                Section("Glasses") {
                    HStack {
                        Image(systemName: "eyeglasses")
                        Text("TCP :8091")
                        Spacer()
                        Text("\(vm.glassesClientCount) connected")
                            .foregroundStyle(vm.glassesClientCount > 0 ? .green : .secondary)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("HA HUD")
            .toolbar {
                EditButton()
            }
        }
    }
}

// MARK: - Connection Banner

struct ConnectionBanner: View {
    let state: HAConnectionState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
            Text(state.label)
                .font(.subheadline.weight(.medium))
            Spacer()
            Button(state.isConnected ? "Disconnect" : "Connect", action: action)
                .font(.subheadline)
                .buttonStyle(.borderedProminent)
                .tint(state.isConnected ? .red : .blue)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var dotColor: Color {
        switch state {
        case .connected:       return .green
        case .connecting, .authenticating: return .orange
        case .error:           return .red
        case .disconnected:    return .gray
        }
    }
}

// MARK: - Entity Row

struct EntityRow: View {
    let entity: HAEntity
    let isPinned: Bool
    let alertOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entity.sfSymbol)
                .font(.title3)
                .foregroundStyle(entity.isAlerting ? .red : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.friendlyName)
                    .font(.subheadline.weight(.medium))
                Text(entity.entityId)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entity.displayState)
                    .font(.subheadline)
                    .foregroundStyle(entity.isAlerting ? .red : .primary)
                if alertOn {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .listRowBackground(entity.isAlerting ? Color.red.opacity(0.07) : Color.clear)
    }
}

#Preview {
    DashboardView()
        .environmentObject(HAViewModel())
        .environmentObject(SettingsStore.shared)
}
