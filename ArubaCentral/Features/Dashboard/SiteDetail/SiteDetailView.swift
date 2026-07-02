import SwiftUI

struct SiteDetailView: View {
    @StateObject private var viewModel: SiteDetailViewModel

    init(site: Site) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site,
                                                                    apiClient: CentralAPIClient.placeholder))
    }

    init(site: Site, apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site, apiClient: apiClient))
    }

    var body: some View {
        List {
            siteHealthSection
            apSection
            switchSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.site.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Sections

    private var siteHealthSection: some View {
        Section {
            HStack(spacing: 12) {
                StatCardView(title: "Devices",
                             value: "\(viewModel.site.deviceCount)",
                             systemImage: "network")
                StatCardView(title: "Clients",
                             value: "\(viewModel.site.clientCount)",
                             systemImage: "person.2")
                StatCardView(title: "Alerts",
                             value: "\(viewModel.site.alertCount)",
                             systemImage: "bell")
            }
            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            HStack {
                HealthBadgePillView(size: .compact, level: viewModel.site.healthLevel)
                Text("Site Health")
            }
        }
    }

    @ViewBuilder
    private var apSection: some View {
        Section {
            switch viewModel.apsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

            case .loaded(let aps):
                if aps.isEmpty {
                    Text("No APs at this site")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(aps) { ap in
                        NavigationLink(value: ap) {
                            DeviceRowView(name: ap.name, model: ap.model,
                                         status: ap.status, uptime: ap.uptime)
                        }
                        .onAppear {
                            if ap.id == aps.last?.id {
                                Task { await viewModel.loadNextAPPage() }
                            }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("Access Points")
        }
    }

    @ViewBuilder
    private var switchSection: some View {
        Section {
            switch viewModel.switchesState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

            case .loaded(let switches):
                if switches.isEmpty {
                    Text("No switches at this site")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(switches) { sw in
                        NavigationLink(value: sw) {
                            DeviceRowView(name: sw.name, model: sw.model,
                                         status: sw.status, uptime: sw.uptime)
                        }
                        .onAppear {
                            if sw.id == switches.last?.id {
                                Task { await viewModel.loadNextSwitchPage() }
                            }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("Switches")
        }
    }
}

// MARK: - Shared device row

struct DeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status == .up ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let uptime {
                        Text("Up \(uptimeString(uptime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days    = seconds / 86400
        let hours   = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Placeholder for environment init

private extension CentralAPIClient {
    static var placeholder: CentralAPIClient {
        CentralAPIClient(authManager: AuthTokenManager(),
                         baseURL: CentralRegion.defaultRegion.baseURL)
    }
}

#Preview {
    NavigationStack {
        SiteDetailView(
            site: Site(id: "s1", name: "HQ Campus", healthPct: 90,
                       deviceCount: 28, clientCount: 310),
            apiClient: PreviewMockClient()
        )
    }
}
