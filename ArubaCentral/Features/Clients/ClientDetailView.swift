import SwiftUI
import Combine

@MainActor
final class ClientDetailViewModel: ObservableObject {
    @Published private(set) var detailState: LoadState<CentralClient> = .idle
    @Published private(set) var connectedDeviceName: String? = nil

    let client: CentralClient
    private let apiClient: CentralAPIClientProtocol

    init(client: CentralClient, apiClient: CentralAPIClientProtocol) {
        self.client    = client
        self.apiClient = apiClient
        self.detailState = .loaded(client)
    }

    func load() async {
        guard let serial = client.associatedDeviceSerial else { return }
        if client.connectionType == .wireless {
            connectedDeviceName = (try? await apiClient.fetchAPDetail(serial: serial))?.name
        } else {
            connectedDeviceName = (try? await apiClient.fetchSwitchDetail(serial: serial))?.name
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
        .background(Color.appBackground)
        .navigationTitle(viewModel.client.name ?? viewModel.client.macAddress)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
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
                if let dev = client.associatedDeviceSerial {
                    LabeledContent("Device", value: viewModel.connectedDeviceName ?? dev)
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
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

}
