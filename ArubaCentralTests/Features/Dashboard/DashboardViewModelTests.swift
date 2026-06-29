import XCTest
@testable import ArubaCentral

@MainActor
final class DashboardViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: DashboardViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = DashboardViewModel(client: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.sitesState { } else {
            XCTFail("Expected idle, got \(sut.sitesState)")
        }
    }

    // MARK: - load()

    func testLoadSetsLoadingThenLoaded() async {
        let sites = [makeSite(id: "s1", name: "HQ", score: 90)]
        mockClient.sitesResult = .success(sites)

        await sut.load()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "HQ")
    }

    func testLoadCallsFetchSiteHealthOnce() async {
        mockClient.sitesResult = .success([])
        await sut.load()
        XCTAssertEqual(mockClient.fetchSitesCallCount, 1)
    }

    func testLoadSetsErrorStateOnFailure() async {
        mockClient.sitesResult = .failure(.networkError)
        await sut.load()

        guard case .error(let error) = sut.sitesState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .networkError)
    }

    func testLoadSetsErrorForbidden() async {
        mockClient.sitesResult = .failure(.forbidden)
        await sut.load()

        guard case .error(let error) = sut.sitesState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .forbidden)
    }

    // MARK: - refresh()

    func testRefreshReloadsFromScratch() async {
        let firstBatch  = [makeSite(id: "s1", name: "Old", score: 50)]
        let secondBatch = [makeSite(id: "s1", name: "New", score: 90)]
        mockClient.sitesResult = .success(firstBatch)
        await sut.load()

        mockClient.sitesResult = .success(secondBatch)
        await sut.refresh()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].name, "New")
        XCTAssertEqual(mockClient.fetchSitesCallCount, 2)
    }

    // MARK: - sorting

    func testSitesAreSortedByCriticalFirst() async {
        let sites = [
            makeSite(id: "s1", name: "Good",     score: 95),
            makeSite(id: "s2", name: "Critical",  score: 20),
            makeSite(id: "s3", name: "Warning",   score: 60),
        ]
        mockClient.sitesResult = .success(sites)
        await sut.load()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].name, "Critical")
        XCTAssertEqual(result[1].name, "Warning")
        XCTAssertEqual(result[2].name, "Good")
    }

    // MARK: - Helpers

    private func makeSite(id: String, name: String, score: Int) -> Site {
        Site(id: id, name: name, healthScore: score, apCount: 1, switchCount: 1, clientCount: 1)
    }
}
