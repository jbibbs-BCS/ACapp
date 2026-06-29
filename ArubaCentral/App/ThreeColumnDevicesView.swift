import SwiftUI
import Combine

final class ThreeColumnCoordinator: ObservableObject {
    @Published var selectedSiteName: String?
    @Published var selectedDeviceSerial: String?
}

struct ThreeColumnDevicesView: View {
    @StateObject private var viewModel: DevicesViewModel
    @StateObject private var coordinator = ThreeColumnCoordinator()

    init(apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DevicesViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            siteListColumn
                .navigationTitle("Sites")
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 320)
        } content: {
            deviceListColumn
                .navigationTitle("Devices")
                .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 440)
        } detail: {
            deviceDetailColumn
        }
        .environmentObject(coordinator)
    }

    @ViewBuilder
    private var siteListColumn: some View {
        switch viewModel.devicesState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let devices):
            let sites = Array(Set(devices.compactMap(\.siteName))).sorted()
            List(sites, id: \.self, selection: $coordinator.selectedSiteName) { site in
                Label(site, systemImage: "building.2")
            }
        case .error(let err):
            Text(err.localizedDescription)
                .foregroundColor(.red)
                .padding()
        }
    }

    @ViewBuilder
    private var deviceListColumn: some View {
        if let siteName = coordinator.selectedSiteName {
            let devices = viewModel.devices(forSite: siteName)
            List(devices, id: \.serial, selection: $coordinator.selectedDeviceSerial) { device in
                HStack {
                    Image(systemName: device.deviceType == .ap ? "wifi" : "server.rack")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(device.name).font(.body)
                        if let site = device.siteName {
                            Text(site).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Select a Site")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var deviceDetailColumn: some View {
        if let serial = coordinator.selectedDeviceSerial,
           let device = viewModel.device(withSerial: serial) {
            switch device {
            case .ap(let ap):
                APDetailView(ap: ap, apiClient: viewModel.apiClient)
            case .switch_(let sw):
                SwitchDetailView(sw: sw, apiClient: viewModel.apiClient)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Select a Device")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
