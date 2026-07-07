import SwiftUI

struct ClientsView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: ClientsViewModel
    @StateObject private var searchVM: GlobalSearchViewModel
    @State private var showingSitePicker = false
    @Binding private var searchPath: NavigationPath

    init(apiClient: CentralAPIClientProtocol,
         searchPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: ClientsViewModel(apiClient: apiClient))
        _searchVM  = StateObject(wrappedValue: GlobalSearchViewModel(apiClient: apiClient))
        _searchPath = searchPath
    }

    var body: some View {
        Group {
            switch viewModel.clientsState {
            case .idle:
                emptyPrompt

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                clientList

            case .error(let error):
                VStack(spacing: 16) {
                    Spacer()
                    Text(error.userMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Try Again") { Task { await viewModel.refresh() } }
                        .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.navBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchVM.query, prompt: "IP, MAC, or hostname")
        .overlay(alignment: .top) {
            if !searchVM.query.isEmpty {
                SearchResultsOverlay(viewModel: searchVM) { result in
                    handleClientSearchSelection(result)
                }
                .padding(.top, 8)
            }
        }
        .toolbar { sitePickerToolbar }
        .sheet(isPresented: $showingSitePicker) {
            SitePickerSheet(sites: viewModel.sites) { site in
                Task { await viewModel.selectSite(site) }
                showingSitePicker = false
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadSites() }
    }

    // MARK: - Sub-views

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a Site or Search")
                .font(.headline)
            Text("Choose a site from the filter, or search by IP, MAC, or hostname.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    @ViewBuilder
    private var clientList: some View {
        List {
            wirelessSection
            wiredSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var wirelessSection: some View {
        if !viewModel.wirelessClients.isEmpty {
            Section("Wireless (\(viewModel.wirelessClients.count))") {
                ForEach(viewModel.wirelessClients) { client in
                    NavigationLink(value: client) {
                        ClientRowView(client: client)
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
    }

    @ViewBuilder
    private var wiredSection: some View {
        if !viewModel.wiredClients.isEmpty {
            Section("Wired (\(viewModel.wiredClients.count))") {
                ForEach(viewModel.wiredClients) { client in
                    NavigationLink(value: client) {
                        ClientRowView(client: client)
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
    }

    @ToolbarContentBuilder
    private var sitePickerToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSitePicker = true
            } label: {
                Label(viewModel.selectedSite ?? "All Sites", systemImage: "building.2")
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private func handleClientSearchSelection(_ result: SearchResult) {
        searchVM.query = ""
        if case .client(let client) = result {
            searchPath.append(client)
        }
    }
}

// MARK: - ClientRowView

struct ClientRowView: View {
    let client: CentralClient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: client.connectionType == .wireless ? "wifi" : "cable.connector")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name ?? client.macAddress)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let ip = client.ipAddress {
                        Text(ip).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(client.macAddress).font(.caption).foregroundStyle(.secondary)
                }

                if client.connectionType == .wireless, let ssid = client.ssid {
                    Text(ssid).font(.caption2).foregroundStyle(.secondary)
                } else if client.connectionType == .wired, let port = client.port {
                    Text("Port \(port)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let name = client.name ?? client.macAddress
        let conn = client.connectionType == .wireless ? "wireless" : "wired"
        let ip   = client.ipAddress ?? "unknown IP"
        return "\(name), \(conn), \(ip)"
    }
}

// MARK: - SitePickerSheet

private struct SitePickerSheet: View {
    let sites: [String]
    let onSelect: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button("All Sites") { onSelect(nil) }
                    .foregroundStyle(.primary)
                if sites.isEmpty {
                    Text("Loading sites…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sites, id: \.self) { site in
                        Button(site) { onSelect(site) }
                            .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Site")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
