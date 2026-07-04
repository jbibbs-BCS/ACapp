import SwiftUI

/// A stack member's ports, for separating members in the port diagram.
struct PortMemberGroup: Identifiable, Equatable {
    let member: String            // "" for member-less ids (e.g. "A3")
    let ports: [SwitchInterface]
    var id: String { member }
}

enum PortDiagramLayout {
    static func columns(for count: Int) -> Int {
        count <= 8 ? 4 : 12
    }

    /// Groups ports by stack member — the leading component before the first "/"
    /// ("1" from "1/13" or "1/1/4"). Port ids without a "/" (e.g. "A3") share a
    /// single group, so a standalone switch renders as one grid. First-seen order
    /// is preserved.
    static func groupedByMember(_ ports: [SwitchInterface]) -> [PortMemberGroup] {
        var order: [String] = []
        var map: [String: [SwitchInterface]] = [:]
        for port in ports {
            let key: String
            if let slash = port.portId.firstIndex(of: "/") {
                key = String(port.portId[..<slash])
            } else {
                key = ""
            }
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(port)
        }
        return order.map { PortMemberGroup(member: $0, ports: map[$0]!) }
    }
}

extension PortStatus {
    // Semantic string identifier used in tests
    var color: String {
        switch self {
        case .up:       return "up"
        case .down:     return "down"
        case .disabled: return "disabled"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .up:       return .healthGood
        case .down:     return Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280
        case .disabled: return .healthWarning
        }
    }
}

struct PortDiagramView: View {
    let ports: [SwitchInterface]
    let onBounce: (SwitchInterface) -> Void

    @State private var selectedPort: SwitchInterface? = nil

    private var columns: Int { PortDiagramLayout.columns(for: ports.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PortLegendView()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(PortDiagramLayout.groupedByMember(ports)) { group in
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: columns),
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(group.ports) { port in
                                PortCell(port: port)
                                    .onTapGesture { selectedPort = port }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(port: port, onBounce: {
                onBounce(port)
                selectedPort = nil
            })
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Legend

private struct PortLegendView: View {
    var body: some View {
        HStack(spacing: 12) {
            legendPill(color: .healthGood,   label: "Up")
            legendPill(color: Color(red: 0.420, green: 0.447, blue: 0.502), label: "Down")
            legendPill(color: .healthWarning, label: "Disabled")
        }
    }

    private func legendPill(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Port cell

private struct PortCell: View {
    let port: SwitchInterface

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(port.status.swiftUIColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(port.status.swiftUIColor, lineWidth: 1.5)
            )
            .overlay(
                Text(port.portId)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(port.status.swiftUIColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
            )
            .frame(width: 44, height: 44)
            .accessibilityLabel("Port \(port.portId), \(port.status.rawValue)")
    }
}

// MARK: - Port detail sheet

private struct PortDetailSheet: View {
    let port: SwitchInterface
    let onBounce: () -> Void

    @State private var showingBounceConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Port Info") {
                    LabeledContent("Port ID", value: port.portId)
                    if let description = port.description, !description.isEmpty {
                        LabeledContent("Description", value: description)
                    }
                    LabeledContent("Status", value: port.status.rawValue)
                    if let speed = port.speed { LabeledContent("Speed", value: formatSpeed(speed)) }
                    if let vlan = port.vlan {
                        LabeledContent("Native VLAN", value: "\(vlan)")
                    }
                    if let ids = port.allowedVlanIds, !ids.isEmpty {
                        LabeledContent("Allowed VLANs", value: ids.map(String.init).joined(separator: ", "))
                    }
                    if let neighbour = port.neighbour { LabeledContent("Neighbour", value: neighbour) }
                    if let role = port.neighbourRole { LabeledContent("Neighbour Role", value: role) }
                }
                if let tx = port.txBytes, let rx = port.rxBytes {
                    Section("Traffic") {
                        LabeledContent("TX", value: formatBytes(tx))
                        LabeledContent("RX", value: formatBytes(rx))
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showingBounceConfirm = true
                    } label: {
                        Label("Bounce Port", systemImage: "arrow.clockwise.circle")
                    }
                    // NOTE: Bounce port endpoint TBC (Open Item #1) — button wired but action is placeholder
                } footer: {
                    Text("Bouncing a port briefly disconnects all devices on this port.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Port \(port.portId)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("Bounce port \(port.portId)?",
                            isPresented: $showingBounceConfirm,
                            titleVisibility: .visible) {
            Button("Bounce", role: .destructive, action: onBounce)
        } message: {
            Text("This will briefly disconnect all devices on this port.")
        }
    }

    private func formatSpeed(_ bps: Int) -> String {
        let gbps = Double(bps) / 1_000_000_000
        if gbps >= 1 { return String(format: "%.0f Gbps", gbps) }
        return String(format: "%.0f Mbps", Double(bps) / 1_000_000)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", mb / 1024)
    }
}

#Preview {
    PortDiagramView(
        ports: (1...24).map { i in
            SwitchInterface(portId: "1/1/\(i)",
                            status: i % 5 == 0 ? .down : (i % 7 == 0 ? .disabled : .up),
                            speed: 1_000_000_000, vlan: 10,
                            neighbour: nil,
                            txBytes: 1_000_000, rxBytes: 500_000)
        },
        onBounce: { _ in }
    )
}
