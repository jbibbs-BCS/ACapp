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
            .listRowBackground(Color.cardBackground)

            Section("Details") {
                if let summary = alert.description {
                    Text(summary).font(.body).foregroundStyle(.secondary)
                }
                if let category = alert.category {
                    LabeledContent("Category", value: category)
                }
                if let deviceType = alert.deviceType {
                    LabeledContent("Device Type", value: deviceType)
                }
                if let priority = alert.priority {
                    LabeledContent("Priority", value: priority)
                }
                if let state = alert.status {
                    LabeledContent("State", value: state)
                }
                LabeledContent("Created", value: alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let updated = alert.updatedAt {
                    LabeledContent("Updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                }
                if let reason = alert.clearedReason {
                    LabeledContent("Cleared Reason", value: reason)
                }
            }
            .listRowBackground(Color.cardBackground)

            Section("Status") {
                if alert.isCleared {
                    Label("Acknowledged", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.healthGood)
                        .listRowBackground(Color.cardBackground)
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
                id: "a1", name: "Insufficient PoE Received", severity: .critical,
                description: "AP LUHR000001 did not receive the requested PoE power which may limit its functions.",
                createdAt: Date(), isCleared: false,
                category: "System", deviceType: "Access Point",
                priority: "Very High", status: "Active"
            ),
            onAcknowledge: {}
        )
    }
}
