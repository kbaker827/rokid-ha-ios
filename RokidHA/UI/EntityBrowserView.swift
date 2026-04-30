import SwiftUI

struct EntityBrowserView: View {
    @EnvironmentObject private var vm: HAViewModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var searchText = ""
    @State private var selectedDomain: String = "All"

    // Unique domain list derived from allEntities
    private var domains: [String] {
        var seen = Set<String>()
        var result = ["All"]
        for e in vm.allEntities where !seen.contains(e.domain) {
            seen.insert(e.domain)
            result.append(e.domain)
        }
        return result
    }

    private var filtered: [HAEntity] {
        vm.allEntities.filter { entity in
            let domainMatch = selectedDomain == "All" || entity.domain == selectedDomain
            let searchMatch = searchText.isEmpty
                || entity.friendlyName.localizedCaseInsensitiveContains(searchText)
                || entity.entityId.localizedCaseInsensitiveContains(searchText)
            return domainMatch && searchMatch
        }
    }

    private func isPinned(_ entity: HAEntity) -> Bool {
        settings.dashboardItems.contains { $0.entityId == entity.entityId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Domain picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(domains, id: \.self) { domain in
                            Button(domain.capitalized) {
                                selectedDomain = domain
                            }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedDomain == domain ? Color.blue : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedDomain == domain ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List(filtered) { entity in
                    Button {
                        if isPinned(entity) {
                            settings.removeDashboardItem(entity.entityId)
                        } else {
                            settings.addDashboardItem(entity.entityId)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: entity.sfSymbol)
                                .font(.title3)
                                .foregroundStyle(entity.isAlerting ? .red : .blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entity.friendlyName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(entity.entityId)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(entity.displayState)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if isPinned(entity) {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isPinned(entity) {
                            Button(role: .destructive) {
                                settings.removeDashboardItem(entity.entityId)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                        } else {
                            Button {
                                settings.addDashboardItem(entity.entityId)
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if isPinned(entity) {
                            Button {
                                settings.toggleAlert(for: entity.entityId)
                            } label: {
                                let alertOn = settings.dashboardItems.first { $0.entityId == entity.entityId }?.alertOnChange ?? false
                                Label(alertOn ? "No Alert" : "Alert", systemImage: alertOn ? "bell.slash" : "bell.fill")
                            }
                            .tint(.purple)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search entities…")
            .navigationTitle("Entities (\(vm.allEntities.count))")
        }
    }
}

#Preview {
    EntityBrowserView()
        .environmentObject(HAViewModel())
        .environmentObject(SettingsStore.shared)
}
