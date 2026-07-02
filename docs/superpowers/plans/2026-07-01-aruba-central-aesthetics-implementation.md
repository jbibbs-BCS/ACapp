# Aruba Central — Aesthetics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generic system colors, stock components, and flat typography with the Aruba Navy Flagship brand design across Dashboard, Site Detail, Device Detail, and Alerts screens.

**Architecture:** Semantic color tokens defined as `static let Color` extensions backed by `UIColor` dynamic providers for automatic light/dark adaptation. New components are standalone SwiftUI `View` structs in `Shared/Components/`. Global nav/tab bar chrome configured once via `UIAppearance` in `ArubaCentralApp.init()`. Screen files consume the token/component layer; no architectural or data-flow changes.

**Tech Stack:** SwiftUI (iOS 16+), XCTest, UIKit UIAppearance API

## Global Constraints
- iOS 16+ minimum — all APIs must be available on iOS 16; use `.scrollContentBackground(.hidden)` (iOS 16+) freely
- SF Pro system font only — no bundled typefaces; all font sizes use named text styles for Dynamic Type
- All numeric displays must use `.monospacedDigit()` modifier
- Health token names (`healthGood`, `healthWarning`, `healthCritical`, `healthColor(for:)`) are unchanged — existing call sites must compile without modification after Task 1
- `static let` (not `static var`) for all color tokens so test equality checks work
- Shadow applied in light mode only: `color: .black.opacity(0.06), radius: 8, x: 0, y: 2` — `.clear` shadow in dark mode
- No snapshot tests — XCTest covers logic and view init; visual correctness verified in Xcode Preview
- Commit after every task with `git add <specific files>`

---

## File Map

| Action | Path |
|--------|------|
| **Create** | `ArubaCentral/Shared/Extensions/Color+Brand.swift` |
| **Delete** | `ArubaCentral/Shared/Extensions/Color+Health.swift` |
| **Create** | `ArubaCentral/Shared/Components/HealthBadgePillView.swift` |
| **Delete** | `ArubaCentral/Shared/Components/HealthBadgeView.swift` |
| **Create** | `ArubaCentral/Shared/Components/AlertSeverityBadgeView.swift` |
| **Create** | `ArubaCentral/Shared/Components/DeviceStatusBadge.swift` |
| **Create** | `ArubaCentral/Shared/Components/BrandedTabPicker.swift` |
| **Create** | `ArubaCentral/Features/Dashboard/SiteDetail/SiteHealthHeaderView.swift` |
| **Modify** | `ArubaCentral/Shared/Components/StatCardView.swift` |
| **Modify** | `ArubaCentral/Core/Models/AlertSeverity.swift` |
| **Modify** | `ArubaCentral/ArubaCentralApp.swift` |
| **Modify** | `ArubaCentral/Features/Dashboard/DashboardView.swift` |
| **Modify** | `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift` |
| **Modify** | `ArubaCentral/Features/Alerts/AlertsView.swift` |
| **Modify** | `ArubaCentral/Features/Alerts/AlertDetailView.swift` |
| **Modify** | `ArubaCentral/Features/Devices/APDetail/APDetailView.swift` |
| **Modify** | `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift` |
| **Modify** | `ArubaCentral/Shared/Components/PortDiagramView.swift` |
| **Modify** | `ArubaCentralTests/Shared/Components/SharedComponentTests.swift` |
| **Modify** | `ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift` |

---

## Task 1: Color+Brand Foundation

**Files:**
- Create: `ArubaCentral/Shared/Extensions/Color+Brand.swift`
- Delete: `ArubaCentral/Shared/Extensions/Color+Health.swift`
- Modify: `ArubaCentral/Core/Models/AlertSeverity.swift`
- Modify: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Produces: `Color.appBackground`, `Color.cardBackground`, `Color.navBackground`, `Color.cardBorder`, `Color.brandOrange`, `Color.brandNavy`, `Color.brandOrangeMuted`, `Color.healthGood`, `Color.healthWarning`, `Color.healthCritical`, `Color.healthColor(for: HealthLevel) -> Color`, `HealthLevel.accessibilityLabel: String`, `HealthLevel.systemImage: String`, `AlertSeverity.color: Color` (updated values)

- [ ] **Step 1: Write the failing tests** — add brand token and isolation tests to `SharedComponentTests.swift`

```swift
// ArubaCentralTests/Shared/Components/SharedComponentTests.swift
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
        // Key spec requirement: they must never clash on the same card
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
}
```

- [ ] **Step 2: Run tests — expect failures** for the new brand token tests

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: `testBrandOrangeIsDefined` and the other new tests FAIL with "type 'Color' has no member 'brandOrange'".

- [ ] **Step 3: Create `Color+Brand.swift`**

```swift
// ArubaCentral/Shared/Extensions/Color+Brand.swift
import SwiftUI

// MARK: - Surface tokens

extension Color {
    static let appBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.039, green: 0.118, blue: 0.220, alpha: 1)  // #0A1E38
            : UIColor(red: 0.949, green: 0.945, blue: 0.937, alpha: 1)  // #F2F1EF
    })

    static let cardBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.145, blue: 0.251, alpha: 1)  // #112540
            : UIColor.white
    })

    static let navBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.027, green: 0.082, blue: 0.149, alpha: 1)  // #071526
            : UIColor(red: 0.051, green: 0.153, blue: 0.302, alpha: 1)  // #0D274D
    })

    static let cardBorder: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor(red: 0.051, green: 0.153, blue: 0.302, alpha: 0.10)
    })
}

// MARK: - Brand accent tokens

extension Color {
    static let brandOrange     = Color(red: 1.000, green: 0.514, blue: 0.000) // #FF8300
    static let brandNavy       = Color(red: 0.051, green: 0.153, blue: 0.302) // #0D274D
    static let brandOrangeMuted = Color(UIColor(red: 1.000, green: 0.514, blue: 0.000, alpha: 0.12))
}

// MARK: - Health / status tokens (names unchanged for call-site compatibility)

extension Color {
    static let healthGood: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1)  // #4ADE80
            : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E
    })

    static let healthWarning: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.988, green: 0.827, blue: 0.302, alpha: 1)  // #FCD34D
            : UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)  // #F59E0B — amber, distinct from brandOrange
    })

    static let healthCritical: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1)  // #F87171
            : UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)  // #EF4444
    })

    static func healthColor(for level: HealthLevel) -> Color {
        switch level {
        case .good:     return .healthGood
        case .warning:  return .healthWarning
        case .critical: return .healthCritical
        }
    }
}

// MARK: - HealthLevel display extensions (moved from Color+Health.swift)

extension HealthLevel {
    var accessibilityLabel: String {
        switch self {
        case .good:     return "Good"
        case .warning:  return "Warning"
        case .critical: return "Critical"
        }
    }

    var systemImage: String {
        switch self {
        case .good:     return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}
```

- [ ] **Step 4: Delete `Color+Health.swift`**

```bash
rm /Users/joshuaebibbs/XcodeProj/ArubaCentral/ArubaCentral/Shared/Extensions/Color+Health.swift
```

Then remove the file from the Xcode project target in `ArubaCentral.xcodeproj/project.pbxproj`. Open the project in Xcode, select `Color+Health.swift` in the navigator, press Delete → "Remove Reference" (the file is already deleted on disk). Alternatively edit `project.pbxproj` directly and remove the two entries for `Color+Health.swift` (one in the `PBXFileReference` section, one in the `PBXSourcesBuildPhase` section).

- [ ] **Step 5: Update `AlertSeverity.swift` — replace raw colors with brand tokens**

Replace the entire SwiftUI extension block at the bottom of `AlertSeverity.swift`:

```swift
// ArubaCentral/Core/Models/AlertSeverity.swift
// (keep the enum and Comparable conformance unchanged; replace only the extension below)

import SwiftUI

extension AlertSeverity {
    var color: Color {
        switch self {
        case .critical: return .healthCritical
        case .major:    return .healthWarning   // amber #F59E0B — distinct from brandOrange
        case .minor:    return Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
        case .info:     return Color(.secondaryLabel)
        }
    }

    var systemImage: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .major:    return "exclamationmark.triangle.fill"
        case .minor:    return "exclamationmark.circle.fill"
        case .info:     return "info.circle.fill"
        }
    }
}
```

- [ ] **Step 6: Build to verify no compile errors**

```bash
xcodebuild build -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
git add ArubaCentral/Shared/Extensions/Color+Brand.swift \
        ArubaCentral/Core/Models/AlertSeverity.swift \
        ArubaCentralTests/Shared/Components/SharedComponentTests.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): replace Color+Health with Color+Brand semantic token layer

Navy/orange brand tokens, adaptive light/dark surfaces, health amber
distinct from brand orange, AlertSeverity.color updated to brand tokens.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Global UIAppearance Configuration

**Files:**
- Modify: `ArubaCentral/ArubaCentralApp.swift`

**Interfaces:**
- Consumes: `Color.navBackground`, `Color.brandOrange`
- Produces: Navy nav bars and tab bars with orange tint globally across all screens

- [ ] **Step 1: Open `ArubaCentralApp.swift` and add `init()`**

The current file has `@main struct ArubaCentralApp: App { var body: some Scene { ... } }`. Add an `init()` before `body`:

```swift
// ArubaCentral/ArubaCentralApp.swift
import SwiftUI

@main
struct ArubaCentralApp: App {

    init() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    // MARK: - Appearance

    private func configureNavigationBarAppearance() {
        let navColor   = UIColor(Color.navBackground)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor              = navColor
        appearance.titleTextAttributes         = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes    = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().tintColor            = UIColor(Color.brandOrange)
    }

    private func configureTabBarAppearance() {
        let tabColor   = UIColor(Color.navBackground)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = tabColor
        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor            = UIColor(Color.brandOrange)
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild build -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`. Launch the app in the simulator — nav bar and tab bar should be deep navy with orange selected tab icon.

- [ ] **Step 3: Commit**

```bash
git add ArubaCentral/ArubaCentralApp.swift
git commit -m "feat(brand): configure global navy/orange UIAppearance for nav and tab bars

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: HealthBadgePillView

**Files:**
- Create: `ArubaCentral/Shared/Components/HealthBadgePillView.swift`
- Delete: `ArubaCentral/Shared/Components/HealthBadgeView.swift`
- Modify: `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift` (temporary call-site update; full SiteDetailView redesign in Task 10)

**Interfaces:**
- Consumes: `Color.healthColor(for:)`, `HealthLevel.systemImage`, `HealthLevel.accessibilityLabel`
- Produces: `HealthBadgePillView(size: HealthBadgePillView.Size, level: HealthLevel)` — two sizes: `.compact` (icon circle) and `.standard` (icon + text capsule)

- [ ] **Step 1: Write the failing test** — append to `SharedComponentTests.swift`

```swift
// Add inside final class SharedComponentTests: XCTestCase { ... }

// MARK: - HealthBadgePillView

func testHealthBadgePillCompactInits() {
    let _ = HealthBadgePillView(size: .compact, level: .good)
    let _ = HealthBadgePillView(size: .compact, level: .warning)
    let _ = HealthBadgePillView(size: .compact, level: .critical)
}

func testHealthBadgePillStandardInits() {
    let _ = HealthBadgePillView(size: .standard, level: .good)
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests/testHealthBadgePillCompactInits \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: FAIL — "cannot find type 'HealthBadgePillView'".

- [ ] **Step 3: Create `HealthBadgePillView.swift`**

```swift
// ArubaCentral/Shared/Components/HealthBadgePillView.swift
import SwiftUI

struct HealthBadgePillView: View {
    enum Size { case compact, standard }

    let size: Size
    let level: HealthLevel

    private var color: Color { Color.healthColor(for: level) }

    var body: some View {
        switch size {
        case .compact:  compactView
        case .standard: standardView
        }
    }

    private var compactView: some View {
        Image(systemName: level.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }

    private var standardView: some View {
        Label(level.accessibilityLabel, systemImage: level.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            HealthBadgePillView(size: .standard, level: .good)
            HealthBadgePillView(size: .standard, level: .warning)
            HealthBadgePillView(size: .standard, level: .critical)
        }
        HStack(spacing: 12) {
            HealthBadgePillView(size: .compact, level: .good)
            HealthBadgePillView(size: .compact, level: .warning)
            HealthBadgePillView(size: .compact, level: .critical)
        }
    }
    .padding()
}
```

- [ ] **Step 4: Delete `HealthBadgeView.swift`**

```bash
rm /Users/joshuaebibbs/XcodeProj/ArubaCentral/ArubaCentral/Shared/Components/HealthBadgeView.swift
```

Remove `HealthBadgeView.swift` from the Xcode project target (same process as Task 1 Step 4 — delete from navigator or edit `project.pbxproj`). Add `HealthBadgePillView.swift` to the target.

- [ ] **Step 5: Update `SiteDetailView.swift` — replace `HealthBadgeView` call site**

In `SiteDetailView.swift`, the `siteHealthSection` has:
```swift
HealthBadgeView(level: viewModel.site.healthLevel)
```

Replace with:
```swift
HealthBadgePillView(size: .compact, level: viewModel.site.healthLevel)
```

- [ ] **Step 6: Build — verify DevicesView still compiles with the updated DeviceRowView**

```bash
xcodebuild build -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED` — `DevicesView` uses the updated `DeviceRowView` without any call-site changes.

- [ ] **Step 7: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add ArubaCentral/Shared/Components/HealthBadgePillView.swift \
        ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): add HealthBadgePillView, remove HealthBadgeView

Compact (icon circle) and standard (icon+text capsule) sizes. Health
color fill at 12% opacity background. All call sites updated.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: AlertSeverityBadgeView

**Files:**
- Create: `ArubaCentral/Shared/Components/AlertSeverityBadgeView.swift`
- Modify: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Consumes: `AlertSeverity.color`, `AlertSeverity.rawValue`
- Produces: `AlertSeverityBadgeView(severity: AlertSeverity)` — pill badge used inline in alert rows and detail view

- [ ] **Step 1: Write the failing test**

```swift
// Append inside SharedComponentTests
func testAlertSeverityBadgeInits() {
    let _ = AlertSeverityBadgeView(severity: .critical)
    let _ = AlertSeverityBadgeView(severity: .major)
    let _ = AlertSeverityBadgeView(severity: .minor)
    let _ = AlertSeverityBadgeView(severity: .info)
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests/testAlertSeverityBadgeInits \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 3: Create `AlertSeverityBadgeView.swift`**

```swift
// ArubaCentral/Shared/Components/AlertSeverityBadgeView.swift
import SwiftUI

struct AlertSeverityBadgeView: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(severity.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(severity.color.opacity(0.12), in: Capsule())
            .accessibilityHidden(true) // parent row provides combined accessibility label
    }
}

#Preview {
    HStack(spacing: 10) {
        AlertSeverityBadgeView(severity: .critical)
        AlertSeverityBadgeView(severity: .major)
        AlertSeverityBadgeView(severity: .minor)
        AlertSeverityBadgeView(severity: .info)
    }
    .padding()
}
```

Add `AlertSeverityBadgeView.swift` to the Xcode project target.

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 5: Commit**

```bash
git add ArubaCentral/Shared/Components/AlertSeverityBadgeView.swift \
        ArubaCentralTests/Shared/Components/SharedComponentTests.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): add AlertSeverityBadgeView severity pill badge

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: DeviceStatusBadge

**Files:**
- Create: `ArubaCentral/Shared/Components/DeviceStatusBadge.swift`
- Modify: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Consumes: `DeviceStatus` (`.up` / `.down`), `Color.healthGood`, `Color.healthCritical`
- Produces: `DeviceStatusBadge(status: DeviceStatus)` — compact Up/Down pill for device list rows

- [ ] **Step 1: Write the failing test**

```swift
// Append inside SharedComponentTests
func testDeviceStatusBadgeUpInits() {
    let _ = DeviceStatusBadge(status: .up)
}

func testDeviceStatusBadgeDownInits() {
    let _ = DeviceStatusBadge(status: .down)
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests/testDeviceStatusBadgeUpInits \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 3: Create `DeviceStatusBadge.swift`**

```swift
// ArubaCentral/Shared/Components/DeviceStatusBadge.swift
import SwiftUI

struct DeviceStatusBadge: View {
    let status: DeviceStatus

    private var color: Color { status == .up ? .healthGood : .healthCritical }
    private var label: String { status == .up ? "Up" : "Down" }

    var body: some View {
        Text(label)
            .font(.system(.caption2).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityHidden(true) // parent row provides combined accessibility label
    }
}

#Preview {
    HStack(spacing: 10) {
        DeviceStatusBadge(status: .up)
        DeviceStatusBadge(status: .down)
    }
    .padding()
}
```

Add `DeviceStatusBadge.swift` to the Xcode project target.

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 5: Commit**

```bash
git add ArubaCentral/Shared/Components/DeviceStatusBadge.swift \
        ArubaCentralTests/Shared/Components/SharedComponentTests.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): add DeviceStatusBadge Up/Down pill for device rows

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: BrandedTabPicker

**Files:**
- Create: `ArubaCentral/Shared/Components/BrandedTabPicker.swift`
- Modify: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Consumes: `Color.brandOrange`
- Produces: `BrandedTabPicker(tabs: [String], selection: Binding<Int>)` — full-width pill tab selector replacing `.segmented` Picker in device detail views

- [ ] **Step 1: Write the failing test**

```swift
// Append inside SharedComponentTests
func testBrandedTabPickerInits() {
    let _ = BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: .constant(0))
}

func testBrandedTabPickerRequiresTwoOrMoreTabs() {
    // Should not crash with a single tab
    let _ = BrandedTabPicker(tabs: ["Overview"], selection: .constant(0))
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests/testBrandedTabPickerInits \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 3: Create `BrandedTabPicker.swift`**

```swift
// ArubaCentral/Shared/Components/BrandedTabPicker.swift
import SwiftUI

struct BrandedTabPicker: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Text(tabs[index])
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selection == index
                                ? Color.brandOrange
                                : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selection == index
                                ? Color.white
                                : Color.secondary
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.brandNavy.opacity(0.07), in: Capsule())
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var selection = 0
    VStack(spacing: 16) {
        BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: $selection)
        BrandedTabPicker(tabs: ["Overview", "Ports", "VLANs"], selection: $selection)
        Text("Selected: \(selection)")
    }
    .padding()
}
```

Add `BrandedTabPicker.swift` to the Xcode project target.

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 5: Commit**

```bash
git add ArubaCentral/Shared/Components/BrandedTabPicker.swift \
        ArubaCentralTests/Shared/Components/SharedComponentTests.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): add BrandedTabPicker orange-pill tab selector

Replaces .segmented Picker in AP and Switch detail views.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: StatCardView Redesign

**Files:**
- Modify: `ArubaCentral/Shared/Components/StatCardView.swift`

**Interfaces:**
- Consumes: `Color.cardBackground`, `Color.cardBorder`, `Color.brandOrange`
- Produces: `StatCardView(title: String, value: String, systemImage: String, accentColor: Color = .brandOrange)` — adds optional `accentColor` parameter (default: `brandOrange`) for the 3pt top accent bar; backwards-compatible with all existing call sites

- [ ] **Step 1: Verify existing `StatCardView` test still works before touching anything**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: All pass (baseline).

- [ ] **Step 2: Replace `StatCardView.swift` entirely**

```swift
// ArubaCentral/Shared/Components/StatCardView.swift
import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var accentColor: Color = .brandOrange

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 3pt top accent bar
            Rectangle()
                .fill(accentColor)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .foregroundStyle(accentColor)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(title.uppercased())
                        .font(.caption2.weight(.medium))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .light ? .black.opacity(0.06) : .clear,
            radius: 8, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(title: "APs",     value: "24",  systemImage: "antenna.radiowaves.left.and.right")
        StatCardView(title: "Clients", value: "310", systemImage: "person.2")
        StatCardView(title: "Down",    value: "3",   systemImage: "xmark.circle.fill", accentColor: .healthCritical)
    }
    .padding()
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild build -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED` — all existing `StatCardView(title:value:systemImage:)` call sites continue to compile.

- [ ] **Step 4: Commit**

```bash
git add ArubaCentral/Shared/Components/StatCardView.swift
git commit -m "feat(brand): redesign StatCardView with top accent bar and solid background

Removes .regularMaterial, adds 3pt colored top bar (default brandOrange),
uppercase tracking labels, monospacedDigit values, cardBackground surface.
Backwards-compatible via accentColor default parameter.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: SiteHealthHeaderView

**Files:**
- Create: `ArubaCentral/Features/Dashboard/SiteDetail/SiteHealthHeaderView.swift`
- Modify: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Consumes: `Site` (`.healthPct: Int`, `.healthLevel: HealthLevel`, `.goodDeviceCount: Int`, `.deviceCount: Int`, `.clientCount: Int`), `StatCardView(title:value:systemImage:accentColor:)`, `Color.healthColor(for:)`, `Color.cardBackground`, `Color.cardBorder`
- Produces: `SiteHealthHeaderView(site: Site)` — full-width card with 64pt health ring above three stat blocks

- [ ] **Step 1: Write the failing test**

```swift
// Append inside SharedComponentTests
func testSiteHealthHeaderViewInits() {
    let site = Site(id: "s1", name: "HQ", healthPct: 90, deviceCount: 10, clientCount: 50)
    let _ = SiteHealthHeaderView(site: site)
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests/testSiteHealthHeaderViewInits \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 3: Create `SiteHealthHeaderView.swift`**

First check what properties `Site` exposes. From existing code, `Site` has at minimum: `id`, `name`, `healthPct`, `deviceCount`, `clientCount`, `alertCount`, `goodDeviceCount`, `healthLevel`. The down device count is computed as `deviceCount - goodDeviceCount`.

```swift
// ArubaCentral/Features/Dashboard/SiteDetail/SiteHealthHeaderView.swift
import SwiftUI

struct SiteHealthHeaderView: View {
    let site: Site

    @Environment(\.colorScheme) private var colorScheme

    private var healthColor: Color { Color.healthColor(for: site.healthLevel) }
    private var downDeviceCount: Int { site.deviceCount - site.goodDeviceCount }

    var body: some View {
        VStack(spacing: 12) {
            healthRing
            statRow
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .light ? .black.opacity(0.06) : .clear,
            radius: 8, x: 0, y: 2
        )
    }

    private var healthRing: some View {
        ZStack {
            Circle()
                .stroke(healthColor.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(site.healthPct) / 100.0)
                .stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(site.healthPct)%")
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(healthColor)
                Text("Health")
                    .font(.caption2.weight(.medium))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            StatCardView(
                title: "Up Devices",
                value: "\(site.goodDeviceCount)",
                systemImage: "checkmark.circle.fill",
                accentColor: .healthGood
            )
            StatCardView(
                title: "Down",
                value: "\(downDeviceCount)",
                systemImage: "xmark.circle.fill",
                accentColor: .healthCritical
            )
            StatCardView(
                title: "Clients",
                value: "\(site.clientCount)",
                systemImage: "person.2.fill",
                accentColor: .brandOrange
            )
        }
    }
}

#Preview {
    SiteHealthHeaderView(
        site: Site(id: "s1", name: "HQ Campus", healthPct: 74,
                   deviceCount: 12, clientCount: 87)
    )
    .padding()
}
```

Add `SiteHealthHeaderView.swift` to the Xcode project target.

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

- [ ] **Step 5: Commit**

```bash
git add ArubaCentral/Features/Dashboard/SiteDetail/SiteHealthHeaderView.swift \
        ArubaCentralTests/Shared/Components/SharedComponentTests.swift \
        ArubaCentral.xcodeproj/project.pbxproj
git commit -m "feat(brand): add SiteHealthHeaderView with health ring and stat blocks

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: DashboardView Redesign

**Files:**
- Modify: `ArubaCentral/Features/Dashboard/DashboardView.swift`

**Interfaces:**
- Consumes: `Color.appBackground`, `Color.cardBackground`, `Color.cardBorder`, `Color.brandOrange`, `Color.healthColor(for:)`, `HealthBadgePillView(size:level:)`
- Produces: Redesigned `SiteCardView` (left accent bar, warm canvas, uppercase stats) and `AlertSummaryCardView` (orange leading bar)

- [ ] **Step 1: Replace `DashboardView.swift` entirely**

```swift
// ArubaCentral/Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    private let apiClient: CentralAPIClientProtocol
    @StateObject private var viewModel: DashboardViewModel
    let onAlertsTapped: () -> Void

    init(client: CentralAPIClientProtocol, onAlertsTapped: @escaping () -> Void = {}) {
        self.apiClient = client
        self.onAlertsTapped = onAlertsTapped
        _viewModel = StateObject(wrappedValue: DashboardViewModel(apiClient: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.sitesState,
            content: { sites in siteScrollView(sites) },
            retry: { Task { await viewModel.load() } }
        )
        .background(Color.appBackground)
        .navigationTitle("Dashboard")
        .navigationDestination(for: Site.self) { site in
            SiteDetailView(site: site, apiClient: apiClient)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func siteScrollView(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "building.2")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandOrange.opacity(0.6))
                Text("No Sites")
                    .font(.headline)
                Text("No sites found in your Central account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.alertCounts.hasAny {
                        AlertSummaryCardView(counts: viewModel.alertCounts, onTap: onAlertsTapped)
                    }
                    ForEach(sites) { site in
                        NavigationLink(value: site) {
                            SiteCardView(site: site)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
            .refreshable { await viewModel.refresh() }
        }
    }
}

// MARK: - Alert Summary Card

struct AlertSummaryCardView: View {
    let counts: AlertSummaryCounts
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack {
                // 4pt leading bar
                Rectangle()
                    .fill(Color.brandOrange)
                    .frame(width: 4)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)

                Image(systemName: "bell.fill")
                    .foregroundStyle(Color.brandOrange)
                    .font(.title3)
                    .padding(.leading, 10)
                Text("Active Alerts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(counts.total)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.brandOrange)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 14)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .light ? .black.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Site Card

struct SiteCardView: View {
    let site: Site

    @Environment(\.colorScheme) private var colorScheme

    private var statusColor: Color { Color.healthColor(for: site.healthLevel) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Card body
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(site.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HealthBadgePillView(size: .standard, level: site.healthLevel)
                    }
                    Spacer()
                    Text("\(site.healthPct)%")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(statusColor)
                }
                .padding(.leading, 18) // extra lead for accent bar
                .padding(.trailing, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(height: 0.5)

                // Stat row
                HStack(spacing: 0) {
                    statCell(
                        value: "\(site.goodDeviceCount)/\(site.deviceCount)",
                        label: "DEVICES",
                        icon: "network",
                        valueColor: .primary
                    )
                    Rectangle().fill(Color.cardBorder).frame(width: 0.5, height: 40)
                    statCell(
                        value: "\(site.clientCount)",
                        label: "CLIENTS",
                        icon: "person.2.fill",
                        valueColor: .primary
                    )
                    Rectangle().fill(Color.cardBorder).frame(width: 0.5, height: 40)
                    statCell(
                        value: "\(site.alertCount)",
                        label: "ALERTS",
                        icon: "bell.fill",
                        valueColor: site.alertCount == 0 ? .healthGood : .healthCritical
                    )
                }
                .padding(.vertical, 10)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .light ? .black.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )

            // 3pt leading accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(site.name), health \(site.healthPct) percent, " +
            "\(site.goodDeviceCount) of \(site.deviceCount) devices healthy, " +
            "\(site.clientCount) clients, \(site.alertCount) alerts"
        )
    }

    private func statCell(value: String, label: String, icon: String, valueColor: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        DashboardView(client: PreviewMockClient())
    }
}
```

- [ ] **Step 2: Build and run the full test suite**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'PASS|FAIL|error:|BUILD'
```

Expected: `BUILD SUCCEEDED`, all tests pass. The DashboardViewModel tests don't test view rendering so they're unaffected.

- [ ] **Step 3: Commit**

```bash
git add ArubaCentral/Features/Dashboard/DashboardView.swift
git commit -m "feat(brand): redesign SiteCardView and AlertSummaryCardView

Left health-color accent bar, cardBackground surfaces, appBackground canvas,
uppercase stat labels with tracking, monospacedDigit values.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: SiteDetailView Integration

**Files:**
- Modify: `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift`

**Interfaces:**
- Consumes: `SiteHealthHeaderView(site:)`, `DeviceStatusBadge(status:)`, `Color.appBackground`, `Color.cardBorder`
- Produces: Redesigned SiteDetailView with health header, branded section headers, `DeviceStatusBadge` in device rows, `appBackground` canvas

- [ ] **Step 1: Verify `DeviceRowView` is not used outside `SiteDetailView.swift`**

```bash
grep -rn "DeviceRowView" /Users/joshuaebibbs/XcodeProj/ArubaCentral/ArubaCentral/
```

`DevicesView.swift` uses `DeviceRowView` at multiple call sites. Do NOT rename or make it private. Instead, update `DeviceRowView` in-place to use `DeviceStatusBadge` and monospaced model text, keeping its public signature `DeviceRowView(name: String, model: String, status: DeviceStatus, uptime: Int?)` unchanged.

Replace the `DeviceRowView` struct body in `SiteDetailView.swift` with:

```swift
// Keep struct public and signature unchanged — DevicesView depends on it
struct DeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(model)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let uptime {
                        Text("Up \(uptimeString(uptime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            DeviceStatusBadge(status: status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days = seconds / 86400; let hours = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

This update is picked up automatically by `DevicesView` — no changes needed there.

- [ ] **Step 2: Replace `SiteDetailView.swift` entirely**

```swift
// ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift
import SwiftUI

struct SiteDetailView: View {
    @StateObject private var viewModel: SiteDetailViewModel

    init(site: Site) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site,
                                                                    apiClient: CentralAPIClient.placeholder))
    }

    init(site: Site, apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site, apiClient: apiClient))
    }

    var body: some View {
        List {
            // Health header
            Section {
                SiteHealthHeaderView(site: viewModel.site)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.appBackground)
                    .listRowSeparator(.hidden)
            }

            // APs
            apSection

            // Switches
            switchSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(viewModel.site.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var apSection: some View {
        Section {
            switch viewModel.apsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appBackground)

            case .loaded(let aps):
                if aps.isEmpty {
                    Text("No APs at this site")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.appBackground)
                } else {
                    ForEach(aps) { ap in
                        NavigationLink(value: ap) {
                            BrandedDeviceRowView(name: ap.name, model: ap.model, status: ap.status, uptime: ap.uptime)
                        }
                        .listRowBackground(Color.cardBackground)
                        .onAppear {
                            if ap.id == aps.last?.id { Task { await viewModel.loadNextAPPage() } }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .listRowBackground(Color.appBackground)
            }
        } header: {
            Text("Access Points".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(Color.brandNavy.opacity(0.7))
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var switchSection: some View {
        Section {
            switch viewModel.switchesState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.appBackground)

            case .loaded(let switches):
                if switches.isEmpty {
                    Text("No switches at this site")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.appBackground)
                } else {
                    ForEach(switches) { sw in
                        NavigationLink(value: sw) {
                            BrandedDeviceRowView(name: sw.name, model: sw.model, status: sw.status, uptime: sw.uptime)
                        }
                        .listRowBackground(Color.cardBackground)
                        .onAppear {
                            if sw.id == switches.last?.id { Task { await viewModel.loadNextSwitchPage() } }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .listRowBackground(Color.appBackground)
            }
        } header: {
            Text("Switches".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(Color.brandNavy.opacity(0.7))
                .padding(.top, 4)
        }
    }
}

// MARK: - Branded device row (replaces DeviceRowView for this screen)

private struct BrandedDeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                Text(model)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let uptime {
                    Text("Up \(uptimeString(uptime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            DeviceStatusBadge(status: status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days = seconds / 86400; let hours = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Placeholder for environment init

private extension CentralAPIClient {
    static var placeholder: CentralAPIClient {
        CentralAPIClient(authManager: AuthTokenManager(),
                         baseURL: CentralRegion.defaultRegion.baseURL)
    }
}

#Preview {
    NavigationStack {
        SiteDetailView(
            site: Site(id: "s1", name: "HQ Campus", healthPct: 90,
                       deviceCount: 28, clientCount: 310),
            apiClient: PreviewMockClient()
        )
    }
}
```

- [ ] **Step 2: Build and run the full test suite**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'PASS|FAIL|error:|BUILD'
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift
git commit -m "feat(brand): redesign SiteDetailView with health header and branded device rows

SiteHealthHeaderView replaces plain stat cards. BrandedDeviceRowView
uses DeviceStatusBadge and monospaced model text. appBackground canvas
with plain List style and scrollContentBackground hidden.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 11: AlertsView + AlertDetailView

**Files:**
- Modify: `ArubaCentral/Features/Alerts/AlertsView.swift`
- Modify: `ArubaCentral/Features/Alerts/AlertDetailView.swift`

**Interfaces:**
- Consumes: `AlertSeverityBadgeView(severity:)`, `Color.brandOrange`
- Produces: `AlertRowView` with severity badge pill and subtle tinted unread row background; `AlertDetailView` with severity badge header and orange-tinted acknowledge button

- [ ] **Step 1: Replace `AlertRowView` inside `AlertsView.swift`**

Only `AlertRowView` changes — the outer `AlertsView` structure is unchanged. Replace the `AlertRowView` struct:

```swift
// In ArubaCentral/Features/Alerts/AlertsView.swift
// Replace the existing AlertRowView struct with:

struct AlertRowView: View {
    let alert: CentralAlert

    var body: some View {
        HStack(spacing: 0) {
            // 4pt severity bar (existing pattern, unchanged)
            Rectangle()
                .fill(alert.isCleared ? Color.clear : alert.severity.color)
                .frame(width: 4)
                .clipShape(Capsule())
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: alert.severity.systemImage)
                    .foregroundStyle(alert.isCleared ? Color.secondary : alert.severity.color)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(alert.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(alert.isCleared ? .secondary : .primary)
                        if !alert.isCleared {
                            AlertSeverityBadgeView(severity: alert.severity)
                        }
                    }
                    HStack(spacing: 8) {
                        if let site = alert.siteName {
                            Text(site).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(alert.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if alert.isCleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.healthGood)
                        .imageScale(.small)
                        .accessibilityLabel("Acknowledged")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .listRowBackground(
            alert.isCleared
                ? Color.clear
                : alert.severity.color.opacity(0.04)
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let status = alert.isCleared ? "acknowledged" : "unacknowledged"
        return "\(alert.severity.rawValue) alert: \(alert.name), \(status)"
    }
}
```

- [ ] **Step 2: Replace `AlertDetailView.swift` entirely**

```swift
// ArubaCentral/Features/Alerts/AlertDetailView.swift
import SwiftUI

struct AlertDetailView: View {
    let alert: CentralAlert
    let onAcknowledge: () -> Void

    @State private var showingConfirm = false

    var body: some View {
        List {
            // Header section: icon + name + severity badge
            Section {
                HStack(spacing: 12) {
                    Image(systemName: alert.severity.systemImage)
                        .foregroundStyle(alert.severity.color)
                        .font(.title2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.name)
                            .font(.headline)
                        AlertSeverityBadgeView(severity: alert.severity)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                if let desc = alert.description {
                    Text(desc).font(.body).foregroundStyle(.secondary)
                }
                if let device = alert.deviceSerial {
                    LabeledContent("Device") {
                        Text(device)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Color.brandOrange)
                    }
                }
                if let site = alert.siteName {
                    LabeledContent("Site", value: site)
                }
                LabeledContent("Time", value: alert.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Status") {
                if alert.isCleared {
                    Label("Acknowledged", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.healthGood)
                } else {
                    Button {
                        showingConfirm = true
                    } label: {
                        Text("Acknowledge Alert")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(Color.brandOrange, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Alert Detail")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Acknowledge this alert?",
                            isPresented: $showingConfirm,
                            titleVisibility: .visible) {
            Button("Acknowledge") { onAcknowledge() }
        } message: {
            Text("This will mark the alert as cleared in Aruba Central.")
        }
    }
}

#Preview {
    NavigationStack {
        AlertDetailView(
            alert: CentralAlert(
                id: "a1", name: "AP Down", severity: .critical,
                description: "AP-Lobby (SN001) is unreachable.",
                deviceSerial: "SN001", siteName: "HQ Campus",
                createdAt: Date(), isCleared: false
            ),
            onAcknowledge: {}
        )
    }
}
```

- [ ] **Step 3: Build and run the full test suite**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'PASS|FAIL|error:|BUILD'
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add ArubaCentral/Features/Alerts/AlertsView.swift \
        ArubaCentral/Features/Alerts/AlertDetailView.swift
git commit -m "feat(brand): redesign AlertRowView and AlertDetailView

AlertRowView: severity badge pill, 0.04 opacity unread tint, subheadline
alert name. AlertDetailView: severity badge header, monospaced device serial
in brandOrange, full-width orange capsule acknowledge button.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 12: APDetailView

**Files:**
- Modify: `ArubaCentral/Features/Devices/APDetail/APDetailView.swift`

**Interfaces:**
- Consumes: `BrandedTabPicker(tabs:selection:)`, `Color.brandOrange`
- Produces: `APDetailView` using `BrandedTabPicker` for tab selection; Overview content with monospaced tech fields

- [ ] **Step 1: Replace the `Picker` block and update Overview content in `APDetailView.swift`**

Replace the `VStack(spacing: 0)` body that starts with `Picker("Tab", ...)` and replace `APOverviewContent`:

```swift
// ArubaCentral/Features/Devices/APDetail/APDetailView.swift
// Replace the var body: some View { VStack block and APOverviewContent struct

// In APDetailView.body, replace the VStack content:
var body: some View {
    VStack(spacing: 0) {
        BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: $selectedTab)
            .padding(.vertical, 8)

        Group {
            switch selectedTab {
            case 0: overviewTab
            case 1: radiosTab
            default: clientsTab
            }
        }
    }
    .navigationTitle(viewModel.ap.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { actionMenu }
    .task { await viewModel.load() }
    .refreshable { await viewModel.load() }
    .alert("Action Failed", isPresented: Binding(
        get: { viewModel.actionError != nil },
        set: { if !$0 { viewModel.actionError = nil } }
    )) {
        Button("OK") { viewModel.actionError = nil }
    } message: {
        Text(viewModel.actionError?.userMessage ?? "")
    }
    .confirmationDialog("Reboot \(viewModel.ap.name)?",
                        isPresented: $viewModel.showingRebootConfirm,
                        titleVisibility: .visible) {
        Button("Reboot", role: .destructive) { Task { await viewModel.rebootAP() } }
    } message: { Text("The AP will disconnect all clients briefly.") }
    .confirmationDialog("Blink LED on \(viewModel.ap.name)?",
                        isPresented: $viewModel.showingBlinkConfirm,
                        titleVisibility: .visible) {
        Button("Blink LED") { Task { await viewModel.blinkLED() } }
    }
}

// Replace APOverviewContent with:
private struct APOverviewContent: View {
    let ap: AccessPoint
    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Model",    value: ap.model)
                monoRow("Serial",   ap.serial)
                if let fw = ap.firmware  { monoRow("Firmware", fw) }
                if let ip = ap.ipAddress { monoRow("IP",       ip) }
                monoRow("MAC", ap.macAddress)
            }
            Section("Status") {
                LabeledContent("Status", value: ap.status == .up ? "Online" : "Offline")
                if let uptime = ap.uptime {
                    LabeledContent("Uptime", value: uptimeString(uptime))
                }
                if let count = ap.clientCount {
                    LabeledContent("Clients", value: "\(count)")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // Helper for monospaced tech-string rows
    @ViewBuilder
    private func monoRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func uptimeString(_ seconds: Int) -> String {
        let d = seconds / 86400; let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
```

- [ ] **Step 2: Build and run the full test suite**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'PASS|FAIL|error:|BUILD'
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add ArubaCentral/Features/Devices/APDetail/APDetailView.swift
git commit -m "feat(brand): APDetailView — BrandedTabPicker + monospaced tech fields

Replaces .segmented Picker with BrandedTabPicker. Serial, MAC, IP, and
firmware values use .monospaced caption style.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 13: SwitchDetailView + PortDiagramView

**Files:**
- Modify: `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift`
- Modify: `ArubaCentral/Shared/Components/PortDiagramView.swift`
- Modify: `ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift`

**Interfaces:**
- Consumes: `BrandedTabPicker(tabs:selection:)`, `Color.healthGood`, `Color.healthCritical`, `Color.healthWarning`
- Produces: `SwitchDetailView` with `BrandedTabPicker`; `PortDiagramView` with brand status colors and legend strip above the port grid

- [ ] **Step 1: Update `PortDiagramViewTests.swift` first**

The test `testPortColorDisabled` currently asserts `"orange"`. After the redesign, `.disabled` maps to `"amber"`:

```swift
// ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift
import XCTest
@testable import ArubaCentral

final class PortDiagramViewTests: XCTestCase {

    func testPortColorUp() {
        XCTAssertEqual(PortStatus.up.color, "up")
    }

    func testPortColorDown() {
        XCTAssertEqual(PortStatus.down.color, "down")
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
}
```

- [ ] **Step 2: Run the updated test — expect FAIL on color string tests**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/PortDiagramViewTests \
  2>&1 | grep -E 'PASS|FAIL|error:'
```

Expected: `testPortColorUp`, `testPortColorDown`, `testPortColorDisabled` FAIL (old strings "green", "gray", "orange").

- [ ] **Step 3: Replace `PortDiagramView.swift` entirely**

```swift
// ArubaCentral/Shared/Components/PortDiagramView.swift
import SwiftUI

enum PortDiagramLayout {
    static func columns(for count: Int) -> Int {
        count <= 8 ? 4 : 12
    }
}

extension PortStatus {
    // String identifier used in tests — semantic name, not CSS color
    var color: String {
        switch self {
        case .up:       return "up"
        case .down:     return "down"
        case .disabled: return "disabled"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .up:       return .healthGood
        case .down:     return Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280
        case .disabled: return .healthWarning
        }
    }

    var statusLabel: String {
        switch self {
        case .up:       return "Up"
        case .down:     return "Down"
        case .disabled: return "Disabled"
        }
    }
}

struct PortDiagramView: View {
    let ports: [SwitchInterface]
    let onBounce: (SwitchInterface) -> Void

    @State private var selectedPort: SwitchInterface? = nil

    private var columns: Int { PortDiagramLayout.columns(for: ports.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Legend strip
            PortLegendView()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView([.horizontal, .vertical]) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: columns),
                    spacing: 6
                ) {
                    ForEach(ports) { port in
                        PortCell(port: port)
                            .onTapGesture { selectedPort = port }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(port: port, onBounce: {
                onBounce(port)
                selectedPort = nil
            })
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Legend

private struct PortLegendView: View {
    var body: some View {
        HStack(spacing: 12) {
            legendPill(color: .healthGood,   label: "Up")
            legendPill(color: Color(red: 0.420, green: 0.447, blue: 0.502), label: "Down")
            legendPill(color: .healthWarning, label: "Disabled")
        }
    }

    private func legendPill(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Port cell

private struct PortCell: View {
    let port: SwitchInterface

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(port.status.swiftUIColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(port.status.swiftUIColor, lineWidth: 1.5)
            )
            .overlay(
                Text(shortPortId(port.portId))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(port.status.swiftUIColor)
            )
            .frame(width: 44, height: 44)
            .accessibilityLabel("Port \(port.portId), \(port.status.rawValue)")
    }

    private func shortPortId(_ id: String) -> String {
        id.components(separatedBy: "/").last ?? id
    }
}

// MARK: - Port detail sheet

private struct PortDetailSheet: View {
    let port: SwitchInterface
    let onBounce: () -> Void

    @State private var showingBounceConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Port Info") {
                    LabeledContent("Port ID") {
                        Text(port.portId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Status",  value: port.status.rawValue)
                    if let speed = port.speed { LabeledContent("Speed", value: formatSpeed(speed)) }
                    if let vlan  = port.vlan  {
                        LabeledContent("VLAN") {
                            Text("\(vlan)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let dev = port.connectedDevice { LabeledContent("Device", value: dev) }
                }
                if let tx = port.txBytes, let rx = port.rxBytes {
                    Section("Traffic") {
                        LabeledContent("TX", value: formatBytes(tx))
                        LabeledContent("RX", value: formatBytes(rx))
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showingBounceConfirm = true
                    } label: {
                        Label("Bounce Port", systemImage: "arrow.clockwise.circle")
                    }
                    // NOTE: Bounce port endpoint TBC (Open Item #1)
                } footer: {
                    Text("Bouncing a port briefly disconnects all devices on this port.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Port \(port.portId)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("Bounce port \(port.portId)?",
                            isPresented: $showingBounceConfirm,
                            titleVisibility: .visible) {
            Button("Bounce", role: .destructive, action: onBounce)
        } message: {
            Text("This will briefly disconnect all devices on this port.")
        }
    }

    private func formatSpeed(_ bps: Int) -> String {
        let gbps = Double(bps) / 1_000_000_000
        if gbps >= 1 { return String(format: "%.0f Gbps", gbps) }
        return String(format: "%.0f Mbps", Double(bps) / 1_000_000)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", mb / 1024)
    }
}

#Preview {
    PortDiagramView(
        ports: (1...24).map { i in
            SwitchInterface(portId: "1/1/\(i)",
                            status: i % 5 == 0 ? .down : (i % 7 == 0 ? .disabled : .up),
                            speed: 1_000_000_000, vlan: 10,
                            connectedDevice: nil,
                            txBytes: 1_000_000, rxBytes: 500_000)
        },
        onBounce: { _ in }
    )
}
```

- [ ] **Step 4: Update `SwitchDetailView.swift` — replace Picker with BrandedTabPicker**

Only the `VStack` body changes — replace the `Picker` block:

```swift
// In SwitchDetailView.body, replace:
//   Picker("Tab", selection: $selectedTab) { ... }.pickerStyle(.segmented)...
// with:
BrandedTabPicker(tabs: ["Overview", "Ports", "VLANs"], selection: $selectedTab)
    .padding(.vertical, 8)
```

The rest of `SwitchDetailView` is unchanged.

- [ ] **Step 5: Run the full test suite — expect all pass**

```bash
xcodebuild test -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E 'PASS|FAIL|error:|BUILD'
```

Expected: `BUILD SUCCEEDED`, all tests pass including updated `PortDiagramViewTests`.

- [ ] **Step 6: Commit**

```bash
git add ArubaCentral/Shared/Components/PortDiagramView.swift \
        ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift \
        ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift
git commit -m "feat(brand): SwitchDetailView BrandedTabPicker + port diagram brand colors

Port cells use healthGood/healthCritical/healthWarning tokens. Legend strip
above port grid. PortCell stroke reduced to 1.5pt. Port detail sheet uses
monospaced font for Port ID and VLAN values.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Post-Implementation Checklist

Run through these manually in the simulator before marking the feature complete.

**Light mode:**
- [ ] Dashboard: warm off-white canvas, white cards, health-color left bars, orange alert summary bar, navy nav bar, orange active tab
- [ ] SiteDetailView: health ring, branded section headers ("ACCESS POINTS"), DeviceStatusBadge pill on rows
- [ ] AP Detail: orange BrandedTabPicker pill on selected tab, monospaced serial/MAC/IP
- [ ] Switch Detail: port grid shows healthGood green / gray / healthWarning amber colors; legend strip visible
- [ ] Alerts: severity badge pill in rows, subtle red/amber tint on unread rows, orange capsule Acknowledge button

**Dark mode (manually toggle in Settings → Appearance → Dark):**
- [ ] Dashboard canvas is dark navy (`#0A1E38`), cards are `#112540`, no shadow rings visible
- [ ] Nav bar and tab bar are deeper navy (`#071526`) — visible distinction from card surfaces
- [ ] Health colors use dark-mode variants (brighter green, amber, red)
- [ ] `StatCardView` uses solid `cardBackground` — no material blur bleed-through

**Accessibility:**
- [ ] VoiceOver: activate on Dashboard — site cards read "Site name, health N percent, X of Y devices healthy, Z clients, N alerts"
- [ ] VoiceOver: BrandedTabPicker — each tab reads its label; selected tab has selected trait
- [ ] Dynamic Type: set to Accessibility Large in simulator — all text scales, no clipping
