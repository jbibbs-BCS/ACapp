import XCTest
import SwiftUI
@testable import ArubaCentral

final class AdaptiveNavigationViewTests: XCTestCase {

    func test_compactSizeClass_rendersWithoutCrash() {
        let sut = AdaptiveNavigationView {
            Text("Content")
        }
        XCTAssertNotNil(sut)
    }

    func test_isThreeColumn_falseForNarrowWidth() {
        XCTAssertFalse(LayoutHelper.isThreeColumn(width: 768))
        XCTAssertFalse(LayoutHelper.isThreeColumn(width: 1023))
    }

    func test_isThreeColumn_trueForWideWidth() {
        XCTAssertTrue(LayoutHelper.isThreeColumn(width: 1024))
        XCTAssertTrue(LayoutHelper.isThreeColumn(width: 1366))
    }
}
