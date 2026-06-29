import SwiftUI

struct RootView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var apiClient: CentralAPIClient
    @AppStorage("appearance") private var appearanceRaw: String = "system"

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                NavigationStack {
                    DashboardView(client: apiClient)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

                NavigationStack {
                    DevicesPlaceholder()
                }
                .tabItem {
                    Label("Devices", systemImage: "wifi")
                }

                NavigationStack {
                    ClientsPlaceholder()
                }
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }

                NavigationStack {
                    AlertsPlaceholder()
                }
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

                NavigationStack {
                    SettingsPlaceholder()
                }
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

    private func colorScheme(for raw: String) -> ColorScheme? {
        switch raw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

#Preview {
    RootView()
        .environmentObject(NetworkMonitor())
        .environmentObject(CentralAPIClient(authManager: AuthTokenManager()))
}
