import SwiftUI

struct APDetailView: View {
    @StateObject private var viewModel: APDetailViewModel
    @State private var selectedTab = 0

    init(ap: AccessPoint, apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: APDetailViewModel(ap: ap, apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: $selectedTab)
                .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case 0: overviewTab
                case 1: radiosTab
                default: clientsTab
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(viewModel.ap.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { actionMenu }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Action Failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError?.userMessage ?? "")
        }
        .confirmationDialog("Reboot \(viewModel.ap.name)?",
                            isPresented: $viewModel.showingRebootConfirm,
                            titleVisibility: .visible) {
            Button("Reboot", role: .destructive) { Task { await viewModel.rebootAP() } }
        } message: { Text("The AP will disconnect all clients briefly.") }
        .confirmationDialog("Blink LED on \(viewModel.ap.name)?",
                            isPresented: $viewModel.showingBlinkConfirm,
                            titleVisibility: .visible) {
            Button("Blink LED") { Task { await viewModel.blinkLED() } }
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var overviewTab: some View {
        LoadStateView(state: viewModel.detailState,
                      content: { ap in APOverviewContent(ap: ap) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder
    private var radiosTab: some View {
        LoadStateView(state: viewModel.radiosState,
                      content: { radios in
                          List(radios) { radio in
                              RadioRowView(radio: radio)
                                  .listRowBackground(Color.cardBackground)
                          }
                          .listStyle(.insetGrouped)
                          .scrollContentBackground(.hidden)
                          .background(Color.appBackground)
                      },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder
    private var clientsTab: some View {
        LoadStateView(state: viewModel.clientsState,
                      content: clientsContent,
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder
    private func clientsContent(_ clients: [CentralClient]) -> some View {
        if clients.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "person.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                if let count = viewModel.ap.clientCount, count > 0 {
                    Text("\(count) client(s) connected")
                        .font(.headline)
                    Text("Client details are not available for this AP.\nThe API does not support per-device filtering.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else {
                    Text("No clients connected")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else {
            List(clients) { client in
                APClientRowView(client: client)
                    .listRowBackground(Color.cardBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    @ToolbarContentBuilder
    private var actionMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { viewModel.showingRebootConfirm = true } label: {
                    Label("Reboot AP", systemImage: "arrow.clockwise")
                }
                Button { viewModel.showingBlinkConfirm = true } label: {
                    Label("Blink LED", systemImage: "light.beacon.max")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Sub-views

private struct APOverviewContent: View {
    let ap: AccessPoint
    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Model", value: ap.model)
                monoRow("Serial",   ap.serial)
                if let fw = ap.firmware  { monoRow("Firmware", fw) }
                if let ip = ap.ipAddress { monoRow("IP",       ip) }
                monoRow("MAC", ap.macAddress)
            }
            .listRowBackground(Color.cardBackground)
            Section("Status") {
                LabeledContent("Status", value: ap.status == .up ? "Online" : "Offline")
                if let uptime = ap.uptime {
                    LabeledContent("Uptime", value: uptimeString(uptime))
                }
                if let count = ap.clientCount {
                    LabeledContent("Clients", value: "\(count)")
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func monoRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func uptimeString(_ seconds: Int) -> String {
        let d = seconds / 86400; let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct RadioRowView: View {
    let radio: Radio
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(radio.band).font(.headline)
                Spacer()
                Text("\(radio.clientCount) clients").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let ch = radio.channel  { Label("Ch \(ch)", systemImage: "dot.radiowaves.left.and.right") }
                if let ssid = radio.ssid   { Label(ssid,       systemImage: "wifi") }
                if let tp = radio.throughput { Label(String(format: "%.0f Mbps", tp), systemImage: "arrow.up.arrow.down") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct APClientRowView: View {
    let client: CentralClient
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(client.name ?? "Unknown").font(.subheadline)
                Text(client.ipAddress ?? "—").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(client.connectionType == .wireless ? "Wireless" : "Wired")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
