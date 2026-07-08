import SwiftUI

struct SwitchDetailView: View {
    @StateObject private var viewModel: SwitchDetailViewModel
    @State private var selectedTab = 0

    init(sw: CentralSwitch, apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SwitchDetailViewModel(sw: sw, apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandedTabPicker(tabs: ["Overview", "Ports", "VLANs"], selection: $selectedTab)
                .padding(.vertical, 8)
                .background(Color.appBackground)

            Group {
                switch selectedTab {
                case 0: overviewTab
                case 1: portsTab
                default: vlansTab
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(viewModel.sw.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .alert("Action Failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError?.userMessage ?? "")
        }
    }

    @ViewBuilder private var overviewTab: some View {
        LoadStateView(state: viewModel.detailState,
                      content: { sw in SwitchOverviewContent(sw: sw) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder private var portsTab: some View {
        LoadStateView(state: viewModel.portsState,
                      content: { ports in PortDiagramView(ports: ports, onBounce: { _ in }) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder private var vlansTab: some View {
        LoadStateView(state: viewModel.vlansState,
                      content: { vlans in
                          List(vlans) { vlan in
                              VLANRowView(vlan: vlan)
                                  .listRowBackground(Color.cardBackground)
                          }
                          .listStyle(.insetGrouped)
                          .scrollContentBackground(.hidden)
                          .background(Color.appBackground)
                      },
                      retry: { Task { await viewModel.load() } })
    }
}

// MARK: - Sub-views

private struct SwitchOverviewContent: View {
    let sw: CentralSwitch
    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Model",  value: sw.model)
                LabeledContent("Serial", value: sw.serial)
                if let fw  = sw.firmware   { LabeledContent("Firmware", value: fw) }
                if let ip  = sw.ipAddress  { LabeledContent("IP",       value: ip) }
                if let mac = sw.macAddress { LabeledContent("MAC",      value: mac) }
            }
            .listRowBackground(Color.cardBackground)
            Section("Status") {
                LabeledContent("Status", value: sw.status == .up ? "Online" : "Offline")
                if let uptime = sw.uptime { LabeledContent("Uptime", value: uptimeString(uptime)) }
                if let site = sw.siteName { LabeledContent("Site",   value: site) }
            }
            .listRowBackground(Color.cardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func uptimeString(_ s: Int) -> String {
        let d = s / 86400; let h = (s % 86400) / 3600; let m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct VLANRowView: View {
    let vlan: VLAN
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("VLAN \(vlan.vlanId)").font(.headline)
                if let name = vlan.name { Text(name).foregroundStyle(.secondary) }
            }
            if !vlan.taggedPorts.isEmpty {
                Text("Tagged: \(vlan.taggedPorts.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !vlan.untaggedPorts.isEmpty {
                Text("Untagged: \(vlan.untaggedPorts.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 2)
    }
}
