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
        .background(Color.appBackground)
        .navigationTitle("Devices")
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
                case .stackMember(let member, _):
                    StackMemberRowView(member: member)
                        .padding(.leading, 16)
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
    }
}

private struct StackMemberRowView: View {
    let member: StackMember
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.serial)
                        .font(.subheadline)
                    if let role = member.role {
                        Text(role.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                }
                if let model = member.model {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            DeviceStatusBadge(status: member.status)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.role.map { $0.capitalized + " " } ?? "")Stack member \(member.serial)")
    }
}

#Preview {
    NavigationStack {
        DevicesView(client: PreviewMockClient())
    }
}
