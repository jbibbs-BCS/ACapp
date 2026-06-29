import XCTest
@testable import ArubaCentral

@MainActor
final class ClientDetailViewTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: ClientDetailViewModel!

    let client = CentralClient(
        macAddress: "aa:11:bb:22:cc:33", name: "MacBook-Josh",
        ipAddress: "10.0.1.100", connectionType: .wireless,
        associatedDeviceSerial: "AP-SN001", site: "HQ",
        ssid: "Corp-WiFi", vlan: nil, port: nil,
        signalStrength: -65, txDataRate: 120.0, rxDataRate: 45.0,
        connectedAt: Date(timeIntervalSince1970: 1_751_000_000)
    )

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = ClientDetailViewModel(client: client, apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadFetchesClientDetail() async {
        mockClient.clientDetailResult = .success(client)
        await sut.load()
        guard case .loaded(let detail) = sut.detailState else { return XCTFail() }
        XCTAssertEqual(detail.macAddress, "aa:11:bb:22:cc:33")
    }

    func testLoadSetsErrorOnFailure() async {
        mockClient.clientDetailResult = .failure(.networkError)
        await sut.load()
        guard case .error = sut.detailState else { return XCTFail("Expected error") }
    }

    func testDisconnectCallsAPIWithAPSerial() async {
        await sut.disconnect()
        XCTAssertEqual(mockClient.disconnectCallCount, 1)
    }

    func testDisconnectSetsErrorOnFailure() async {
        mockClient.disconnectError = .serverError(500)
        await sut.disconnect()
        XCTAssertNotNil(sut.actionError)
    }

    func testDisconnectDoesNothingWhenNoAPSerial() async {
        let clientWithNoAP = CentralClient(
            macAddress: "aa:11", name: nil, ipAddress: nil,
            connectionType: .wired, associatedDeviceSerial: nil,
            site: nil, ssid: nil, vlan: nil, port: nil,
            signalStrength: nil, txDataRate: nil, rxDataRate: nil, connectedAt: nil
        )
        sut = ClientDetailViewModel(client: clientWithNoAP, apiClient: mockClient)
        await sut.disconnect()
        XCTAssertEqual(mockClient.disconnectCallCount, 0)
    }
}
