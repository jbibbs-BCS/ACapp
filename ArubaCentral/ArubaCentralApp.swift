import SwiftUI

@main
struct ArubaCentralApp: App {
    @StateObject private var networkMonitor  = NetworkMonitor()
    @StateObject private var authManager     = AuthTokenManager()
    @StateObject private var apiClient: CentralAPIClient
    @StateObject private var alertsViewModel: AlertsViewModel

    init() {
        let auth = AuthTokenManager()
        let regionId = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        let region   = CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
        let client   = CentralAPIClient(authManager: auth, baseURL: region.baseURL)
        _authManager     = StateObject(wrappedValue: auth)
        _apiClient       = StateObject(wrappedValue: client)
        _alertsViewModel = StateObject(wrappedValue: AlertsViewModel(apiClient: client))
        configureNavigationBarAppearance()
        configureTabBarAppearance()
    }

    // MARK: - Global Appearance

    private func configureNavigationBarAppearance() {
        let navColor   = UIColor(Color.navBackground)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor           = navColor
        appearance.titleTextAttributes       = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes  = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().tintColor            = UIColor(Color.brandOrange)
    }

    private func configureTabBarAppearance() {
        let tabColor   = UIColor(Color.navBackground)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = tabColor
        UITabBar.appearance().standardAppearance      = appearance
        UITabBar.appearance().scrollEdgeAppearance    = appearance
        UITabBar.appearance().tintColor               = UIColor(Color.brandOrange)
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            let previewArgs = ["-PreviewMode", "-PreviewSiteDetail", "-PreviewAPDetail", "-PreviewSwitchDetail", "-PreviewAlerts"]
            if ProcessInfo.processInfo.arguments.contains(where: { previewArgs.contains($0) }) {
                PreviewRootView()
            } else {
                rootView
            }
#else
            rootView
#endif
        }
    }

    private var rootView: some View {
        RootView()
            .environmentObject(networkMonitor)
            .environmentObject(authManager)
            .environmentObject(apiClient)
            .environmentObject(alertsViewModel)
    }
}
