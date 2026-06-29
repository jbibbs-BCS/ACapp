import XCTest
@testable import ArubaCentral

@MainActor
final class DevicesViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: DevicesViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = DevicesViewModel(apiClient: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.devicesState { } else { XCTFail("Expected idle") }
    }

    func testDefaultFilterTypeIsAll() {
        XCTAssertEqual(sut.filterType, .all)
    }

    // MARK: - load

    func testLoadFetchesBothAPsAndSwitches() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertEqual(items.count, 2)
    }

    func testLoadSetsErrorWhenAPsFail() async {
        mockClient.apsResult      = .failure(.serverError(500))
        mockClient.switchesResult = .success(.empty())
        await sut.load()
        guard case .error = sut.devicesState else { return XCTFail("Expected error") }
    }

    // MARK: - Filter type

    func testFilterTypeAPShowsOnlyAPs() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        sut.filterType = .ap
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertTrue(items.allSatisfy { $0.deviceType == .ap })
    }

    func testFilterTypeSwitchShowsOnlySwitches() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        sut.filterType = .switch_
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertTrue(items.allSatisfy { $0.deviceType == .switch_ })
    }

    // MARK: - Site filter

    func testSiteFilterPassedToAPICall() async {
        mockClient.apsResult      = .success(.empty())
        mockClient.switchesResult = .success(.empty())
        sut.selectedSite = "HQ Campus"
        await sut.load()
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ Campus")
    }

    // MARK: - Search

    func testSearchQueryPassedToAPICall() async {
        mockClient.apsResult      = .success(.empty())
        mockClient.switchesResult = .success(.empty())
        await sut.search(query: "lobby")
        XCTAssertEqual(mockClient.lastSearchQuery, "lobby")
    }

    func testEmptySearchResetsToFullLoad() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.search(query: "")
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertEqual(items.count, 2)
    }

    // MARK: - Helpers

    private func makeAP(_ serial: String) -> AccessPoint {
        AccessPoint(serial: serial, name: serial, model: "AP-635", status: .up,
                    ipAddress: nil, macAddress: "", firmware: nil, uptime: nil,
                    site: nil, clientCount: nil)
    }

    private func makeSW(_ serial: String) -> CentralSwitch {
        CentralSwitch(serial: serial, name: serial, model: "6300M", status: .up,
                      ipAddress: nil, macAddress: nil, firmware: nil, uptime: nil,
                      site: nil, stackId: nil)
    }
}
