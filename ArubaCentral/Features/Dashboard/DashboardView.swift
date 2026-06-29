import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(client: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.sitesState,
            content: { sites in siteList(sites) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Dashboard")
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func siteList(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            ContentUnavailableView(
                "No Sites",
                systemImage: "building.2",
                description: Text("No sites found in your Central account.")
            )
        } else {
            List(sites) { site in
                NavigationLink(value: site) {
                    SiteRowView(site: site)
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
        }
    }
}

struct SiteRowView: View {
    let site: Site

    var body: some View {
        HStack(spacing: 12) {
            HealthBadgeView(level: site.healthLevel)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                HStack(spacing: 16) {
                    Label("\(site.apCount) APs",         systemImage: "antenna.radiowaves.left.and.right")
                    Label("\(site.switchCount) SWs",     systemImage: "network")
                    Label("\(site.clientCount) Clients",  systemImage: "person.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(site.name), health \(site.healthLevel.accessibilityLabel), " +
        "\(site.apCount) APs, \(site.switchCount) switches, \(site.clientCount) clients"
    }
}

#Preview {
    NavigationStack {
        DashboardView(client: PreviewMockClient())
    }
}
