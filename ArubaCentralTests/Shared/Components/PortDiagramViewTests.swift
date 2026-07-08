import XCTest
@testable import ArubaCentral

final class PortDiagramViewTests: XCTestCase {

    func testPortColorUp() {
        XCTAssertEqual(PortStatus.up.color,       "up")
    }

    func testPortColorDown() {
        XCTAssertEqual(PortStatus.down.color,     "down")
    }

    func testPortColorDisabled() {
        XCTAssertEqual(PortStatus.disabled.color, "disabled")
    }

    func testPortGridColumns8Port() {
        XCTAssertEqual(PortDiagramLayout.columns(for: 8),  4)
    }

    func testPortGridColumns24Port() {
        XCTAssertEqual(PortDiagramLayout.columns(for: 24), 12)
    }

    func testPortGridColumns48Port() {
        XCTAssertEqual(PortDiagramLayout.columns(for: 48), 12)
    }

    // MARK: - Stack member grouping

    private func port(_ id: String) -> SwitchInterface {
        SwitchInterface(portId: id, status: .up, speed: nil, vlan: nil,
                        neighbour: nil, txBytes: nil, rxBytes: nil)
    }

    func testGroupedByMemberSeparatesStackMembers() {
        let ports = [port("1/1"), port("1/2"), port("2/1"), port("2/2"), port("2/3")]
        let groups = PortDiagramLayout.groupedByMember(ports)
        XCTAssertEqual(groups.map(\.member), ["1", "2"])   // order preserved
        XCTAssertEqual(groups[0].ports.count, 2)
        XCTAssertEqual(groups[1].ports.count, 3)
    }

    func testGroupedByMemberThreePartIds() {
        let groups = PortDiagramLayout.groupedByMember([port("1/1/4"), port("2/1/1")])
        XCTAssertEqual(groups.map(\.member), ["1", "2"])
    }

    func testGroupedByMemberSlashlessIdsShareOneGroup() {
        // Standalone switch with member-less port ids renders as a single grid.
        let groups = PortDiagramLayout.groupedByMember([port("A1"), port("A2"), port("A3")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].ports.count, 3)
    }
}
