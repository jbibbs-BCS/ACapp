import SwiftUI

@main
struct ArubaCentralApp: App {
    @StateObject private var networkMonitor  = NetworkMonitor()
    @StateObject private var authManager     = AuthTokenManager()
    @StateObject private var apiClient: CentralAPIClient

    init() {
        let auth = AuthTokenManager()
        let regionId = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        let region   = CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
        _authManager = StateObject(wrappedValue: auth)
        _apiClient   = StateObject(wrappedValue: CentralAPIClient(authManager: auth, baseURL: region.baseURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(networkMonitor)
                .environmentObject(authManager)
                .environmentObject(apiClient)
        }
    }
}
