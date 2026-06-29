import SwiftUI

struct DevicesView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: DevicesViewModel
    @StateObject private var searchVM: GlobalSearchViewModel

    init(client: CentralAPIClientProtocol) {
        self.apiClient = client
        _viewModel = StateObject(wrappedValue: DevicesViewModel(apiClient: client))
        _searchVM  = StateObject(wrappedValue: GlobalSearchViewModel(apiClient: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.devicesState,
            content: { items in deviceList(items) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Devices")
        .searchable(text: $searchVM.query, prompt: "Name, IP, or MAC")
        .overlay(alignment: .top) {
            if !searchVM.query.isEmpty {
                SearchResultsOverlay(viewModel: searchVM) { result in
                    handleDeviceSearchSelection(result)
                }
                .padding(.top, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Type", selection: $viewModel.filterType) {
                    ForEach(DeviceFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func deviceList(_ items: [DeviceItem]) -> some View {
        if items.isEmpty {
            ContentUnavailableView.search(text: searchVM.query)
        } else {
            List(items) { item in
                switch item {
                case .ap(let ap):
                    NavigationLink(value: ap) {
                        DeviceRowView(name: item.name, model: item.model,
                                     status: item.status, uptime: item.uptime)
                    }
                case .switch_(let sw):
                    NavigationLink(value: sw) {
                        DeviceRowView(name: item.name, model: item.model,
                                     status: item.status, uptime: item.uptime)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func handleDeviceSearchSelection(_ result: SearchResult) {
        searchVM.query = ""
    }
}

#Preview {
    NavigationStack {
        DevicesView(client: PreviewMockClient())
    }
}
