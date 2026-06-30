import Foundation
import Combine

enum SettingsError: Error, Equatable {
    case emptyClientId
    case emptyClientSecret
}

enum ConnectionTestResult {
    case idle
    case testing
    case success(tokenExpiry: Date)
    case failure(APIError)
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var clientId:     String = ""
    @Published var clientSecret: String = ""
    @Published var selectedRegion: CentralRegion = CentralRegion.defaultRegion
    @Published var notificationPrefs = NotificationPreferences.load()
    @Published private(set) var connectionTestResult: ConnectionTestResult = .idle
    @Published var credentialsSaved = false

    private let keychain = KeychainManager()
    private let client: CentralAPIClientProtocol

    init(apiClient: CentralAPIClientProtocol) {
        self.client = apiClient
        loadCredentials()
        loadRegion()
    }

    // MARK: - Credentials

    func loadCredentials() {
        clientId     = (try? keychain.retrieve(for: .clientId))     ?? ""
        clientSecret = (try? keychain.retrieve(for: .clientSecret)) ?? ""
    }

    func saveCredentials() throws {
        guard !clientId.isEmpty     else { throw SettingsError.emptyClientId }
        guard !clientSecret.isEmpty else { throw SettingsError.emptyClientSecret }
        try keychain.save(clientId,     for: .clientId)
        try keychain.save(clientSecret, for: .clientSecret)
        credentialsSaved = true
    }

    // MARK: - Region

    func loadRegion() {
        let id = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        selectedRegion = CentralRegion.all.first { $0.id == id } ?? CentralRegion.defaultRegion
    }

    func saveRegion() {
        UserDefaults.standard.set(selectedRegion.id, forKey: "selectedRegionId")
        client.updateBaseURL(selectedRegion.baseURL)
    }

    // MARK: - Notification preferences

    func saveNotificationPrefs() {
        notificationPrefs.save()
    }

    // MARK: - Test connection

    func testConnection() async {
        connectionTestResult = .testing
        do {
            try await client.testConnection()
            let expiry = (try? keychain.retrieve(for: .tokenExpiry))
                .flatMap { Double($0) }
                .map { Date(timeIntervalSince1970: $0) }
                ?? Date().addingTimeInterval(7199)
            connectionTestResult = .success(tokenExpiry: expiry)
        } catch let error as APIError {
            connectionTestResult = .failure(error)
        } catch {
            connectionTestResult = .failure(.networkError)
        }
    }
}
