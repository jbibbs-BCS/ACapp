import SwiftUI

struct DevicesView: View {
    @StateObject private var viewModel: DevicesViewModel
    @State private var searchText = ""

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DevicesViewModel(apiClient: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.devicesState,
            content: { items in deviceList(items) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Devices")
        .searchable(text: $searchText, prompt: "Name, IP, or MAC")
        .onChange(of: searchText) { _, query in
            Task { await viewModel.search(query: query) }
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
            ContentUnavailableView.search(text: searchText)
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
}

#Preview {
    NavigationStack {
        DevicesView(client: PreviewMockClient())
    }
}
