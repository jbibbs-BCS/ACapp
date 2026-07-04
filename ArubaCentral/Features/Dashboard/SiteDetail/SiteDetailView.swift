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
            // Health header
            Section {
                SiteHealthHeaderView(site: viewModel.site)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.appBackground)
                    .listRowSeparator(.hidden)
            }

            apSection
            switchSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(viewModel.site.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var apSection: some View {
        Section {
            switch viewModel.apsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appBackground)

            case .loaded(let aps):
                if aps.isEmpty {
                    Text("No APs at this site")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.appBackground)
                } else {
                    ForEach(aps) { ap in
                        NavigationLink(value: ap) {
                            BrandedDeviceRowView(name: ap.name, model: ap.model,
                                                 status: ap.status, uptime: ap.uptime)
                        }
                        .listRowBackground(Color.cardBackground)
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
                    .listRowBackground(Color.appBackground)
            }
        } header: {
            Text("Access Points")
                .font(.caption.weight(.semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.brandSectionHeader)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var switchSection: some View {
        Section {
            switch viewModel.switchesState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appBackground)

            case .loaded(let switches):
                if switches.isEmpty {
                    Text("No switches at this site")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.appBackground)
                } else {
                    let entries = switches.groupedIntoStacks()
                    ForEach(entries) { entry in
                        Group {
                            switch entry {
                            case .standalone(let sw):
                                NavigationLink(value: sw) {
                                    BrandedDeviceRowView(name: sw.name, model: sw.model,
                                                         status: sw.status, uptime: sw.uptime)
                                }
                            case .stack(let stack):
                                NavigationLink(value: stack.representative) {
                                    StackRowView(stack: stack)
                                }
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                        .onAppear {
                            if entry.id == entries.last?.id {
                                Task { await viewModel.loadNextSwitchPage() }
                            }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .listRowBackground(Color.appBackground)
            }
        } header: {
            Text("Switches")
                .font(.caption.weight(.semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.brandSectionHeader)
                .padding(.top, 4)
        }
    }
}

// MARK: - Branded device row

private struct BrandedDeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                Text(model)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let uptime {
                    Text("Up \(uptimeString(uptime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            DeviceStatusBadge(status: status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days = seconds / 86400; let hours = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - DeviceRowView kept for DevicesView compatibility

struct DeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(model)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let uptime {
                        Text("Up \(uptimeString(uptime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            DeviceStatusBadge(status: status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days = seconds / 86400; let hours = (seconds % 86400) / 3600
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
