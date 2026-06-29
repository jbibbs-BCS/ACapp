import XCTest
@testable import ArubaCentral

final class AlertBackgroundRefreshTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: AlertBackgroundRefresh!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = AlertBackgroundRefresh(apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testFetchNewAlertsReturnsUnacknowledgedAlerts() async throws {
        let alerts = [
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: true),
            makeAlert("a3", cleared: false),
        ]
        mockClient.alertsResult = .success(.of(alerts))
        let unread = try await sut.fetchUnacknowledgedAlerts()
        XCTAssertEqual(unread.count, 2)
        XCTAssertTrue(unread.allSatisfy { !$0.isCleared })
    }

    func testFetchAlertsThrowsOnAPIError() async {
        mockClient.alertsResult = .failure(.networkError)
        do {
            _ = try await sut.fetchUnacknowledgedAlerts()
            XCTFail("Expected throw")
        } catch { }
    }

    func testFilterByPreferencesCriticalEnabled() {
        var prefs = NotificationPreferences()
        prefs.critical = true
        prefs.major    = false
        let alerts = [
            makeAlert("a1", cleared: false, severity: .critical),
            makeAlert("a2", cleared: false, severity: .major),
        ]
        let filtered = sut.filter(alerts: alerts, by: prefs)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].severity, .critical)
    }

    func testFilterByPreferencesAllDisabled() {
        var prefs = NotificationPreferences()
        prefs.critical = false; prefs.major = false; prefs.minor = false; prefs.info = false
        let alerts = [makeAlert("a1", cleared: false, severity: .critical)]
        XCTAssertTrue(sut.filter(alerts: alerts, by: prefs).isEmpty)
    }

    private func makeAlert(_ id: String, cleared: Bool, severity: AlertSeverity = .critical) -> CentralAlert {
        CentralAlert(id: id, name: "Alert \(id)", severity: severity,
                     description: nil, deviceSerial: nil, siteName: nil,
                     createdAt: Date(), isCleared: cleared)
    }
}
