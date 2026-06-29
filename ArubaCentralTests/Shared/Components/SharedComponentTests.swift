import XCTest
import SwiftUI
@testable import ArubaCentral

final class SharedComponentTests: XCTestCase {

    // MARK: - Color+Health

    func testHealthColorGood() {
        XCTAssertEqual(Color.healthColor(for: .good), Color.healthGood)
    }

    func testHealthColorWarning() {
        XCTAssertEqual(Color.healthColor(for: .warning), Color.healthWarning)
    }

    func testHealthColorCritical() {
        XCTAssertEqual(Color.healthColor(for: .critical), Color.healthCritical)
    }

    // MARK: - HealthLevel accessibility labels

    func testHealthLevelAccessibilityLabelGood() {
        XCTAssertEqual(HealthLevel.good.accessibilityLabel, "Good")
    }

    func testHealthLevelAccessibilityLabelWarning() {
        XCTAssertEqual(HealthLevel.warning.accessibilityLabel, "Warning")
    }

    func testHealthLevelAccessibilityLabelCritical() {
        XCTAssertEqual(HealthLevel.critical.accessibilityLabel, "Critical")
    }

    // MARK: - LoadState helpers (already tested in Phase 1; just verify view init compiles)

    func testLoadStateViewInitWithLoaded() {
        let state: LoadState<String> = .loaded("hello")
        // If this compiles and doesn't crash, the view is correctly generic
        let _ = LoadStateView(state: state, content: { Text($0) }, retry: {})
    }

    func testLoadStateViewInitWithError() {
        let state: LoadState<String> = .error(.networkError)
        let _ = LoadStateView(state: state, content: { Text($0) }, retry: {})
    }
}
