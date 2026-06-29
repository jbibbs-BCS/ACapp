import XCTest
@testable import ArubaCentral

@MainActor
final class ClientsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: ClientsViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = ClientsViewModel(apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle") }
    }

    func testInitialSelectedSiteIsNil() {
        XCTAssertNil(sut.selectedSite)
    }

    // MARK: - selectSite

    func testSelectSiteLoadsClients() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ Campus")
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ Campus")
        guard case .loaded(let items) = sut.clientsState else { return XCTFail() }
        XCTAssertEqual(items.count, 1)
    }

    func testSelectSiteUpdatesSelectedSite() async {
        mockClient.clientsResult = .success(.empty())
        await sut.selectSite("Branch")
        XCTAssertEqual(sut.selectedSite, "Branch")
    }

    func testSelectNilSiteResetsToIdle() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        await sut.selectSite(nil)
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle after clearing site") }
    }

    // MARK: - search

    func testSearchQuerySentToAPI() async {
        mockClient.clientsResult = .success(.empty())
        await sut.search(query: "10.0.1.5")
        XCTAssertEqual(mockClient.lastSearchQuery, "10.0.1.5")
    }

    func testSearchWithSiteFilterKeepsSite() async {
        mockClient.clientsResult = .success(.empty())
        sut.selectedSite = "HQ"
        await sut.search(query: "mac-addr")
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
        XCTAssertEqual(mockClient.lastSearchQuery, "mac-addr")
    }

    func testEmptySearchWithSiteReloadsForSite() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        await sut.search(query: "")
        // Should reload for site, not search
        XCTAssertNil(mockClient.lastSearchQuery)
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
    }

    func testEmptySearchWithNoSiteResetsToIdle() async {
        await sut.search(query: "")
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle") }
    }

    // MARK: - Pagination

    func testLoadNextPageAppendsClients() async {
        let firstPage  = (0..<100).map { makeClient("aa:\($0)") }
        let secondPage = (100..<130).map { makeClient("bb:\($0)") }

        mockClient.clientsResult = .success(PaginatedResponse(items: firstPage, total: 130, offset: 0, limit: 100))
        await sut.selectSite("HQ")

        mockClient.clientsResult = .success(PaginatedResponse(items: secondPage, total: 130, offset: 100, limit: 100))
        await sut.loadNextPage()

        guard case .loaded(let items) = sut.clientsState else { return XCTFail() }
        XCTAssertEqual(items.count, 130)
    }

    func testLoadNextPageDoesNothingWhenNoMore() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        let callsBefore = mockClient.fetchClientsCallCount
        await sut.loadNextPage()
        XCTAssertEqual(mockClient.fetchClientsCallCount, callsBefore)
    }

    // MARK: - wireless/wired grouping

    func testWirelessClientsCount() async {
        let clients = [
            makeClient("aa:11", type: .wireless),
            makeClient("bb:22", type: .wireless),
            makeClient("cc:33", type: .wired),
        ]
        mockClient.clientsResult = .success(.of(clients))
        await sut.selectSite("HQ")
        XCTAssertEqual(sut.wirelessClients.count, 2)
        XCTAssertEqual(sut.wiredClients.count, 1)
    }

    // MARK: - Helpers

    private func makeClient(_ mac: String, type: ClientConnectionType = .wireless) -> CentralClient {
        CentralClient(macAddress: mac, name: "Device-\(mac)", ipAddress: "10.0.0.1",
                      connectionType: type, associatedDeviceSerial: nil, site: "HQ",
                      ssid: type == .wireless ? "Corp" : nil, vlan: nil, port: nil,
                      signalStrength: nil, txDataRate: nil, rxDataRate: nil, connectedAt: nil)
    }
}
