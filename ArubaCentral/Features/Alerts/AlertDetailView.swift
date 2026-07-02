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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.name)
                            .font(.headline)
                        AlertSeverityBadgeView(severity: alert.severity)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                if let desc = alert.description {
                    Text(desc).font(.body).foregroundStyle(.secondary)
                }
                if let device = alert.deviceSerial {
                    LabeledContent("Device") {
                        Text(device)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Color.brandOrange)
                    }
                }
                if let site = alert.siteName {
                    LabeledContent("Site", value: site)
                }
                LabeledContent("Time", value: alert.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Status") {
                if alert.isCleared {
                    Label("Acknowledged", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.healthGood)
                } else {
                    Button {
                        showingConfirm = true
                    } label: {
                        Text("Acknowledge Alert")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(Color.brandOrange, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
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
