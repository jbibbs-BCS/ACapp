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
        _authManager     = StateObject(wrappedValue: auth)
        _apiClient       = StateObject(wrappedValue: client)
        _alertsViewModel = StateObject(wrappedValue: AlertsViewModel(apiClient: client))
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
