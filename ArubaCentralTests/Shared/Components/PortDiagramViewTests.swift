import XCTest
@testable import ArubaCentral

final class PortDiagramViewTests: XCTestCase {

    func testPortColorUp() {
        XCTAssertEqual(PortStatus.up.color,       "green")
    }

    func testPortColorDown() {
        XCTAssertEqual(PortStatus.down.color,     "gray")
    }

    func testPortColorDisabled() {
        XCTAssertEqual(PortStatus.disabled.color, "orange")
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
}
