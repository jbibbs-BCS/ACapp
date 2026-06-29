import XCTest
import SwiftUI
@testable import ArubaCentral

@MainActor
final class ThreeColumnDevicesViewTests: XCTestCase {

    private var mockClient: MockCentralAPIClient!
    private var viewModel: DevicesViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        viewModel = DevicesViewModel(apiClient: mockClient)
    }

    override func tearDown() {
        viewModel = nil
        mockClient = nil
        super.tearDown()
    }

    func test_init_doesNotCrash() {
        let sut = ThreeColumnDevicesView(viewModel: viewModel)
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
