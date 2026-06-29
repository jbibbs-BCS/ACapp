import XCTest
@testable import ArubaCentral

@MainActor
final class PushNotificationHandlerTests: XCTestCase {

    var sut: PushNotificationHandler!

    override func setUp() {
        super.setUp()
        sut = PushNotificationHandler()
    }

    override func tearDown() { sut = nil; super.tearDown() }

    // MARK: - Payload parsing

    func testParseAlertIdFromPayload() {
        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-001", "aps": ["alert": ["title": "AP Down"]]]
        let alertId = sut.alertId(from: userInfo)
        XCTAssertEqual(alertId, "ALT-001")
    }

    func testParseAlertIdMissingReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": ["title": "AP Down"]]]
        let alertId = sut.alertId(from: userInfo)
        XCTAssertNil(alertId)
    }

    func testParseSeverityFromPayload() {
        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-001", "severity": "Critical"]
        let severity = sut.severity(from: userInfo)
        XCTAssertEqual(severity, .critical)
    }

    func testParseSeverityDefaultsToInfoForUnknown() {
        let userInfo: [AnyHashable: Any] = ["severity": "Unknown"]
        let severity = sut.severity(from: userInfo)
        XCTAssertEqual(severity, .info)
    }

    // MARK: - Notification filtering

    func testShouldShowNotificationRespectsCriticalPref() {
        var prefs = NotificationPreferences()
        prefs.critical = false
        XCTAssertFalse(sut.shouldShow(severity: .critical, prefs: prefs))
    }

    func testShouldShowNotificationWhenEnabled() {
        var prefs = NotificationPreferences()
        prefs.critical = true
        XCTAssertTrue(sut.shouldShow(severity: .critical, prefs: prefs))
    }

    func testShouldShowMinorWhenDisabled() {
        var prefs = NotificationPreferences()
        prefs.minor = false
        XCTAssertFalse(sut.shouldShow(severity: .minor, prefs: prefs))
    }

    func testShouldShowInfoWhenEnabled() {
        var prefs = NotificationPreferences()
        prefs.info = true
        XCTAssertTrue(sut.shouldShow(severity: .info, prefs: prefs))
    }

    // MARK: - NotificationCenter posting

    func testHandleNotificationPostsToNotificationCenter() {
        let expectation = XCTestExpectation(description: "NotificationCenter post received")
        var receivedAlertId: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .didReceiveAlertNotification,
            object: nil,
            queue: .main
        ) { note in
            receivedAlertId = note.userInfo?["alert_id"] as? String
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-XYZ", "severity": "Critical"]
        sut.handleIncomingNotification(userInfo: userInfo)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedAlertId, "ALT-XYZ")
    }
}
