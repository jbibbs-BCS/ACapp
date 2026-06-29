import SwiftUI

struct AlertDetailView: View {
    let alert: CentralAlert
    let onAcknowledge: () -> Void

    @State private var showingConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: alert.severity.systemImage)
                        .foregroundStyle(alert.severity.color)
                        .font(.title2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.name).font(.headline)
                        Text(alert.severity.rawValue)
                            .font(.caption)
                            .foregroundStyle(alert.severity.color)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                if let desc = alert.description {
                    Text(desc).font(.body).foregroundStyle(.secondary)
                }
                if let device = alert.deviceSerial {
                    LabeledContent("Device", value: device)
                }
                if let site = alert.siteName {
                    LabeledContent("Site", value: site)
                }
                LabeledContent("Time", value: alert.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Status") {
                if alert.isCleared {
                    Label("Acknowledged", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        showingConfirm = true
                    } label: {
                        Label("Acknowledge Alert", systemImage: "checkmark.circle")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Alert Detail")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Acknowledge this alert?",
                            isPresented: $showingConfirm,
                            titleVisibility: .visible) {
            Button("Acknowledge") { onAcknowledge() }
        } message: {
            Text("This will mark the alert as cleared in Aruba Central.")
        }
    }
}

#Preview {
    NavigationStack {
        AlertDetailView(
            alert: CentralAlert(
                id: "a1", name: "AP Down", severity: .critical,
                description: "AP-Lobby (SN001) is unreachable.",
                deviceSerial: "SN001", siteName: "HQ Campus",
                createdAt: Date(), isCleared: false
            ),
            onAcknowledge: {}
        )
    }
}
