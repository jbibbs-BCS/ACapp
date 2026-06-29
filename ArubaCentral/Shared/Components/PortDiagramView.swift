import SwiftUI

enum PortDiagramLayout {
    static func columns(for count: Int) -> Int {
        count <= 8 ? 4 : 12
    }
}

extension PortStatus {
    var color: String {
        switch self {
        case .up:       return "green"
        case .down:     return "gray"
        case .disabled: return "orange"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .up:       return .green
        case .down:     return Color(.systemGray4)
        case .disabled: return .orange
        }
    }
}

struct PortDiagramView: View {
    let ports: [SwitchInterface]
    let onBounce: (SwitchInterface) -> Void

    @State private var selectedPort: SwitchInterface? = nil

    private var columns: Int { PortDiagramLayout.columns(for: ports.count) }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: columns),
                spacing: 6
            ) {
                ForEach(ports) { port in
                    PortCell(port: port)
                        .onTapGesture { selectedPort = port }
                }
            }
            .padding(16)
        }
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(port: port, onBounce: {
                onBounce(port)
                selectedPort = nil
            })
            .presentationDetents([.medium])
        }
    }
}

private struct PortCell: View {
    let port: SwitchInterface

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(port.status.swiftUIColor.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(port.status.swiftUIColor, lineWidth: 2)
            )
            .overlay(
                Text(shortPortId(port.portId))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(port.status.swiftUIColor)
            )
            .frame(width: 44, height: 44)
            .accessibilityLabel("Port \(port.portId), \(port.status.rawValue)")
    }

    private func shortPortId(_ id: String) -> String {
        id.components(separatedBy: "/").last ?? id
    }
}

private struct PortDetailSheet: View {
    let port: SwitchInterface
    let onBounce: () -> Void

    @State private var showingBounceConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Port Info") {
                    LabeledContent("Port ID", value: port.portId)
                    LabeledContent("Status",  value: port.status.rawValue)
                    if let speed = port.speed { LabeledContent("Speed", value: speed) }
                    if let vlan  = port.vlan  { LabeledContent("VLAN",  value: "\(vlan)") }
                    if let dev   = port.connectedDevice { LabeledContent("Device", value: dev) }
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
                            status: i % 5 == 0 ? .down : .up,
                            speed: "1G", vlan: 10,
                            connectedDevice: nil,
                            txBytes: 1_000_000, rxBytes: 500_000)
        },
        onBounce: { _ in }
    )
}
