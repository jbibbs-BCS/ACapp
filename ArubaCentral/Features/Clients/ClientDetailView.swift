import SwiftUI
import Combine

@MainActor
final class ClientDetailViewModel: ObservableObject {
    @Published private(set) var detailState: LoadState<CentralClient> = .idle
    @Published var actionError: APIError? = nil
    @Published var showingDisconnectConfirm = false

    let client: CentralClient
    private let apiClient: CentralAPIClientProtocol

    init(client: CentralClient, apiClient: CentralAPIClientProtocol) {
        self.client    = client
        self.apiClient = apiClient
    }

    func load() async {
        detailState = .loading
        do {
            let detail = try await apiClient.fetchClientDetail(macAddress: client.macAddress)
            detailState = .loaded(detail)
        } catch let error as APIError {
            detailState = .error(error)
        } catch {
            detailState = .error(.networkError)
        }
    }

    func disconnect() async {
        // NOTE: Per-client disconnect endpoint TBC (open item #2).
        // Fallback: disconnect all clients from the associated AP.
        guard let apSerial = client.associatedDeviceSerial else { return }
        do {
            try await apiClient.disconnectAllClientsFromAP(serial: apSerial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }
}

struct ClientDetailView: View {
    @StateObject private var viewModel: ClientDetailViewModel

    init(client: CentralClient, apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(client: client,
                                                                      apiClient: apiClient))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.detailState,
            content: { detail in detailContent(detail) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle(viewModel.client.name ?? viewModel.client.macAddress)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { disconnectButton }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Action Failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError?.userMessage ?? "") }
        .confirmationDialog("Disconnect client?",
                            isPresented: $viewModel.showingDisconnectConfirm,
                            titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task { await viewModel.disconnect() }
            }
        } message: {
            Text("This will disconnect the client from the network. (Note: currently disconnects all clients on the AP — open item #2)")
        }
    }

    @ViewBuilder
    private func detailContent(_ client: CentralClient) -> some View {
        List {
            Section("Identity") {
                if let name = client.name { LabeledContent("Name",    value: name) }
                LabeledContent("MAC",     value: client.macAddress)
                if let ip = client.ipAddress { LabeledContent("IP",  value: ip) }
            }
            Section("Connection") {
                LabeledContent("Type",  value: client.connectionType == .wireless ? "Wireless" : "Wired")
                if let ssid = client.ssid    { LabeledContent("SSID",   value: ssid) }
                if let port = client.port    { LabeledContent("Port",   value: port) }
                if let vlan = client.vlan    { LabeledContent("VLAN",   value: "\(vlan)") }
                if let dev  = client.associatedDeviceSerial {
                    LabeledContent("Device", value: dev)
                }
                if let site = client.siteName { LabeledContent("Site",   value: site) }
            }
            if client.connectionType == .wireless {
                Section("Signal") {
                    if let rssi = client.signalStrength {
                        LabeledContent("Signal",   value: "\(rssi) dBm")
                    }
                    if let tx = client.txDataRate {
                        LabeledContent("TX Rate",  value: String(format: "%.0f Mbps", tx))
                    }
                    if let rx = client.rxDataRate {
                        LabeledContent("RX Rate",  value: String(format: "%.0f Mbps", rx))
                    }
                }
            }
            if let connectedAt = client.connectedAt {
                Section("Session") {
                    LabeledContent("Connected", value: connectedAt.formatted(.relative(presentation: .named)))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var disconnectButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(role: .destructive) {
                viewModel.showingDisconnectConfirm = true
            } label: {
                Label("Disconnect", systemImage: "wifi.slash")
            }
        }
    }
}
