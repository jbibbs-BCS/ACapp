import XCTest
@testable import ArubaCentral

final class SwitchStackTests: XCTestCase {

    private func sw(_ serial: String, status: DeviceStatus = .up,
                    stackId: String? = nil, role: String? = nil) -> CentralSwitch {
        CentralSwitch(serial: serial, name: "name-\(serial)", model: "6300M", status: status,
                      ipAddress: nil, macAddress: nil, firmware: nil, uptime: nil,
                      site: "HQ", stackId: stackId, switchRole: role)
    }

    // MARK: - Grouping

    func testStandaloneSwitchesStayStandalone() {
        let entries = [sw("A"), sw("B")].groupedIntoStacks()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries, [.standalone(sw("A")), .standalone(sw("B"))])
    }

    func testMembersSharingStackIdCollapseToOneEntry() {
        let members = [sw("M1", stackId: "S1", role: "Conductor"),
                       sw("M2", stackId: "S1"),
                       sw("M3", stackId: "S1")]
        let entries = members.groupedIntoStacks()
        XCTAssertEqual(entries.count, 1)
        guard case .stack(let stack) = entries[0] else { return XCTFail("expected a stack") }
        XCTAssertEqual(stack.memberCount, 3)
        XCTAssertEqual(stack.stackId, "S1")
    }

    func testStackAndStandaloneMixPreservesFirstSeenOrder() {
        let list = [sw("M1", stackId: "S1"), sw("A"), sw("M2", stackId: "S1")]
        let entries = list.groupedIntoStacks()
        // Stack takes M1's slot; A follows. M2 folds into the existing stack.
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id, "stack-S1")
        XCTAssertEqual(entries[1].id, "A")
    }

    // MARK: - Representative / name

    func testRepresentativeIsConductor() {
        let stack = SwitchStack(stackId: "S1", members: [
            sw("M1", stackId: "S1"),
            sw("M2", stackId: "S1", role: "Conductor")
        ])
        XCTAssertEqual(stack.representative.serial, "M2")
        XCTAssertEqual(stack.name, "name-M2")
    }

    func testRepresentativeFallsBackToFirstMember() {
        let stack = SwitchStack(stackId: "S1", members: [
            sw("M1", stackId: "S1"), sw("M2", stackId: "S1")
        ])
        XCTAssertEqual(stack.representative.serial, "M1")
    }

    // MARK: - Aggregate status

    func testAggregateDownIfAnyMemberDown() {
        let stack = SwitchStack(stackId: "S1", members: [
            sw("M1", status: .up, stackId: "S1"),
            sw("M2", status: .down, stackId: "S1")
        ])
        XCTAssertEqual(stack.status, .down)
    }

    func testAggregateUpOnlyIfAllUp() {
        let allUp = SwitchStack(stackId: "S1", members: [
            sw("M1", status: .up, stackId: "S1"), sw("M2", status: .up, stackId: "S1")
        ])
        XCTAssertEqual(allUp.status, .up)

        let mixed = SwitchStack(stackId: "S1", members: [
            sw("M1", status: .up, stackId: "S1"), sw("M2", status: .unknown, stackId: "S1")
        ])
        XCTAssertEqual(mixed.status, .unknown)
    }
}
