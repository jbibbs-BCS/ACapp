import XCTest
@testable import ArubaCentral

@MainActor
final class AlertsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: AlertsViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = AlertsViewModel(apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    // MARK: - load

    func testLoadSetsLoadedState() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertEqual(alerts.count, 1)
    }

    func testLoadSetsErrorOnFailure() async {
        mockClient.alertsResult = .failure(.networkError)
        await sut.load()
        guard case .error = sut.alertsState else { return XCTFail("Expected error") }
    }

    // MARK: - unacknowledgedCount

    func testUnacknowledgedCountExcludesCleared() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: true),
            makeAlert("a3", cleared: false),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 2)
    }

    func testUnacknowledgedCountZeroWhenAllCleared() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: true),
            makeAlert("a2", cleared: true),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 0)
    }

    // MARK: - acknowledge

    func testAcknowledgeCallsClearAlert() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        XCTAssertEqual(mockClient.clearAlertCallCount, 1)
    }

    func testAcknowledgeMarksAlertClearedLocally() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertTrue(alerts.first(where: { $0.id == "a1" })?.isCleared ?? false)
    }

    func testAcknowledgeDecrementsUnacknowledgedCount() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: false),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 2)
        await sut.acknowledge(alertId: "a1")
        XCTAssertEqual(sut.unacknowledgedCount, 1)
    }

    func testAcknowledgeSetsErrorOnAPIFailure() async {
        mockClient.alertsResult  = .success(.of([makeAlert("a1", cleared: false)]))
        mockClient.clearAlertError = .serverError(500)
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        XCTAssertNotNil(sut.actionError)
    }

    // MARK: - Pagination

    func testLoadNextPageAppendsAlerts() async {
        let firstPage  = (0..<100).map { makeAlert("a\($0)", cleared: false) }
        let secondPage = (100..<120).map { makeAlert("b\($0)", cleared: false) }

        mockClient.alertsResult = .success(PaginatedResponse(items: firstPage, total: 120, offset: 0, limit: 100))
        await sut.load()

        mockClient.alertsResult = .success(PaginatedResponse(items: secondPage, total: 120, offset: 100, limit: 100))
        await sut.loadNextPage()

        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertEqual(alerts.count, 120)
    }

    func testLoadNextPageDoesNothingWhenNoMore() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        let callsBefore = mockClient.fetchAlertsCallCount
        await sut.loadNextPage()
        XCTAssertEqual(mockClient.fetchAlertsCallCount, callsBefore)
    }

    // MARK: - navigateTo

    func testNavigateToAlertIdSelectsAlert() async {
        let alert = makeAlert("target-id", cleared: false)
        mockClient.alertsResult = .success(.of([alert]))
        await sut.load()
        sut.navigateTo(alertId: "target-id")
        XCTAssertEqual(sut.selectedAlertId, "target-id")
    }

    func testNavigateToUnknownAlertIdLoadsFirst() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        sut.navigateTo(alertId: "unknown-id")
        // Should load but not crash
        XCTAssertEqual(sut.selectedAlertId, "unknown-id")
    }

    // MARK: - Helpers

    private func makeAlert(_ id: String, cleared: Bool) -> CentralAlert {
        CentralAlert(id: id, name: "AP Down", severity: .critical,
                     description: "AP unreachable", deviceSerial: "SN001",
                     siteName: "HQ", createdAt: Date(), isCleared: cleared)
    }
}
