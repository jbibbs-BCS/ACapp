import XCTest
@testable import ArubaCentral

@MainActor
final class SiteDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: SiteDetailViewModel!
    let site = Site(id: "s1", name: "HQ", healthScore: 90, apCount: 2, switchCount: 1, clientCount: 50)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = SiteDetailViewModel(site: site, client: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialAPsStateIsIdle() {
        if case .idle = sut.apsState { } else {
            XCTFail("Expected idle")
        }
    }

    func testInitialSwitchesStateIsIdle() {
        if case .idle = sut.switchesState { } else {
            XCTFail("Expected idle")
        }
    }

    // MARK: - load()

    func testLoadFetchesAPsForSite() async {
        let aps = [makeAP(serial: "AP1"), makeAP(serial: "AP2")]
        mockClient.apsResult = .success(PaginatedResponse.of(aps))
        mockClient.switchesResult = .success(.empty())

        await sut.load()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
    }

    func testLoadFetchesSwitchesForSite() async {
        mockClient.apsResult = .success(.empty())
        let switches = [makeSW(serial: "SW1")]
        mockClient.switchesResult = .success(PaginatedResponse.of(switches))

        await sut.load()

        guard case .loaded(let result) = sut.switchesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 1)
    }

    func testLoadSetsAPsErrorOnFailure() async {
        mockClient.apsResult = .failure(.serverError(503))
        mockClient.switchesResult = .success(.empty())

        await sut.load()

        guard case .error(let error) = sut.apsState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .serverError(503))
    }

    // MARK: - Pagination

    func testLoadNextAPPageAppendsItems() async {
        let firstPage  = (0..<100).map { makeAP(serial: "AP\($0)") }
        let secondPage = (100..<150).map { makeAP(serial: "AP\($0)") }

        mockClient.apsResult = .success(PaginatedResponse(items: firstPage, total: 150, offset: 0, limit: 100))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        mockClient.apsResult = .success(PaginatedResponse(items: secondPage, total: 150, offset: 100, limit: 100))
        await sut.loadNextAPPage()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 150)
    }

    func testLoadNextAPPageDoesNothingWhenNoMore() async {
        let aps = [makeAP(serial: "AP1")]
        mockClient.apsResult = .success(PaginatedResponse.of(aps))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        let callsBefore = mockClient.fetchAPsCallCount
        await sut.loadNextAPPage()
        XCTAssertEqual(mockClient.fetchAPsCallCount, callsBefore,
                       "Should not fetch when hasMore is false")
    }

    func testLoadNextSwitchPageAppendsItems() async {
        let firstPage  = (0..<100).map { makeSW(serial: "SW\($0)") }
        let secondPage = (100..<120).map { makeSW(serial: "SW\($0)") }

        mockClient.apsResult = .success(.empty())
        mockClient.switchesResult = .success(PaginatedResponse(items: firstPage, total: 120, offset: 0, limit: 100))
        await sut.load()

        mockClient.switchesResult = .success(PaginatedResponse(items: secondPage, total: 120, offset: 100, limit: 100))
        await sut.loadNextSwitchPage()

        guard case .loaded(let result) = sut.switchesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 120)
    }

    // MARK: - refresh()

    func testRefreshResetsOffsetAndReloads() async {
        let firstBatch = [makeAP(serial: "OLD")]
        mockClient.apsResult = .success(PaginatedResponse.of(firstBatch))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        let freshBatch = [makeAP(serial: "NEW")]
        mockClient.apsResult = .success(PaginatedResponse.of(freshBatch))
        await sut.refresh()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].serial, "NEW")
    }

    // MARK: - Helpers

    private func makeAP(serial: String) -> AccessPoint {
        AccessPoint(serial: serial, name: serial, model: "AP-635",
                    status: .up, ipAddress: nil, macAddress: nil,
                    firmware: nil, uptime: nil, site: "HQ", clientCount: 0)
    }

    private func makeSW(serial: String) -> CentralSwitch {
        CentralSwitch(serial: serial, name: serial, model: "6300M",
                      status: .up, ipAddress: nil, macAddress: nil,
                      firmware: nil, uptime: nil, site: "HQ", stackId: nil)
    }
}
