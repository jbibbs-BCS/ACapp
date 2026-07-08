import XCTest
@testable import ArubaCentral

@MainActor
final class NetworkMonitorTests: XCTestCase {

    func testInitialStateIsUnknown() {
        let monitor = NetworkMonitor()
        // Before the first path update, isConnected reflects system state.
        // We can only assert the property exists and is Bool.
        let _ = monitor.isConnected
    }

    func testIsConnectedPublished() {
        let monitor = NetworkMonitor()
        // NetworkMonitor must be an ObservableObject with a published isConnected
        let _: Published<Bool>.Publisher = monitor.$isConnected
    }
}
