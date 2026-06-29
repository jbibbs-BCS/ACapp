import XCTest
@testable import ArubaCentral

@MainActor
final class SwitchDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: SwitchDetailViewModel!
    let sw = CentralSwitch(serial: "SW1", name: "Core-1", model: "6300M",
                           status: .up, ipAddress: "10.0.0.1", macAddress: nil,
                           firmware: "10.13", uptime: 604800, site: "HQ", stackId: nil)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = SwitchDetailViewModel(sw: sw, apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadFetchesDetailInterfacesAndVLANs() async {
        mockClient.switchDetailResult = .success(sw)
        mockClient.interfacesResult   = .success([makeInterface("1/1/1")])
        mockClient.vlansResult        = .success([makeVLAN(10)])

        await sut.load()

        guard case .loaded = sut.detailState    else { return XCTFail("detail") }
        guard case .loaded(let ifaces) = sut.portsState else { return XCTFail("ports") }
        guard case .loaded(let vlans)  = sut.vlansState else { return XCTFail("vlans") }

        XCTAssertEqual(ifaces.count, 1)
        XCTAssertEqual(vlans.count, 1)
    }

    func testLoadSetsErrorOnDetailFailure() async {
        mockClient.switchDetailResult = .failure(.serverError(503))
        mockClient.interfacesResult   = .success([])
        mockClient.vlansResult        = .success([])

        await sut.load()
        guard case .error = sut.detailState else { return XCTFail("Expected error") }
    }

    private func makeInterface(_ portId: String) -> SwitchInterface {
        SwitchInterface(portId: portId, status: .up, speed: "1G",
                        vlan: 10, connectedDevice: nil, txBytes: nil, rxBytes: nil)
    }

    private func makeVLAN(_ id: Int) -> VLAN {
        VLAN(vlanId: id, name: "Corp", taggedPorts: [], untaggedPorts: ["1/1/1"])
    }
}
