import XCTest
@testable import ArubaCentral

@MainActor
final class APDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: APDetailViewModel!
    let ap = AccessPoint(serial: "AP1", name: "AP-Lobby", model: "AP-635",
                         status: .up, ipAddress: "10.0.1.5", macAddress: "aa:bb:cc:dd:ee:ff",
                         firmware: "10.4.0", uptime: 86400, site: "HQ", clientCount: 8)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = APDetailViewModel(ap: ap, apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadSetsDetailRadiosAndClients() async {
        mockClient.apDetailResult  = .success(ap)
        mockClient.radiosResult    = .success([makeRadio(index: 0, band: "5GHz")])
        mockClient.apClientsResult = .success(.of([makeClient()]))

        await sut.load()

        guard case .loaded(let detail)   = sut.detailState  else { return XCTFail("detail") }
        guard case .loaded(let radios)   = sut.radiosState  else { return XCTFail("radios") }
        guard case .loaded(let clients)  = sut.clientsState else { return XCTFail("clients") }

        XCTAssertEqual(detail.serial, "AP1")
        XCTAssertEqual(radios.count, 1)
        XCTAssertEqual(clients.count, 1)
    }

    func testLoadSetsErrorWhenDetailFails() async {
        mockClient.apDetailResult  = .failure(.forbidden)
        mockClient.radiosResult    = .success([])
        mockClient.apClientsResult = .success(.empty())

        await sut.load()

        guard case .error(let error) = sut.detailState else { return XCTFail() }
        XCTAssertEqual(error, .forbidden)
    }

    func testRebootAPCallsClient() async throws {
        await sut.rebootAP()
        XCTAssertEqual(mockClient.rebootCallCount, 1)
    }

    func testRebootAPSetsErrorOnFailure() async {
        mockClient.rebootError = .serverError(500)
        await sut.rebootAP()
        XCTAssertNotNil(sut.actionError)
    }

    func testBlinkLEDCallsClient() async {
        await sut.blinkLED()
        XCTAssertEqual(mockClient.blinkCallCount, 1)
    }

    func testBlinkLEDSetsErrorOnFailure() async {
        mockClient.blinkError = .forbidden
        await sut.blinkLED()
        XCTAssertNotNil(sut.actionError)
    }

    private func makeRadio(index: Int, band: String) -> Radio {
        Radio(index: index, band: band, channel: 36, ssid: "Corp", clientCount: 4, throughput: 100)
    }

    private func makeClient() -> CentralClient {
        CentralClient(macAddress: "aa:11:bb:22:cc:33", name: "MacBook",
                      ipAddress: "10.0.1.100", connectionType: .wireless,
                      associatedDeviceSerial: "AP1", site: "HQ",
                      ssid: "Corp", vlan: nil, port: nil,
                      signalStrength: -65, txDataRate: nil, rxDataRate: nil, connectedAt: nil)
    }
}
