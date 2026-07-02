import SwiftUI

@main
struct ArubaCentralApp: App {
    @StateObject private var networkMonitor  = NetworkMonitor()
    @StateObject private var authManager     = AuthTokenManager()
    @StateObject private var apiClient: CentralAPIClient
    @StateObject private var alertsViewModel: AlertsViewModel
    @StateObject private var pushHandler     = PushNotificationHandler()

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        let auth = AuthTokenManager()
        let regionId = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        let region   = CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
        let client   = CentralAPIClient(authManager: auth, baseURL: region.baseURL)
        AlertBackgroundRefresh.shared = AlertBackgroundRefresh(apiClient: client)
        _authManager     = StateObject(wrappedValue: auth)
        _apiClient       = StateObject(wrappedValue: client)
        _alertsViewModel = StateObject(wrappedValue: AlertsViewModel(apiClient: client))
        AlertBackgroundRefresh.register()
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
            RootView()
                .environmentObject(networkMonitor)
                .environmentObject(authManager)
                .environmentObject(apiClient)
                .environmentObject(alertsViewModel)
                .environmentObject(pushHandler)
                .onAppear { appDelegate.pushHandler = pushHandler }
                .onReceive(authManager.$isAuthenticated) { authenticated in
                    if authenticated {
                        Task { await pushHandler.requestAuthorizationAndRegister() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    AlertBackgroundRefresh.scheduleNext()
                }
        }
    }
}

// MARK: - AppDelegate for APNs token callbacks

final class AppDelegate: NSObject, UIApplicationDelegate {
    var pushHandler: PushNotificationHandler?

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in pushHandler?.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in pushHandler?.didFailRegistration(error: error) }
    }
}
