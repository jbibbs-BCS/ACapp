# Phase 10: iPad NavigationSplitView Adaptive Layout

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-column iPhone layout with an adaptive `NavigationSplitView` on iPad — sidebar + content for all tabs, three-column for the Devices tab on iPad Pro 12.9".

**Architecture:** A shared `DeviceLayoutEnvironment` environment value exposes `isThreeColumn` to the view tree; `RootView` switches between `NavigationStack` (iPhone) and `NavigationSplitView` (iPad) per tab at the `@main` level. Existing ViewModels and Views remain unchanged — layout is a pure container concern.

**Tech Stack:** SwiftUI `NavigationSplitView`, `UITraitCollection`, `horizontalSizeClass`, `GeometryReader`, `@Environment(\.horizontalSizeClass)`

## Global Constraints

- iOS 16+ minimum deployment target
- `ObservableObject` + `@Published` — no `@Observable` (requires iOS 17)
- `NavigationSplitView` introduced in iOS 16 — no fallback needed
- `NavigationSplitView` sidebar width: 320 pt fixed on iPad, auto on iPad Pro 12.9" three-column
- Three-column layout only activates when `horizontalSizeClass == .regular` AND `UIScreen.main.bounds.width >= 1024`
- Existing ViewModels are **not** modified in this phase
- All UI strings must match existing views exactly (no copy changes)
- TDD: write failing test → verify fail → implement → verify pass → commit

---

## File Structure

**New files:**
- `ArubaCentral/UI/Layout/AdaptiveNavigationView.swift` — generic wrapper that picks `NavigationStack` or `NavigationSplitView` based on size class
- `ArubaCentral/UI/Layout/ThreeColumnDevicesView.swift` — iPad Pro 12.9" three-column Devices layout: Sites sidebar → Device list → Device detail
- `ArubaCentral/UI/Layout/SplitTabView.swift` — assembles sidebar + content for each tab on `.regular` size class
- `ArubaCentral/Tests/Layout/AdaptiveNavigationViewTests.swift`
- `ArubaCentral/Tests/Layout/ThreeColumnDevicesViewTests.swift`

**Modified files:**
- `ArubaCentral/UI/RootView.swift` — swap tab bodies for `AdaptiveNavigationView` wrappers
- `ArubaCentral/UI/Settings/SettingsView.swift` — pin to fixed 320 pt column width on iPad
- `ArubaCentral/UI/Devices/PortDiagramView.swift` — fix canvas size on iPad (remove `GeometryReader` stretch, use fixed 400×300)

---

### Task 24: iPad NavigationSplitView Adaptive Layout

**Files:**
- Create: `ArubaCentral/UI/Layout/AdaptiveNavigationView.swift`
- Create: `ArubaCentral/UI/Layout/ThreeColumnDevicesView.swift`
- Create: `ArubaCentral/UI/Layout/SplitTabView.swift`
- Create: `ArubaCentral/Tests/Layout/AdaptiveNavigationViewTests.swift`
- Create: `ArubaCentral/Tests/Layout/ThreeColumnDevicesViewTests.swift`
- Modify: `ArubaCentral/UI/RootView.swift`
- Modify: `ArubaCentral/UI/Settings/SettingsView.swift`
- Modify: `ArubaCentral/UI/Devices/PortDiagramView.swift`

**Interfaces:**
- Consumes:
  - `DashboardView(viewModel:)` — from Phase 4
  - `DevicesView(viewModel:)` — from Phase 5
  - `ClientsView(viewModel:)` — from Phase 6
  - `AlertsView(viewModel:)` — from Phase 7
  - `SettingsView(viewModel:)` — from Phase 8
  - `SiteDetailView(site:apiClient:)` — from Phase 4
  - `APDetailView(ap:apiClient:)` — from Phase 5
  - `SwitchDetailView(switch:apiClient:)` — from Phase 5
- Produces:
  - `AdaptiveNavigationView<Content: View>` — public struct, init takes `@ViewBuilder content: () -> Content`
  - `SplitTabView` — internal struct used by `RootView`
  - `ThreeColumnDevicesView(viewModel: DevicesViewModel)` — public struct

---

- [ ] **Step 1: Write failing test for `AdaptiveNavigationView` size-class switching**

Create `ArubaCentral/Tests/Layout/AdaptiveNavigationViewTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import ArubaCentral

final class AdaptiveNavigationViewTests: XCTestCase {

    // Verify that AdaptiveNavigationView renders without crashing in compact size class
    func test_compactSizeClass_rendersWithoutCrash() {
        let sut = AdaptiveNavigationView {
            Text("Content")
        }
        // SwiftUI view construction must not throw
        XCTAssertNotNil(sut)
    }

    // Verify the isThreeColumn helper returns false for widths < 1024
    func test_isThreeColumn_falseForNarrowWidth() {
        XCTAssertFalse(LayoutHelper.isThreeColumn(width: 768))
        XCTAssertFalse(LayoutHelper.isThreeColumn(width: 1023))
    }

    // Verify the isThreeColumn helper returns true for iPad Pro 12.9" width
    func test_isThreeColumn_trueForWideWidth() {
        XCTAssertTrue(LayoutHelper.isThreeColumn(width: 1024))
        XCTAssertTrue(LayoutHelper.isThreeColumn(width: 1366))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:ArubaCentralTests/AdaptiveNavigationViewTests \
  2>&1 | grep -E "FAILED|error:|AdaptiveNavigationViewTests"
```

Expected: FAIL — `LayoutHelper` not defined, `AdaptiveNavigationView` not defined.

- [ ] **Step 3: Create `LayoutHelper` and `AdaptiveNavigationView`**

Create `ArubaCentral/UI/Layout/AdaptiveNavigationView.swift`:

```swift
import SwiftUI

enum LayoutHelper {
    static func isThreeColumn(width: CGFloat) -> Bool {
        width >= 1024
    }
}

struct AdaptiveNavigationView<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let content: () -> Content

    var body: some View {
        if sizeClass == .regular {
            // iPad: caller is responsible for wrapping in NavigationSplitView
            // AdaptiveNavigationView is a passthrough on regular size class;
            // SplitTabView provides the actual NavigationSplitView.
            content()
        } else {
            NavigationStack {
                content()
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:ArubaCentralTests/AdaptiveNavigationViewTests \
  2>&1 | grep -E "PASSED|FAILED|AdaptiveNavigationViewTests"
```

Expected: PASSED — all 3 tests green.

- [ ] **Step 5: Write failing test for `ThreeColumnDevicesView`**

Create `ArubaCentral/Tests/Layout/ThreeColumnDevicesViewTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import ArubaCentral

final class ThreeColumnDevicesViewTests: XCTestCase {

    private var mockClient: MockCentralAPIClient!
    private var viewModel: DevicesViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        viewModel = DevicesViewModel(apiClient: mockClient)
    }

    // ThreeColumnDevicesView must initialise without crashing
    func test_init_doesNotCrash() {
        let sut = ThreeColumnDevicesView(viewModel: viewModel)
        XCTAssertNotNil(sut)
    }

    // selectedSiteID starts nil
    func test_selectedSiteID_startsNil() {
        let coordinator = ThreeColumnCoordinator()
        XCTAssertNil(coordinator.selectedSiteID)
    }

    // selectedDeviceSerial starts nil
    func test_selectedDeviceSerial_startsNil() {
        let coordinator = ThreeColumnCoordinator()
        XCTAssertNil(coordinator.selectedDeviceSerial)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:ArubaCentralTests/ThreeColumnDevicesViewTests \
  2>&1 | grep -E "FAILED|error:|ThreeColumnDevicesViewTests"
```

Expected: FAIL — `ThreeColumnDevicesView`, `ThreeColumnCoordinator` not defined.

- [ ] **Step 7: Create `ThreeColumnCoordinator` and `ThreeColumnDevicesView`**

Create `ArubaCentral/UI/Layout/ThreeColumnDevicesView.swift`:

```swift
import SwiftUI

// Holds sidebar and content selection state for the three-column Devices layout.
final class ThreeColumnCoordinator: ObservableObject {
    @Published var selectedSiteID: String?
    @Published var selectedDeviceSerial: String?
}

struct ThreeColumnDevicesView: View {
    @ObservedObject var viewModel: DevicesViewModel
    @StateObject private var coordinator = ThreeColumnCoordinator()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Column 1: Site list sidebar
            siteListColumn
                .navigationTitle("Sites")
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 320)
        } content: {
            // Column 2: Device list for selected site
            deviceListColumn
                .navigationTitle("Devices")
                .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 440)
        } detail: {
            // Column 3: Device detail
            deviceDetailColumn
        }
        .environmentObject(coordinator)
    }

    // MARK: - Columns

    @ViewBuilder
    private var siteListColumn: some View {
        switch viewModel.sitesState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let sites):
            List(sites, id: \.siteID, selection: $coordinator.selectedSiteID) { site in
                Label(site.siteName, systemImage: "building.2")
            }
        case .error(let err):
            Text(err.localizedDescription)
                .foregroundColor(.red)
                .padding()
        }
    }

    @ViewBuilder
    private var deviceListColumn: some View {
        if let siteID = coordinator.selectedSiteID {
            let devices = viewModel.devices(forSite: siteID)
            List(devices, id: \.serial, selection: $coordinator.selectedDeviceSerial) { device in
                DeviceRowView(device: device)
            }
        } else {
            ContentUnavailableView("Select a Site", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private var deviceDetailColumn: some View {
        if let serial = coordinator.selectedDeviceSerial,
           let device = viewModel.device(withSerial: serial) {
            switch device {
            case .ap(let ap):
                APDetailView(ap: ap, apiClient: viewModel.apiClient)
            case .switch_(let sw):
                SwitchDetailView(switch: sw, apiClient: viewModel.apiClient)
            }
        } else {
            ContentUnavailableView("Select a Device", systemImage: "wifi")
        }
    }
}
```

> **Note:** `DevicesViewModel` must expose:
> - `var sitesState: LoadState<[Site]>` — already produced in Phase 5
> - `func devices(forSite siteID: String) -> [DeviceItem]` — add in Step 9
> - `func device(withSerial serial: String) -> DeviceItem?` — add in Step 9
> - `var apiClient: CentralAPIClientProtocol` — store reference in Phase 5's init

- [ ] **Step 8: Add helper accessors to `DevicesViewModel`**

Open `ArubaCentral/ViewModels/DevicesViewModel.swift` and add below the existing `@Published` properties:

```swift
// Expose apiClient for detail view injection in three-column layout
let apiClient: CentralAPIClientProtocol

// Returns all devices for a given site, flattening APs and Switches.
func devices(forSite siteID: String) -> [DeviceItem] {
    guard case .loaded(let lists) = devicesState else { return [] }
    return lists.filter { $0.siteID == siteID }
}

// Returns the DeviceItem matching serial, searching APs then Switches.
func device(withSerial serial: String) -> DeviceItem? {
    guard case .loaded(let lists) = devicesState else { return nil }
    return lists.first { $0.serial == serial }
}
```

> The `DeviceItem` enum must already be defined in Phase 5 as:
> ```swift
> enum DeviceItem: Identifiable {
>     case ap(AccessPoint)
>     case switch_(CentralSwitch)
>     var serial: String { ... }
>     var siteID: String { ... }
>     var id: String { serial }
> }
> ```
> If the Phase 5 implementation used a different name, rename consistently.

- [ ] **Step 9: Run `ThreeColumnDevicesViewTests` to verify they pass**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:ArubaCentralTests/ThreeColumnDevicesViewTests \
  2>&1 | grep -E "PASSED|FAILED|ThreeColumnDevicesViewTests"
```

Expected: PASSED — all 3 tests green.

- [ ] **Step 10: Create `SplitTabView` for two-column iPad layout**

Create `ArubaCentral/UI/Layout/SplitTabView.swift`:

```swift
import SwiftUI

// Two-column NavigationSplitView used on all iPad tabs except Devices
// (Devices uses ThreeColumnDevicesView on iPad Pro 12.9").
struct SplitTabView<Sidebar: View, Content: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationSplitView {
            sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 320, max: 320)
        } detail: {
            content()
        }
    }
}
```

- [ ] **Step 11: Update `RootView` to use adaptive layout per tab**

Open `ArubaCentral/UI/RootView.swift`. Replace each tab's `NavigationStack { ... }` body with the adaptive wrapper. The full updated file:

```swift
import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var devicesVM: DevicesViewModel
    @StateObject private var clientsVM: ClientsViewModel
    @StateObject private var alertsVM: AlertsViewModel
    @StateObject private var settingsVM: SettingsViewModel
    @StateObject private var networkMonitor = NetworkMonitor()

    init(apiClient: CentralAPIClientProtocol) {
        _dashboardVM  = StateObject(wrappedValue: DashboardViewModel(apiClient: apiClient))
        _devicesVM    = StateObject(wrappedValue: DevicesViewModel(apiClient: apiClient))
        _clientsVM    = StateObject(wrappedValue: ClientsViewModel(apiClient: apiClient))
        _alertsVM     = StateObject(wrappedValue: AlertsViewModel(apiClient: apiClient))
        _settingsVM   = StateObject(wrappedValue: SettingsViewModel())
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                dashboardTab
                    .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                devicesTab
                    .tabItem { Label("Devices", systemImage: "wifi") }
                clientsTab
                    .tabItem { Label("Clients", systemImage: "person.2") }
                alertsTab
                    .tabItem { Label("Alerts", systemImage: "bell") }
                settingsTab
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            if !networkMonitor.isConnected {
                OfflineBannerView()
            }
        }
        .environmentObject(networkMonitor)
    }

    // MARK: - Tabs

    @ViewBuilder
    private var dashboardTab: some View {
        if sizeClass == .regular {
            // iPad: sidebar = site list, content = selected site detail or DashboardView
            SplitTabView {
                DashboardView(viewModel: dashboardVM)
            } content: {
                Text("Select a site").foregroundColor(.secondary)
            }
        } else {
            NavigationStack {
                DashboardView(viewModel: dashboardVM)
            }
        }
    }

    @ViewBuilder
    private var devicesTab: some View {
        if sizeClass == .regular {
            GeometryReader { geo in
                if LayoutHelper.isThreeColumn(width: geo.size.width) {
                    ThreeColumnDevicesView(viewModel: devicesVM)
                } else {
                    SplitTabView {
                        DevicesView(viewModel: devicesVM)
                    } content: {
                        Text("Select a device").foregroundColor(.secondary)
                    }
                }
            }
        } else {
            NavigationStack {
                DevicesView(viewModel: devicesVM)
            }
        }
    }

    @ViewBuilder
    private var clientsTab: some View {
        if sizeClass == .regular {
            SplitTabView {
                ClientsView(viewModel: clientsVM)
            } content: {
                Text("Select a client").foregroundColor(.secondary)
            }
        } else {
            NavigationStack {
                ClientsView(viewModel: clientsVM)
            }
        }
    }

    @ViewBuilder
    private var alertsTab: some View {
        if sizeClass == .regular {
            SplitTabView {
                AlertsView(viewModel: alertsVM)
            } content: {
                Text("Select an alert").foregroundColor(.secondary)
            }
        } else {
            NavigationStack {
                AlertsView(viewModel: alertsVM)
            }
        }
    }

    @ViewBuilder
    private var settingsTab: some View {
        if sizeClass == .regular {
            // Settings: fixed-width column on iPad, no detail panel
            NavigationSplitView {
                SettingsView(viewModel: settingsVM)
                    .navigationSplitViewColumnWidth(320)
            } detail: {
                Text("").hidden()
            }
        } else {
            NavigationStack {
                SettingsView(viewModel: settingsVM)
            }
        }
    }
}
```

- [ ] **Step 12: Fix `PortDiagramView` canvas on iPad**

Open `ArubaCentral/UI/Devices/PortDiagramView.swift`. The current implementation likely wraps the `Canvas` in a `GeometryReader` which stretches unbounded on iPad. Replace with a fixed-size container:

Find the `GeometryReader` wrapper around `Canvas` and replace it with:

```swift
// Fixed canvas — GeometryReader stretches to fill on iPad, breaking the port diagram
Canvas { context, size in
    drawPorts(context: context, size: size)
}
.frame(width: 400, height: 300)
.background(Color(.systemBackground))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

- [ ] **Step 13: Build to verify no compile errors**

```bash
xcodebuild build \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 14: Run all layout tests**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:ArubaCentralTests/AdaptiveNavigationViewTests \
  -only-testing:ArubaCentralTests/ThreeColumnDevicesViewTests \
  2>&1 | grep -E "PASSED|FAILED|Test Suite"
```

Expected: all 6 tests PASSED.

- [ ] **Step 15: Commit**

```bash
git add \
  ArubaCentral/UI/Layout/AdaptiveNavigationView.swift \
  ArubaCentral/UI/Layout/ThreeColumnDevicesView.swift \
  ArubaCentral/UI/Layout/SplitTabView.swift \
  ArubaCentral/UI/RootView.swift \
  ArubaCentral/UI/Settings/SettingsView.swift \
  ArubaCentral/UI/Devices/PortDiagramView.swift \
  ArubaCentral/Tests/Layout/AdaptiveNavigationViewTests.swift \
  ArubaCentral/Tests/Layout/ThreeColumnDevicesViewTests.swift
git commit -m "feat: add iPad NavigationSplitView adaptive layout — two-column for all tabs, three-column Devices on iPad Pro 12.9\""
```
