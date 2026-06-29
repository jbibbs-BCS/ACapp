import SwiftUI

struct DashboardView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var searchVM: GlobalSearchViewModel

    init(client: CentralAPIClientProtocol) {
        self.apiClient = client
        _viewModel = StateObject(wrappedValue: DashboardViewModel(apiClient: client))
        _searchVM  = StateObject(wrappedValue: GlobalSearchViewModel(apiClient: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.sitesState,
            content: { sites in siteList(sites) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Dashboard")
        .searchable(text: $searchVM.query, prompt: "Search by hostname, IP, or MAC")
        .overlay(alignment: .top) {
            if !searchVM.query.isEmpty {
                SearchResultsOverlay(viewModel: searchVM) { result in
                    handleSearchSelection(result)
                }
                .padding(.top, 8)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func siteList(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "building.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
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
            List(sites) { site in
                NavigationLink(value: site) {
                    SiteRowView(site: site)
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site, apiClient: apiClient)
            }
            .navigationDestination(for: AccessPoint.self) { ap in
                APDetailView(ap: ap, apiClient: apiClient)
            }
            .navigationDestination(for: CentralSwitch.self) { sw in
                SwitchDetailView(sw: sw, apiClient: apiClient)
            }
        }
    }

    private func handleSearchSelection(_ result: SearchResult) {
        searchVM.query = ""
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
