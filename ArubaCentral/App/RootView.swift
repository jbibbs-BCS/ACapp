import SwiftUI

struct RootView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var apiClient: CentralAPIClient
    @EnvironmentObject private var alertsViewModel: AlertsViewModel
    @AppStorage("appearance") private var appearanceRaw: String = "system"
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                dashboardTab
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }

                devicesTab
                    .tabItem {
                        Label("Devices", systemImage: "wifi")
                    }

                clientsTab
                    .tabItem {
                        Label("Clients", systemImage: "person.2")
                    }

                AlertsView(viewModel: alertsViewModel)
                    .tabItem {
                        Label("Alerts", systemImage: alertsViewModel.unacknowledgedCount > 0 ? "bell.badge" : "bell")
                    }
                    .badge(alertsViewModel.unacknowledgedCount)

                settingsTab
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

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
                DashboardView(client: apiClient)
            } content: {
                Text("Select a site").foregroundColor(.secondary)
            }
        } else {
            NavigationStack {
                DashboardView(client: apiClient)
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
            NavigationStack {
                DevicesView(client: apiClient)
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
            NavigationStack {
                ClientsView(apiClient: apiClient)
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
