import XCTest
@testable import ArubaCentral

@MainActor
final class ClientDetailViewTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: ClientDetailViewModel!

    let wirelessClient = CentralClient(
        macAddress: "aa:11:bb:22:cc:33", name: "MacBook-Josh",
        ipAddress: "10.0.1.100", connectionType: .wireless,
        associatedDeviceSerial: "AP-SN001", site: "HQ",
        ssid: "Corp-WiFi", vlan: nil, port: nil,
        signalStrength: -65, txDataRate: 120.0, rxDataRate: 45.0,
        connectedAt: Date(timeIntervalSince1970: 1_751_000_000)
    )

    let wiredClient = CentralClient(
        macAddress: "bb:22:cc:33:dd:44", name: "Printer-01",
        ipAddress: "10.0.1.200", connectionType: .wired,
        associatedDeviceSerial: "SW-SN001", site: "HQ",
        ssid: nil, vlan: 10, port: "1/1/1",
        signalStrength: nil, txDataRate: nil, rxDataRate: nil,
        connectedAt: nil
    )

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testDetailPreLoadedFromInit() {
        sut = ClientDetailViewModel(client: wirelessClient, apiClient: mockClient)
        guard case .loaded(let detail) = sut.detailState else {
            return XCTFail("Expected detailState to be .loaded immediately after init")
        }
        XCTAssertEqual(detail.macAddress, wirelessClient.macAddress)
    }

    func testLoadSetsConnectedNameForWirelessClient() async {
        let ap = AccessPoint(serial: "AP-SN001", name: "AP-Lobby", model: "AP-635",
                             status: .up, ipAddress: nil, macAddress: "",
                             firmware: nil, uptime: nil, site: "HQ", clientCount: nil)
        mockClient.apDetailResult = .success(ap)
        sut = ClientDetailViewModel(client: wirelessClient, apiClient: mockClient)
        await sut.load()
        XCTAssertEqual(sut.connectedDeviceName, "AP-Lobby")
    }

    func testLoadSetsConnectedNameForWiredClient() async {
        let sw = CentralSwitch(serial: "SW-SN001", name: "Core-Switch-01", model: "6300M",
                               status: .up, ipAddress: nil, macAddress: nil,
                               firmware: nil, uptime: nil, site: "HQ", stackId: nil)
        mockClient.switchDetailResult = .success(sw)
        sut = ClientDetailViewModel(client: wiredClient, apiClient: mockClient)
        await sut.load()
        XCTAssertEqual(sut.connectedDeviceName, "Core-Switch-01")
    }

    func testLoadDoesNothingWhenNoSerial() async {
        let clientWithNoSerial = CentralClient(
            macAddress: "cc:33", name: nil, ipAddress: nil,
            connectionType: .wired, associatedDeviceSerial: nil,
            site: nil, ssid: nil, vlan: nil, port: nil,
            signalStrength: nil, txDataRate: nil, rxDataRate: nil, connectedAt: nil
        )
        sut = ClientDetailViewModel(client: clientWithNoSerial, apiClient: mockClient)
        await sut.load()
        XCTAssertNil(sut.connectedDeviceName)
    }
}
