import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: HAViewModel
    @EnvironmentObject private var settings: SettingsStore

    private var previewLines: [String] {
        let entities = vm.dashboardEntities
        switch settings.glassesFormat {
        case .compact:
            let parts = entities.prefix(4).map { "\($0.friendlyName): \($0.displayState)" }
            return [parts.joined(separator: "  |  ")]
        case .multiline:
            return entities.prefix(6).map { "• \($0.friendlyName): \($0.displayState)" }
        case .minimal:
            let parts = entities.prefix(3).map { $0.displayState }
            return [parts.joined(separator: " | ")]
        }
    }

    private var rawJSON: String {
        let entities = vm.dashboardEntities
        let dict: [String: Any] = [
            "type": "hud",
            "text": previewLines.joined(separator: "\n"),
            "count": entities.count
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let str  = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Format picker
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Glasses mockup
                    GlassesMockup(lines: previewLines)
                        .padding(.horizontal)

                    // Connection info
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(vm.glassesClientCount > 0 ? .green : .secondary)
                        Text("TCP :8091 — \(vm.glassesClientCount) client(s) connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Raw JSON
                    GroupBox("Raw JSON (sent to glasses)") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(rawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Glasses Preview")
        }
    }
}

// MARK: - Glasses Mockup

struct GlassesMockup: View {
    let lines: [String]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(2)
                }
                if lines.isEmpty {
                    Text("No pinned entities")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .aspectRatio(16/4, contentMode: .fit)
    }
}

#Preview {
    GlassesPreviewView()
        .environmentObject(HAViewModel())
        .environmentObject(SettingsStore.shared)
}
