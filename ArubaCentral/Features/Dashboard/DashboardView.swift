import SwiftUI

struct DashboardView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: DashboardViewModel
    let onAlertsTapped: () -> Void

    init(client: CentralAPIClientProtocol, onAlertsTapped: @escaping () -> Void = {}) {
        self.apiClient = client
        self.onAlertsTapped = onAlertsTapped
        _viewModel = StateObject(wrappedValue: DashboardViewModel(apiClient: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.sitesState,
            content: { sites in siteScrollView(sites) },
            retry: { Task { await viewModel.load() } }
        )
        .background(Color.appBackground)
        .navigationTitle("Dashboard")
        .navigationDestination(for: Site.self) { site in
            SiteDetailView(site: site, apiClient: apiClient)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func siteScrollView(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "building.2")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandOrange.opacity(0.6))
                Text("No Sites")
                    .font(.headline)
                Text("No sites found in your Central account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.alertCounts.hasAny {
                        AlertSummaryCardView(counts: viewModel.alertCounts, onTap: onAlertsTapped)
                    }
                    ForEach(sites) { site in
                        NavigationLink(value: site) {
                            SiteCardView(site: site)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
            .refreshable { await viewModel.refresh() }
        }
    }
}

// MARK: - Alert Summary Card

struct AlertSummaryCardView: View {
    let counts: AlertSummaryCounts
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 4pt leading bar
                Rectangle()
                    .fill(Color.brandOrange)
                    .frame(width: 4)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)

                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color.brandOrange)
                        .font(.title3)
                        .padding(.leading, 10)
                    Text("Active Alerts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(counts.total)")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.brandOrange)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 14)
                }
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .light ? .black.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Site Card

struct SiteCardView: View {
    let site: Site

    @Environment(\.colorScheme) private var colorScheme

    private var statusColor: Color { Color.healthColor(for: site.healthLevel) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Card body
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(site.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HealthBadgePillView(size: .standard, level: site.healthLevel)
                    }
                    Spacer()
                    Text("\(site.healthPct)%")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(statusColor)
                }
                .padding(.leading, 18) // extra leading for accent bar
                .padding(.trailing, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(height: 0.5)

                // Stat row
                HStack(spacing: 0) {
                    statCell(
                        value: "\(site.goodDeviceCount)/\(site.deviceCount)",
                        label: "DEVICES",
                        icon: "network",
                        valueColor: .primary
                    )
                    Rectangle().fill(Color.cardBorder).frame(width: 0.5, height: 40)
                    statCell(
                        value: "\(site.clientCount)",
                        label: "CLIENTS",
                        icon: "person.2.fill",
                        valueColor: .primary
                    )
                    Rectangle().fill(Color.cardBorder).frame(width: 0.5, height: 40)
                    statCell(
                        value: "\(site.alertCount)",
                        label: "ALERTS",
                        icon: "bell.fill",
                        valueColor: site.alertCount == 0 ? .healthGood : .healthCritical
                    )
                }
                .padding(.vertical, 10)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .light ? .black.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )

            // 3pt leading health-color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(site.name), health \(site.healthPct) percent, \(site.goodDeviceCount) of \(site.deviceCount) devices healthy, \(site.clientCount) clients, \(site.alertCount) alerts")
    }

    private func statCell(value: String, label: String, icon: String, valueColor: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        DashboardView(client: PreviewMockClient())
    }
}
