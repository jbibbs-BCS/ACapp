import XCTest
import SwiftUI
@testable import ArubaCentral

final class SharedComponentTests: XCTestCase {

    // MARK: - Color+Brand: health token round-trips (unchanged API)

    func testHealthColorGood() {
        XCTAssertEqual(Color.healthColor(for: .good), Color.healthGood)
    }

    func testHealthColorWarning() {
        XCTAssertEqual(Color.healthColor(for: .warning), Color.healthWarning)
    }

    func testHealthColorCritical() {
        XCTAssertEqual(Color.healthColor(for: .critical), Color.healthCritical)
    }

    // MARK: - Color+Brand: brand accent tokens exist

    func testBrandOrangeIsDefined() {
        XCTAssertNotNil(UIColor(Color.brandOrange))
    }

    func testBrandNavyIsDefined() {
        XCTAssertNotNil(UIColor(Color.brandNavy))
    }

    func testBrandOrangeMutedIsDefined() {
        XCTAssertNotNil(UIColor(Color.brandOrangeMuted))
    }

    // MARK: - Color+Brand: surface tokens exist

    func testAppBackgroundIsDefined() {
        XCTAssertNotNil(UIColor(Color.appBackground))
    }

    func testCardBackgroundIsDefined() {
        XCTAssertNotNil(UIColor(Color.cardBackground))
    }

    func testNavBackgroundIsDefined() {
        XCTAssertNotNil(UIColor(Color.navBackground))
    }

    func testCardBorderIsDefined() {
        XCTAssertNotNil(UIColor(Color.cardBorder))
    }

    // MARK: - Color+Brand: warning amber is distinct from brand orange

    func testHealthWarningIsDistinctFromBrandOrange() {
        XCTAssertNotEqual(Color.healthWarning, Color.brandOrange)
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

    // MARK: - LoadState helpers

    func testLoadStateViewInitWithLoaded() {
        let state: LoadState<String> = .loaded("hello")
        let _ = LoadStateView(state: state, content: { Text($0) }, retry: {})
    }

    func testLoadStateViewInitWithError() {
        let state: LoadState<String> = .error(.networkError)
        let _ = LoadStateView(state: state, content: { Text($0) }, retry: {})
    }

    // MARK: - HealthBadgePillView

    func testHealthBadgePillCompactInits() {
        let _ = HealthBadgePillView(size: .compact, level: .good)
        let _ = HealthBadgePillView(size: .compact, level: .warning)
        let _ = HealthBadgePillView(size: .compact, level: .critical)
    }

    func testHealthBadgePillStandardInits() {
        let _ = HealthBadgePillView(size: .standard, level: .good)
    }

    // MARK: - AlertSeverityBadgeView

    func testAlertSeverityBadgeInits() {
        let _ = AlertSeverityBadgeView(severity: .critical)
        let _ = AlertSeverityBadgeView(severity: .major)
        let _ = AlertSeverityBadgeView(severity: .minor)
        let _ = AlertSeverityBadgeView(severity: .info)
    }

    // MARK: - DeviceStatusBadge

    func testDeviceStatusBadgeUpInits() {
        let _ = DeviceStatusBadge(status: .up)
    }

    func testDeviceStatusBadgeDownInits() {
        let _ = DeviceStatusBadge(status: .down)
    }

    // MARK: - BrandedTabPicker

    func testBrandedTabPickerInits() {
        let _ = BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: .constant(0))
    }

    func testBrandedTabPickerSingleTab() {
        let _ = BrandedTabPicker(tabs: ["Overview"], selection: .constant(0))
    }

    // MARK: - SiteHealthHeaderView

    func testSiteHealthHeaderViewInits() {
        let site = Site(id: "s1", name: "HQ", healthPct: 90, deviceCount: 10, clientCount: 50)
        let _ = SiteHealthHeaderView(site: site)
    }
}
