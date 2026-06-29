import SwiftUI

struct AlertsView: View {
    @ObservedObject var viewModel: AlertsViewModel
    @State private var navigationPath = NavigationPath()

    init(viewModel: AlertsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LoadStateView(
                state: viewModel.alertsState,
                content: { alerts in alertList(alerts) },
                retry: { Task { await viewModel.load() } }
            )
            .navigationTitle("Alerts")
            .navigationDestination(for: CentralAlert.self) { alert in
                AlertDetailView(alert: alert, onAcknowledge: {
                    Task { await viewModel.acknowledge(alertId: alert.id) }
                })
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAlertNotification)) { note in
            if let alertId = note.userInfo?["alert_id"] as? String {
                viewModel.navigateTo(alertId: alertId)
            }
        }
        .onChangeCompat(of: viewModel.selectedAlertId) { alertId in
            guard let alertId,
                  case .loaded(let alerts) = viewModel.alertsState,
                  let alert = alerts.first(where: { $0.id == alertId }) else { return }
            navigationPath.append(alert)
            viewModel.selectedAlertId = nil
        }
        .alert("Action Failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError?.userMessage ?? "") }
    }

    @ViewBuilder
    private func alertList(_ alerts: [CentralAlert]) -> some View {
        if alerts.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "bell.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Alerts")
                    .font(.headline)
                Text("Your network has no alerts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List(alerts) { alert in
                NavigationLink(value: alert) {
                    AlertRowView(alert: alert)
                }
                .onAppear {
                    if alert.id == alerts.last?.id { Task { await viewModel.loadNextPage() } }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.refresh() }
        }
    }
}

struct AlertRowView: View {
    let alert: CentralAlert

    var body: some View {
        HStack(spacing: 12) {
            // Unacknowledged left border indicator
            Rectangle()
                .fill(alert.isCleared ? Color.clear : alert.severity.color)
                .frame(width: 4)
                .clipShape(Capsule())
                .accessibilityHidden(true)

            Image(systemName: alert.severity.systemImage)
                .foregroundStyle(alert.severity.color)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.name)
                    .font(.headline)
                    .foregroundStyle(alert.isCleared ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let site = alert.siteName {
                        Text(site).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(alert.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if alert.isCleared {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
                    .accessibilityLabel("Acknowledged")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let status = alert.isCleared ? "acknowledged" : "unacknowledged"
        return "\(alert.severity.rawValue) alert: \(alert.name), \(status)"
    }
}

extension Notification.Name {
    static let didReceiveAlertNotification = Notification.Name("didReceiveAlertNotification")
}
