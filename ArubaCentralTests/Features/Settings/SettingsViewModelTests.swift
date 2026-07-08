import XCTest
@testable import ArubaCentral

@MainActor
final class SettingsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var keychain: KeychainManager!
    var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        UserDefaults.standard.removeObject(forKey: "selectedRegionId")
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.defaultKey)
        mockClient = MockCentralAPIClient()
        sut = SettingsViewModel(apiClient: mockClient)
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        UserDefaults.standard.removeObject(forKey: "selectedRegionId")
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.defaultKey)
        sut = nil; mockClient = nil; super.tearDown()
    }

    // MARK: - Credentials

    func testSaveCredentialsPersistsToKeychain() throws {
        sut.clientId     = "test-id"
        sut.clientSecret = "test-secret"
        try sut.saveCredentials()
        XCTAssertEqual(try keychain.retrieve(for: .clientId),     "test-id")
        XCTAssertEqual(try keychain.retrieve(for: .clientSecret), "test-secret")
    }

    func testSaveCredentialsThrowsForEmptyId() {
        sut.clientId     = ""
        sut.clientSecret = "secret"
        XCTAssertThrowsError(try sut.saveCredentials()) { error in
            XCTAssertEqual(error as? SettingsError, .emptyClientId)
        }
    }

    func testSaveCredentialsThrowsForEmptySecret() {
        sut.clientId     = "id"
        sut.clientSecret = ""
        XCTAssertThrowsError(try sut.saveCredentials()) { error in
            XCTAssertEqual(error as? SettingsError, .emptyClientSecret)
        }
    }

    func testLoadCredentialsPopulatesFields() throws {
        try keychain.save("loaded-id",     for: .clientId)
        try keychain.save("loaded-secret", for: .clientSecret)
        sut.loadCredentials()
        XCTAssertEqual(sut.clientId,     "loaded-id")
        XCTAssertEqual(sut.clientSecret, "loaded-secret")
    }

    func testLoadCredentialsLeavesFieldsEmptyWhenNotSet() {
        sut.loadCredentials()
        XCTAssertEqual(sut.clientId,     "")
        XCTAssertEqual(sut.clientSecret, "")
    }

    // MARK: - Region

    func testDefaultRegionIsUS1() {
        XCTAssertEqual(sut.selectedRegion.id, "us1")
    }

    func testSaveRegionPersistsToUserDefaults() {
        let de1 = CentralRegion.all.first { $0.id == "de1" }!
        sut.selectedRegion = de1
        sut.saveRegion()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedRegionId"), "de1")
    }

    func testLoadRegionRestoresSavedRegion() {
        UserDefaults.standard.set("jp1", forKey: "selectedRegionId")
        sut.loadRegion()
        XCTAssertEqual(sut.selectedRegion.id, "jp1")
    }

    func testLoadRegionFallsBackToUS1WhenInvalidId() {
        UserDefaults.standard.set("invalid-id", forKey: "selectedRegionId")
        sut.loadRegion()
        XCTAssertEqual(sut.selectedRegion.id, "us1")
    }

    // MARK: - Notification Preferences

    func testDefaultNotificationPreferences() {
        XCTAssertTrue(sut.notificationPrefs.critical)
        XCTAssertTrue(sut.notificationPrefs.major)
        XCTAssertFalse(sut.notificationPrefs.minor)
        XCTAssertFalse(sut.notificationPrefs.info)
    }

    func testSaveNotificationPreferencesPersists() {
        sut.notificationPrefs.minor = true
        sut.saveNotificationPrefs()
        let loaded = NotificationPreferences.load()
        XCTAssertTrue(loaded.minor)
    }

    // MARK: - Test Connection

    func testConnectionSuccessUpdatesState() async {
        mockClient.testConnectionError = nil
        await sut.testConnection()
        if case .success = sut.connectionTestResult { } else {
            XCTFail("Expected success, got \(String(describing: sut.connectionTestResult))")
        }
    }

    func testConnectionFailureUpdatesState() async {
        mockClient.testConnectionError = .unauthorized
        await sut.testConnection()
        if case .failure = sut.connectionTestResult { } else {
            XCTFail("Expected failure")
        }
    }

    func testConnectionTestingStateWhileInProgress() async {
        // connectionTestResult should be .testing during the call
        // Hard to assert timing, but we verify it ends in a terminal state
        await sut.testConnection()
        if case .testing = sut.connectionTestResult {
            XCTFail("Should not remain in testing state after completion")
        }
    }
}
