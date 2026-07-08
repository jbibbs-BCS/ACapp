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
