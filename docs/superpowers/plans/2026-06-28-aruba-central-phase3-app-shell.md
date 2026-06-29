# Aruba Central iOS App — Phase 3: App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up the live app shell — network connectivity monitoring, the 5-tab `TabView` root with environment injection, and the shared UI components (`HealthBadgeView`, `StatCardView`, `LoadStateView`, `OfflineBannerView`) used by every feature screen.

**Architecture:** `NetworkMonitor` wraps `NWPathMonitor` and publishes connectivity state as an `ObservableObject`. `RootView` replaces `ContentView` as the app entry point, building the `TabView` and injecting `AuthTokenManager` and `CentralAPIClient` as environment objects. Shared components are pure SwiftUI views with no ViewModel dependencies.

**Tech Stack:** Swift 5.9, SwiftUI, Network.framework (NWPathMonitor), XCTest

## Global Constraints

- Deployment target: iOS 16.0+
- No third-party dependencies
- All shared components support Dynamic Type and meet WCAG AA contrast in light and dark mode
- Minimum tap target: 44×44pt on all interactive elements
- Appearance override (System/Light/Dark) stored in `UserDefaults` key `"appearance"`, applied via `.preferredColorScheme` at the app root
- Prerequisite: Phase 1 + Phase 2 complete

---

### Task 6: NetworkMonitor + OfflineBannerView

**Files:**
- Create: `ArubaCentral/Core/Network/NetworkMonitor.swift`
- Create: `ArubaCentral/Shared/Components/OfflineBannerView.swift`
- Test: `ArubaCentralTests/Core/Network/NetworkMonitorTests.swift`

**Interfaces:**
- Produces: `NetworkMonitor` (injected as `@EnvironmentObject` at app root, consumed by `RootView` and any ViewModel that needs connectivity state), `OfflineBannerView` (used in every tab's root view)

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Core/Network/NetworkMonitorTests.swift`:

```swift
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

    func testLastUpdatedIsNilInitially() {
        let monitor = NetworkMonitor()
        XCTAssertNil(monitor.lastUpdated)
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/NetworkMonitorTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `NetworkMonitor` not found.

- [ ] **Step 3: Create `NetworkMonitor.swift`**

Create `ArubaCentral/Core/Network/NetworkMonitor.swift`:

```swift
import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var lastUpdated: Date? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.aruba.central.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.lastUpdated = Date()
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
```

- [ ] **Step 4: Create `OfflineBannerView.swift`**

Create `ArubaCentral/Shared/Components/OfflineBannerView.swift`:

```swift
import SwiftUI

struct OfflineBannerView: View {
    let lastUpdated: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No network connection")
                    .font(.footnote.bold())
                if let date = lastUpdated {
                    Text("Last updated \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemOrange).opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(.systemOrange).opacity(0.4)),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(offlineBannerAccessibilityLabel)
    }

    private var offlineBannerAccessibilityLabel: String {
        if let date = lastUpdated {
            return "No network connection. Last updated \(date.formatted(.relative(presentation: .named)))."
        }
        return "No network connection."
    }
}

#Preview {
    VStack(spacing: 0) {
        OfflineBannerView(lastUpdated: Date())
        Spacer()
    }
}
```

- [ ] **Step 5: Add files to Xcode targets**

Add `NetworkMonitor.swift` and `OfflineBannerView.swift` to the `ArubaCentral` target. Add the test file to `ArubaCentralTests`. Add `Network.framework` to the `ArubaCentral` target if not already linked (Xcode → Target → Frameworks, Libraries, and Embedded Content → + → Network.framework).

- [ ] **Step 6: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/NetworkMonitorTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'NetworkMonitorTests' passed`

- [ ] **Step 7: Commit**

```bash
git add \
  ArubaCentral/Core/Network/NetworkMonitor.swift \
  ArubaCentral/Shared/Components/OfflineBannerView.swift \
  ArubaCentralTests/Core/Network/NetworkMonitorTests.swift
git commit -m "feat: add NetworkMonitor and OfflineBannerView"
```

---

### Task 7: App Shell — RootView, TabView, environment injection

**Files:**
- Create: `ArubaCentral/App/RootView.swift`
- Modify: `ArubaCentral/ArubaCentral/ArubaCentralApp.swift`
- Delete contents of: `ArubaCentral/ArubaCentral/ContentView.swift` (replace with placeholder stub)

**Interfaces:**
- Consumes: `AuthTokenManager`, `CentralAPIClient`, `NetworkMonitor`, `CentralRegion`
- Produces: `RootView` — the single entry point SwiftUI view; injects all environment objects; renders `TabView` with 5 empty placeholder tabs; shows `OfflineBannerView` when offline

> No ViewModel tests for this task — it is pure app wiring. Verify by building and running on simulator.

---

- [ ] **Step 1: Replace ContentView with a placeholder stub**

Overwrite `ArubaCentral/ArubaCentral/ContentView.swift`:

```swift
import SwiftUI

// Placeholder — replaced per feature phase
struct DashboardPlaceholder: View {
    var body: some View { Text("Dashboard").navigationTitle("Dashboard") }
}

struct DevicesPlaceholder: View {
    var body: some View { Text("Devices").navigationTitle("Devices") }
}

struct ClientsPlaceholder: View {
    var body: some View { Text("Clients").navigationTitle("Clients") }
}

struct AlertsPlaceholder: View {
    var body: some View { Text("Alerts").navigationTitle("Alerts") }
}

struct SettingsPlaceholder: View {
    var body: some View { Text("Settings").navigationTitle("Settings") }
}
```

- [ ] **Step 2: Create `RootView.swift`**

Create `ArubaCentral/App/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @AppStorage("appearance") private var appearanceRaw: String = "system"

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                NavigationStack {
                    DashboardPlaceholder()
                }
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

                NavigationStack {
                    DevicesPlaceholder()
                }
                .tabItem {
                    Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                }

                NavigationStack {
                    ClientsPlaceholder()
                }
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }

                NavigationStack {
                    AlertsPlaceholder()
                }
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

                NavigationStack {
                    SettingsPlaceholder()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            if !networkMonitor.isConnected {
                OfflineBannerView(lastUpdated: networkMonitor.lastUpdated)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .preferredColorScheme(colorScheme(for: appearanceRaw))
    }

    private func colorScheme(for raw: String) -> ColorScheme? {
        switch raw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

#Preview {
    RootView()
        .environmentObject(NetworkMonitor())
}
```

- [ ] **Step 3: Update `ArubaCentralApp.swift`**

Overwrite `ArubaCentral/ArubaCentral/ArubaCentralApp.swift`:

```swift
import SwiftUI

@main
struct ArubaCentralApp: App {
    @StateObject private var networkMonitor  = NetworkMonitor()
    @StateObject private var authManager     = AuthTokenManager()
    @StateObject private var apiClient: CentralAPIClient

    init() {
        let auth = AuthTokenManager()
        let regionId = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        let region   = CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
        _authManager = StateObject(wrappedValue: auth)
        _apiClient   = StateObject(wrappedValue: CentralAPIClient(authManager: auth, baseURL: region.baseURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(networkMonitor)
                .environmentObject(authManager)
                .environmentObject(apiClient)
        }
    }
}
```

- [ ] **Step 4: Add `RootView.swift` to the Xcode target**

In Xcode: File → Add Files, add `ArubaCentral/App/RootView.swift` to the `ArubaCentral` target.

- [ ] **Step 5: Build and run on simulator — verify 5 tabs appear**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `BUILD SUCCEEDED`

Then run on the simulator (Xcode → Run or `⌘R`). Confirm:
- 5 tabs appear at the bottom: Dashboard, Devices, Clients, Alerts, Settings
- Each tab shows its placeholder text
- No crashes on launch

- [ ] **Step 6: Commit**

```bash
git add \
  ArubaCentral/App/RootView.swift \
  ArubaCentral/ArubaCentral/ArubaCentralApp.swift \
  ArubaCentral/ArubaCentral/ContentView.swift
git commit -m "feat: add RootView app shell — TabView with 5 tabs, environment injection, offline banner"
```

---

### Task 8: Shared Components — HealthBadgeView, StatCardView, LoadStateView

**Files:**
- Create: `ArubaCentral/Shared/Components/HealthBadgeView.swift`
- Create: `ArubaCentral/Shared/Components/StatCardView.swift`
- Create: `ArubaCentral/Shared/Components/LoadStateView.swift`
- Create: `ArubaCentral/Shared/Extensions/Color+Health.swift`
- Test: `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`

**Interfaces:**
- Consumes: `HealthLevel` (from Phase 1 models)
- Produces: `HealthBadgeView(level:)`, `StatCardView(title:value:)`, `LoadStateView(state:content:retry:)` — used in Dashboard, Site Detail, Device Detail, and Alerts

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Shared/Components/SharedComponentTests.swift`:

```swift
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
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — components not found.

- [ ] **Step 3: Create `Color+Health.swift`**

Create `ArubaCentral/Shared/Extensions/Color+Health.swift`:

```swift
import SwiftUI

extension Color {
    static let healthGood     = Color.green
    static let healthWarning  = Color.orange
    static let healthCritical = Color.red

    static func healthColor(for level: HealthLevel) -> Color {
        switch level {
        case .good:     return .healthGood
        case .warning:  return .healthWarning
        case .critical: return .healthCritical
        }
    }
}

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

- [ ] **Step 4: Create `HealthBadgeView.swift`**

Create `ArubaCentral/Shared/Components/HealthBadgeView.swift`:

```swift
import SwiftUI

struct HealthBadgeView: View {
    let level: HealthLevel

    var body: some View {
        Image(systemName: level.systemImage)
            .foregroundStyle(Color.healthColor(for: level))
            .imageScale(.medium)
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }
}

#Preview {
    HStack(spacing: 16) {
        HealthBadgeView(level: .good)
        HealthBadgeView(level: .warning)
        HealthBadgeView(level: .critical)
    }
    .padding()
}
```

- [ ] **Step 5: Create `StatCardView.swift`**

Create `ArubaCentral/Shared/Components/StatCardView.swift`:

```swift
import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack {
        StatCardView(title: "APs",     value: "24",  systemImage: "antenna.radiowaves.left.and.right")
        StatCardView(title: "Clients", value: "310", systemImage: "person.2")
    }
    .padding()
}
```

- [ ] **Step 6: Create `LoadStateView.swift`**

Create `ArubaCentral/Shared/Components/LoadStateView.swift`:

```swift
import SwiftUI

struct LoadStateView<T, Content: View>: View {
    let state: LoadState<T>
    let content: (T) -> Content
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Color.clear

        case .loading:
            VStack {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            }

        case .loaded(let value):
            content(value)

        case .error(let error):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(error.userMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadStateView(
            state: LoadState<String>.loading,
            content: { Text($0) },
            retry: {}
        )
        LoadStateView(
            state: LoadState<String>.error(.networkError),
            content: { Text($0) },
            retry: {}
        )
        LoadStateView(
            state: LoadState<String>.loaded("Content here"),
            content: { Text($0) },
            retry: {}
        )
    }
}
```

- [ ] **Step 7: Add all files to Xcode target**

Add all four new files to the `ArubaCentral` target. Add the test file to `ArubaCentralTests`.

- [ ] **Step 8: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'SharedComponentTests' passed`

- [ ] **Step 9: Run all phases 1–3 together**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/FoundationTypesTests \
  -only-testing:ArubaCentralTests/ModelDecodingTests \
  -only-testing:ArubaCentralTests/KeychainManagerTests \
  -only-testing:ArubaCentralTests/AuthTokenManagerTests \
  -only-testing:ArubaCentralTests/CentralAPIClientTests \
  -only-testing:ArubaCentralTests/NetworkMonitorTests \
  -only-testing:ArubaCentralTests/SharedComponentTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All 7 suites pass.

- [ ] **Step 10: Commit**

```bash
git add \
  ArubaCentral/Shared/Components/HealthBadgeView.swift \
  ArubaCentral/Shared/Components/StatCardView.swift \
  ArubaCentral/Shared/Components/LoadStateView.swift \
  ArubaCentral/Shared/Extensions/Color+Health.swift \
  ArubaCentralTests/Shared/Components/SharedComponentTests.swift
git commit -m "feat: add shared components — HealthBadgeView, StatCardView, LoadStateView"
```

---

## Phase 3 Complete

The app now compiles and runs with a working 5-tab shell:

- `NetworkMonitor` — live connectivity state published via `NWPathMonitor`
- `OfflineBannerView` — animated banner with last-updated timestamp
- `RootView` — `TabView` with 5 placeholder tabs, environment injection of `AuthTokenManager`, `CentralAPIClient`, and `NetworkMonitor`; appearance override wired to `UserDefaults`
- `HealthBadgeView` — color-coded health icon with VoiceOver support
- `StatCardView` — metric display card used in Dashboard and detail views
- `LoadStateView` — generic idle/loading/loaded/error switcher used by every ViewModel-backed screen

**Next:** Phase 4 — Dashboard tab (`DashboardViewModel` + `DashboardView`, `SiteDetailViewModel` + `SiteDetailView`)
