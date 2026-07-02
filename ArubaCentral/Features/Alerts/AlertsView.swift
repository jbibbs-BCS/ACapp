import SwiftUI

struct AlertsView: View {
    @ObservedObject var viewModel: AlertsViewModel
    @State private var navigationPath = NavigationPath()
    @State private var severityFilter: AlertSeverity? = nil

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
            .background(Color.appBackground)
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
        let displayed = severityFilter.map { s in alerts.filter { $0.severity == s } } ?? alerts
        VStack(spacing: 0) {
            filterBar
            if displayed.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No \(severityFilter?.rawValue ?? "") Alerts")
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(displayed) { alert in
                    NavigationLink(value: alert) {
                        AlertRowView(alert: alert)
                    }
                    .listRowBackground(
                        ZStack {
                            Color.cardBackground
                            if !alert.isCleared { alert.severity.color.opacity(0.06) }
                        }
                    )
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .onAppear {
                        if alert.id == alerts.last?.id { Task { await viewModel.loadNextPage() } }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SeverityFilterChip(label: "All", color: .brandOrange,
                                   isSelected: severityFilter == nil) {
                    severityFilter = nil
                }
                ForEach([AlertSeverity.critical, .major, .minor, .info], id: \.self) { sev in
                    SeverityFilterChip(label: sev.rawValue, color: sev.color,
                                       isSelected: severityFilter == sev) {
                        severityFilter = severityFilter == sev ? nil : sev
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appBackground)
    }
}

private struct SeverityFilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AlertRowView: View {
    let alert: CentralAlert

    var body: some View {
        HStack(spacing: 0) {
            // 4pt severity bar
            Rectangle()
                .fill(alert.isCleared ? Color.clear : alert.severity.color)
                .frame(width: 4)
                .clipShape(Capsule())
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: alert.severity.systemImage)
                    .foregroundStyle(alert.isCleared ? Color.secondary : alert.severity.color)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(alert.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(alert.isCleared ? .secondary : .primary)
                        if !alert.isCleared {
                            AlertSeverityBadgeView(severity: alert.severity)
                        }
                    }
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
                        .foregroundStyle(Color.healthGood)
                        .imageScale(.small)
                        .accessibilityLabel("Acknowledged")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
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
