import SwiftUI

struct DevicesView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: DevicesViewModel
    @StateObject private var searchVM: GlobalSearchViewModel
    @Binding private var searchPath: NavigationPath

    init(client: CentralAPIClientProtocol,
         searchPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.apiClient = client
        _viewModel = StateObject(wrappedValue: DevicesViewModel(apiClient: client))
        _searchVM  = StateObject(wrappedValue: GlobalSearchViewModel(apiClient: client))
        _searchPath = searchPath
    }

    var body: some View {
        LoadStateView(
            state: viewModel.devicesState,
            content: { items in deviceList(items) },
            retry: { Task { await viewModel.load() } }
        )
        .background(Color.appBackground)
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.navBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No results for \"\(searchVM.query)\"")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                switch item {
                case .ap(let ap):
                    NavigationLink(value: ap) {
                        DeviceRowView(name: item.name, model: item.model,
                                     status: item.status, uptime: item.uptime)
                    }
                    .listRowBackground(Color.cardBackground)
                case .switch_(let sw):
                    NavigationLink(value: sw) {
                        DeviceRowView(name: item.name, model: item.model,
                                     status: item.status, uptime: item.uptime)
                    }
                    .listRowBackground(Color.cardBackground)
                case .stack(let stack):
                    NavigationLink(value: stack.representative) {
                        StackRowView(stack: stack)
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    private func handleDeviceSearchSelection(_ result: SearchResult) {
        searchVM.query = ""
        switch result {
        case .ap(let ap):      searchPath.append(ap)
        case .switch_(let sw): searchPath.append(sw)
        case .client:          break   // no client destination on the Devices tab
        }
    }
}

#Preview {
    NavigationStack {
        DevicesView(client: PreviewMockClient())
    }
}
