import SwiftUI

struct RootView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var apiClient: CentralAPIClient
    @EnvironmentObject private var alertsViewModel: AlertsViewModel
    @AppStorage("appearance") private var appearanceRaw: String = "system"
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab = 0
    @State private var devicesPath = NavigationPath()
    @State private var clientsPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                dashboardTab
                    .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                    .tag(0)

                devicesTab
                    .tabItem { Label("Devices", systemImage: "wifi") }
                    .tag(1)

                clientsTab
                    .tabItem { Label("Clients", systemImage: "person.2") }
                    .tag(2)

                AlertsView(viewModel: alertsViewModel)
                    .tabItem {
                        Label("Alerts", systemImage: alertsViewModel.unacknowledgedCount > 0 ? "bell.badge" : "bell")
                    }
                    .badge(alertsViewModel.unacknowledgedCount)
                    .tag(3)

                settingsTab
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(4)
            }
            .tabViewStyle(.tabBarOnly)
            .toolbarBackground(Color.navBackground, for: .tabBar)
            .tint(Color.brandOrange)

            if !networkMonitor.isConnected {
                OfflineBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .preferredColorScheme(colorScheme(for: appearanceRaw))
    }

    @ViewBuilder
    private var dashboardTab: some View {
        if sizeClass == .regular {
            SplitTabView {
                DashboardView(client: apiClient, onAlertsTapped: { selectedTab = 3 })
            } content: {
                Text("Select a site").foregroundColor(.secondary)
            }
        } else {
            NavigationStack {
                DashboardView(client: apiClient, onAlertsTapped: { selectedTab = 3 })
                    .navigationDestination(for: AccessPoint.self) { ap in
                        APDetailView(ap: ap, apiClient: apiClient)
                    }
                    .navigationDestination(for: CentralSwitch.self) { sw in
                        SwitchDetailView(sw: sw, apiClient: apiClient)
                    }
            }
        }
    }

    @ViewBuilder
    private var devicesTab: some View {
        if sizeClass == .regular {
            GeometryReader { geo in
                if LayoutHelper.isThreeColumn(width: geo.size.width) {
                    ThreeColumnDevicesView(apiClient: apiClient)
                } else {
                    SplitTabView {
                        DevicesView(client: apiClient)
                    } content: {
                        Text("Select a device").foregroundColor(.secondary)
                    }
                }
            }
        } else {
            NavigationStack(path: $devicesPath) {
                DevicesView(client: apiClient, searchPath: $devicesPath)
                    .navigationDestination(for: AccessPoint.self) { ap in
                        APDetailView(ap: ap, apiClient: apiClient)
                    }
                    .navigationDestination(for: CentralSwitch.self) { sw in
                        SwitchDetailView(sw: sw, apiClient: apiClient)
                    }
            }
        }
    }

    @ViewBuilder
    private var clientsTab: some View {
        if sizeClass == .regular {
            SplitTabView {
                ClientsView(apiClient: apiClient)
            } content: {
                Text("Select a client").foregroundColor(.secondary)
            }
        } else {
            NavigationStack(path: $clientsPath) {
                ClientsView(apiClient: apiClient, searchPath: $clientsPath)
                    .navigationDestination(for: CentralClient.self) { client in
                        ClientDetailView(client: client, apiClient: apiClient)
                    }
            }
        }
    }

    @ViewBuilder
    private var settingsTab: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                SettingsView(apiClient: apiClient)
                    .navigationSplitViewColumnWidth(320)
            } detail: {
                Text("").hidden()
            }
        } else {
            NavigationStack {
                SettingsView(apiClient: apiClient)
            }
        }
    }

    private func colorScheme(for raw: String) -> ColorScheme? {
        switch raw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

#Preview {
    let client = CentralAPIClient(authManager: AuthTokenManager())
    RootView()
        .environmentObject(NetworkMonitor())
        .environmentObject(client)
        .environmentObject(AlertsViewModel(apiClient: client))
}

// MARK: - Preview Mode (launched with -PreviewMode / -PreviewSiteDetail / -PreviewAPDetail / -PreviewSwitchDetail)

#if DEBUG
struct PreviewRootView: View {
    private let mock = PreviewMockClient()
    @StateObject private var alertsVM: AlertsViewModel

    private static let args = ProcessInfo.processInfo.arguments

    init() {
        let m = PreviewMockClient()
        _alertsVM = StateObject(wrappedValue: AlertsViewModel(apiClient: m))
    }

    var body: some View {
        if Self.args.contains("-PreviewSiteDetail") {
            NavigationStack {
                SiteDetailView(
                    site: Site(id: "s1", name: "HQ Campus", healthPct: 95,
                               deviceCount: 28, clientCount: 310, alertCount: 0),
                    apiClient: mock
                )
            }
        } else if Self.args.contains("-PreviewAPDetail") {
            NavigationStack {
                APDetailView(
                    ap: AccessPoint(serial: "AP001", name: "AP-Lobby", model: "AP-515",
                                    status: .up, ipAddress: "10.0.1.10",
                                    macAddress: "AA:BB:CC:DD:EE:01", firmware: "10.4.1.0-dev",
                                    uptime: 864000, site: "HQ Campus", clientCount: 24),
                    apiClient: mock
                )
            }
        } else if Self.args.contains("-PreviewSwitchDetail") {
            NavigationStack {
                SwitchDetailView(
                    sw: CentralSwitch(serial: "SW001", name: "SW-Core-1",
                                      model: "CX 6300M 24-port", status: .up,
                                      ipAddress: "10.0.0.1", macAddress: "BB:CC:DD:EE:FF:01",
                                      firmware: "10.10.1040", uptime: 2592000,
                                      site: "HQ Campus", stackId: nil),
                    apiClient: mock
                )
            }
        } else if Self.args.contains("-PreviewAlerts") {
            AlertsView(viewModel: alertsVM)
        } else {
            // Default: -PreviewMode shows Dashboard inside a TabView so the tab bar is visible
            TabView {
                NavigationStack {
                    DashboardView(client: mock, onAlertsTapped: {})
                        .navigationDestination(for: Site.self) { site in
                            SiteDetailView(site: site, apiClient: mock)
                        }
                        .navigationDestination(for: AccessPoint.self) { ap in
                            APDetailView(ap: ap, apiClient: mock)
                        }
                        .navigationDestination(for: CentralSwitch.self) { sw in
                            SwitchDetailView(sw: sw, apiClient: mock)
                        }
                }
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }

                NavigationStack { DevicesView(client: mock) }
                    .tabItem { Label("Devices", systemImage: "wifi") }

                AlertsView(viewModel: alertsVM)
                    .tabItem { Label("Alerts", systemImage: "bell") }

                NavigationStack { SettingsView(apiClient: mock) }
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .tabViewStyle(.tabBarOnly)
            .toolbarBackground(Color.navBackground, for: .tabBar)
            .tint(Color.brandOrange)
        }
    }
}
#endif
