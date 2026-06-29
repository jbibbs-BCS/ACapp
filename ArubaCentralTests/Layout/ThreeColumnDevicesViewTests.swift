import XCTest
import SwiftUI
@testable import ArubaCentral

@MainActor
final class ThreeColumnDevicesViewTests: XCTestCase {

    private var mockClient: MockCentralAPIClient!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    func test_init_doesNotCrash() {
        let sut = ThreeColumnDevicesView(apiClient: mockClient)
        XCTAssertNotNil(sut)
    }

    func test_selectedSiteName_startsNil() {
        let coordinator = ThreeColumnCoordinator()
        XCTAssertNil(coordinator.selectedSiteName)
    }

    func test_selectedDeviceSerial_startsNil() {
        let coordinator = ThreeColumnCoordinator()
        XCTAssertNil(coordinator.selectedDeviceSerial)
    }
}
