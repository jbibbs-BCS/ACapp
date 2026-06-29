# Aruba Central iOS App — Phase 4: Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Dashboard tab (site-health list with pull-to-refresh) and Site Detail screen (per-site device list with infinite scroll), replacing both placeholder views.

**Architecture:** `DashboardViewModel` and `SiteDetailViewModel` conform to `ObservableObject`, consume `CentralAPIClientProtocol`, and expose `LoadState<T>` for the view to render. All ViewModel logic is tested using `MockCentralAPIClient` from Phase 2. Views are SwiftUI only — no logic tested at the view layer.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, `MockCentralAPIClient`

## Global Constraints

- Deployment target: iOS 16.0+
- Page size for device lists: 100
- Pull-to-refresh reloads from offset 0
- Offline: show last in-memory data + `OfflineBannerView` (already wired in RootView); ViewModels store last successful response in a plain property — no disk persistence
- Prerequisite: Phases 1–3 complete

---

### Task 9: DashboardViewModel + DashboardView

**Files:**
- Create: `ArubaCentral/Features/Dashboard/DashboardViewModel.swift`
- Create: `ArubaCentral/Features/Dashboard/DashboardView.swift`
- Modify: `ArubaCentral/ArubaCentral/ContentView.swift` — replace `DashboardPlaceholder` with `DashboardView`
- Test: `ArubaCentralTests/Features/Dashboard/DashboardViewModelTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchSiteHealth()`, `Site`, `HealthLevel`, `LoadState`, `HealthBadgeView`, `StatCardView`, `LoadStateView`
- Produces: `DashboardViewModel` (consumed by `DashboardView`), `DashboardView` (placed in the Dashboard tab)

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Dashboard/DashboardViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class DashboardViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: DashboardViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = DashboardViewModel(client: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.sitesState { } else {
            XCTFail("Expected idle, got \(sut.sitesState)")
        }
    }

    // MARK: - load()

    func testLoadSetsLoadingThenLoaded() async {
        let sites = [makeSite(id: "s1", name: "HQ", score: 90)]
        mockClient.sitesResult = .success(sites)

        await sut.load()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "HQ")
    }

    func testLoadCallsFetchSiteHealthOnce() async {
        mockClient.sitesResult = .success([])
        await sut.load()
        XCTAssertEqual(mockClient.fetchSitesCallCount, 1)
    }

    func testLoadSetsErrorStateOnFailure() async {
        mockClient.sitesResult = .failure(.networkError)
        await sut.load()

        guard case .error(let error) = sut.sitesState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .networkError)
    }

    func testLoadSetsErrorForbidden() async {
        mockClient.sitesResult = .failure(.forbidden)
        await sut.load()

        guard case .error(let error) = sut.sitesState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .forbidden)
    }

    // MARK: - refresh()

    func testRefreshReloadsFromScratch() async {
        let firstBatch  = [makeSite(id: "s1", name: "Old", score: 50)]
        let secondBatch = [makeSite(id: "s1", name: "New", score: 90)]
        mockClient.sitesResult = .success(firstBatch)
        await sut.load()

        mockClient.sitesResult = .success(secondBatch)
        await sut.refresh()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].name, "New")
        XCTAssertEqual(mockClient.fetchSitesCallCount, 2)
    }

    // MARK: - sorting

    func testSitesAreSortedByCriticalFirst() async {
        let sites = [
            makeSite(id: "s1", name: "Good",     score: 95),
            makeSite(id: "s2", name: "Critical",  score: 20),
            makeSite(id: "s3", name: "Warning",   score: 60),
        ]
        mockClient.sitesResult = .success(sites)
        await sut.load()

        guard case .loaded(let result) = sut.sitesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].name, "Critical")
        XCTAssertEqual(result[1].name, "Warning")
        XCTAssertEqual(result[2].name, "Good")
    }

    // MARK: - Helpers

    private func makeSite(id: String, name: String, score: Int) -> Site {
        Site(id: id, name: name, healthScore: score, apCount: 1, switchCount: 1, clientCount: 1)
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
  -only-testing:ArubaCentralTests/DashboardViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `DashboardViewModel` not found.

- [ ] **Step 3: Create `DashboardViewModel.swift`**

Create `ArubaCentral/Features/Dashboard/DashboardViewModel.swift`:

```swift
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var sitesState: LoadState<[Site]> = .idle

    private let client: CentralAPIClientProtocol

    init(client: CentralAPIClientProtocol) {
        self.client = client
    }

    func load() async {
        sitesState = .loading
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            let sites = try await client.fetchSiteHealth()
            let sorted = sites.sorted {
                $0.healthLevel.sortOrder < $1.healthLevel.sortOrder
            }
            sitesState = .loaded(sorted)
        } catch let error as APIError {
            sitesState = .error(error)
        } catch {
            sitesState = .error(.networkError)
        }
    }
}

private extension HealthLevel {
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .warning:  return 1
        case .good:     return 2
        }
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/DashboardViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'DashboardViewModelTests' passed`

- [ ] **Step 5: Create `DashboardView.swift`**

Create `ArubaCentral/Features/Dashboard/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var client: CentralAPIClient

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(client: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.sitesState,
            content: { sites in siteList(sites) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Dashboard")
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func siteList(_ sites: [Site]) -> some View {
        if sites.isEmpty {
            ContentUnavailableView(
                "No Sites",
                systemImage: "building.2",
                description: Text("No sites found in your Central account.")
            )
        } else {
            List(sites) { site in
                NavigationLink(value: site) {
                    SiteRowView(site: site)
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
        }
    }
}

struct SiteRowView: View {
    let site: Site

    var body: some View {
        HStack(spacing: 12) {
            HealthBadgeView(level: site.healthLevel)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                HStack(spacing: 16) {
                    Label("\(site.apCount) APs",      systemImage: "antenna.radiowaves.left.and.right")
                    Label("\(site.switchCount) SWs",  systemImage: "network")
                    Label("\(site.clientCount) Clients", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(site.name), health \(site.healthLevel.accessibilityLabel), " +
        "\(site.apCount) APs, \(site.switchCount) switches, \(site.clientCount) clients"
    }
}

#Preview {
    NavigationStack {
        DashboardView(client: PreviewMockClient())
    }
}
```

- [ ] **Step 6: Add a PreviewMockClient for SwiftUI previews**

Create `ArubaCentral/Shared/Preview/PreviewMockClient.swift`:

```swift
import Foundation

#if DEBUG
final class PreviewMockClient: CentralAPIClientProtocol {
    func fetchSiteHealth() async throws -> [Site] {
        [
            Site(id: "s1", name: "HQ Campus",    healthScore: 95, apCount: 24, switchCount: 4, clientCount: 310),
            Site(id: "s2", name: "Branch Office", healthScore: 62, apCount: 8,  switchCount: 2, clientCount: 47),
            Site(id: "s3", name: "Warehouse",     healthScore: 15, apCount: 4,  switchCount: 1, clientCount: 12),
        ]
    }
    func fetchAPs(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint> { .empty() }
    func fetchAPDetail(serial: String) async throws -> AccessPoint { throw APIError.networkError }
    func fetchAPRadios(serial: String) async throws -> [Radio] { [] }
    func fetchAPClients(serial: String, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> { .empty() }
    func fetchSwitches(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralSwitch> { .empty() }
    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch { throw APIError.networkError }
    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] { [] }
    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] { [] }
    func fetchClients(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> { .empty() }
    func fetchClientDetail(macAddress: String) async throws -> CentralClient { throw APIError.networkError }
    func fetchAlerts(limit: Int, offset: Int) async throws -> PaginatedResponse<CentralAlert> { .empty() }
    func clearAlert(alertId: String) async throws {}
    func rebootAP(serial: String) async throws {}
    func blinkAPLED(serial: String) async throws {}
    func disconnectAllClientsFromAP(serial: String) async throws {}
    func testConnection() async throws {}
}
#endif
```

- [ ] **Step 7: Replace DashboardPlaceholder in ContentView.swift**

In `ArubaCentral/ArubaCentral/ContentView.swift`, update the `DashboardPlaceholder` stub. The tab in `RootView.swift` already uses `DashboardPlaceholder` — replace the tab's content with `DashboardView`:

Open `ArubaCentral/App/RootView.swift` and replace the Dashboard tab block:

```swift
// Before:
NavigationStack {
    DashboardPlaceholder()
}
.tabItem {
    Label("Dashboard", systemImage: "square.grid.2x2")
}

// After:
NavigationStack {
    DashboardView(client: apiClient)
}
.tabItem {
    Label("Dashboard", systemImage: "square.grid.2x2")
}
```

Also add `@EnvironmentObject private var apiClient: CentralAPIClient` to `RootView`.

- [ ] **Step 8: Add all new files to Xcode targets**

Add to `ArubaCentral`:
- `ArubaCentral/Features/Dashboard/DashboardViewModel.swift`
- `ArubaCentral/Features/Dashboard/DashboardView.swift`
- `ArubaCentral/Shared/Preview/PreviewMockClient.swift`

Add to `ArubaCentralTests`:
- `ArubaCentralTests/Features/Dashboard/DashboardViewModelTests.swift`

- [ ] **Step 9: Build and verify on simulator**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `BUILD SUCCEEDED`. Run on simulator — Dashboard tab shows a loading spinner then a site list (or error card if no credentials set).

- [ ] **Step 10: Commit**

```bash
git add \
  ArubaCentral/Features/Dashboard/DashboardViewModel.swift \
  ArubaCentral/Features/Dashboard/DashboardView.swift \
  ArubaCentral/Shared/Preview/PreviewMockClient.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Dashboard/DashboardViewModelTests.swift
git commit -m "feat: add Dashboard tab — site health list with health badges and pull-to-refresh"
```

---

### Task 10: SiteDetailViewModel + SiteDetailView

**Files:**
- Create: `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailViewModel.swift`
- Create: `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift`
- Test: `ArubaCentralTests/Features/Dashboard/SiteDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchAPs()`, `CentralAPIClientProtocol.fetchSwitches()`, `AccessPoint`, `CentralSwitch`, `PaginatedResponse`, `LoadState`, `StatCardView`, `HealthBadgeView`, `LoadStateView`
- Produces: `SiteDetailViewModel`, `SiteDetailView` — navigated to from `DashboardView` when a site row is tapped

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Dashboard/SiteDetailViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class SiteDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: SiteDetailViewModel!
    let site = Site(id: "s1", name: "HQ", healthScore: 90, apCount: 2, switchCount: 1, clientCount: 50)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = SiteDetailViewModel(site: site, client: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialAPsStateIsIdle() {
        if case .idle = sut.apsState { } else {
            XCTFail("Expected idle")
        }
    }

    func testInitialSwitchesStateIsIdle() {
        if case .idle = sut.switchesState { } else {
            XCTFail("Expected idle")
        }
    }

    // MARK: - load()

    func testLoadFetchesAPsForSite() async {
        let aps = [makeAP(serial: "AP1"), makeAP(serial: "AP2")]
        mockClient.apsResult = .success(PaginatedResponse.of(aps))
        mockClient.switchesResult = .success(.empty())

        await sut.load()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
    }

    func testLoadFetchesSwitchesForSite() async {
        mockClient.apsResult = .success(.empty())
        let switches = [makeSW(serial: "SW1")]
        mockClient.switchesResult = .success(PaginatedResponse.of(switches))

        await sut.load()

        guard case .loaded(let result) = sut.switchesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 1)
    }

    func testLoadSetsAPsErrorOnFailure() async {
        mockClient.apsResult = .failure(.serverError(503))
        mockClient.switchesResult = .success(.empty())

        await sut.load()

        guard case .error(let error) = sut.apsState else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(error, .serverError(503))
    }

    // MARK: - Pagination

    func testLoadNextAPPageAppendsItems() async {
        let firstPage  = (0..<100).map { makeAP(serial: "AP\($0)") }
        let secondPage = (100..<150).map { makeAP(serial: "AP\($0)") }

        mockClient.apsResult = .success(PaginatedResponse(items: firstPage, total: 150, offset: 0, limit: 100))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        mockClient.apsResult = .success(PaginatedResponse(items: secondPage, total: 150, offset: 100, limit: 100))
        await sut.loadNextAPPage()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 150)
    }

    func testLoadNextAPPageDoesNothingWhenNoMore() async {
        let aps = [makeAP(serial: "AP1")]
        mockClient.apsResult = .success(PaginatedResponse.of(aps))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        let callsBefore = mockClient.fetchAPsCallCount
        await sut.loadNextAPPage()
        XCTAssertEqual(mockClient.fetchAPsCallCount, callsBefore,
                       "Should not fetch when hasMore is false")
    }

    func testLoadNextSwitchPageAppendsItems() async {
        let firstPage  = (0..<100).map { makeSW(serial: "SW\($0)") }
        let secondPage = (100..<120).map { makeSW(serial: "SW\($0)") }

        mockClient.apsResult = .success(.empty())
        mockClient.switchesResult = .success(PaginatedResponse(items: firstPage, total: 120, offset: 0, limit: 100))
        await sut.load()

        mockClient.switchesResult = .success(PaginatedResponse(items: secondPage, total: 120, offset: 100, limit: 100))
        await sut.loadNextSwitchPage()

        guard case .loaded(let result) = sut.switchesState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result.count, 120)
    }

    // MARK: - refresh()

    func testRefreshResetsOffsetAndReloads() async {
        let firstBatch = [makeAP(serial: "OLD")]
        mockClient.apsResult = .success(PaginatedResponse.of(firstBatch))
        mockClient.switchesResult = .success(.empty())
        await sut.load()

        let freshBatch = [makeAP(serial: "NEW")]
        mockClient.apsResult = .success(PaginatedResponse.of(freshBatch))
        await sut.refresh()

        guard case .loaded(let result) = sut.apsState else {
            return XCTFail("Expected loaded")
        }
        XCTAssertEqual(result[0].serial, "NEW")
    }

    // MARK: - Helpers

    private func makeAP(serial: String) -> AccessPoint {
        AccessPoint(serial: serial, name: serial, model: "AP-635",
                    status: .up, ipAddress: nil, macAddress: nil,
                    firmware: nil, uptime: nil, site: "HQ", clientCount: 0)
    }

    private func makeSW(serial: String) -> CentralSwitch {
        CentralSwitch(serial: serial, name: serial, model: "6300M",
                      status: .up, ipAddress: nil, macAddress: nil,
                      firmware: nil, uptime: nil, site: "HQ", stackId: nil)
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SiteDetailViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `SiteDetailViewModel` not found.

- [ ] **Step 3: Create `SiteDetailViewModel.swift`**

Create `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailViewModel.swift`:

```swift
import Foundation

@MainActor
final class SiteDetailViewModel: ObservableObject {
    @Published private(set) var apsState: LoadState<[AccessPoint]>      = .idle
    @Published private(set) var switchesState: LoadState<[CentralSwitch]> = .idle

    let site: Site
    private let client: CentralAPIClientProtocol
    private let pageSize = 100

    private var apOffset       = 0
    private var apHasMore      = false
    private var isLoadingMoreAPs = false

    private var switchOffset         = 0
    private var switchHasMore        = false
    private var isLoadingMoreSwitches = false

    init(site: Site, client: CentralAPIClientProtocol) {
        self.site   = site
        self.client = client
    }

    func load() async {
        apsState      = .loading
        switchesState = .loading
        apOffset      = 0
        switchOffset  = 0

        async let apsTask     = fetchAPs(offset: 0, appending: false)
        async let switchesTask = fetchSwitches(offset: 0, appending: false)
        await apsTask
        await switchesTask
    }

    func refresh() async {
        apOffset     = 0
        switchOffset = 0
        async let apsTask     = fetchAPs(offset: 0, appending: false)
        async let switchesTask = fetchSwitches(offset: 0, appending: false)
        await apsTask
        await switchesTask
    }

    func loadNextAPPage() async {
        guard apHasMore, !isLoadingMoreAPs else { return }
        isLoadingMoreAPs = true
        defer { isLoadingMoreAPs = false }
        await fetchAPs(offset: apOffset, appending: true)
    }

    func loadNextSwitchPage() async {
        guard switchHasMore, !isLoadingMoreSwitches else { return }
        isLoadingMoreSwitches = true
        defer { isLoadingMoreSwitches = false }
        await fetchSwitches(offset: switchOffset, appending: true)
    }

    // MARK: - Private fetch

    private func fetchAPs(offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchAPs(site: site.name, search: nil,
                                                  limit: pageSize, offset: offset)
            apOffset  = offset + page.items.count
            apHasMore = page.hasMore

            if appending, case .loaded(let existing) = apsState {
                apsState = .loaded(existing + page.items)
            } else {
                apsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { apsState = .error(error) }
        } catch {
            if !appending { apsState = .error(.networkError) }
        }
    }

    private func fetchSwitches(offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchSwitches(site: site.name, search: nil,
                                                       limit: pageSize, offset: offset)
            switchOffset  = offset + page.items.count
            switchHasMore = page.hasMore

            if appending, case .loaded(let existing) = switchesState {
                switchesState = .loaded(existing + page.items)
            } else {
                switchesState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { switchesState = .error(error) }
        } catch {
            if !appending { switchesState = .error(.networkError) }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SiteDetailViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'SiteDetailViewModelTests' passed`

- [ ] **Step 5: Create `SiteDetailView.swift`**

Create `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift`:

```swift
import SwiftUI

struct SiteDetailView: View {
    @StateObject private var viewModel: SiteDetailViewModel
    @EnvironmentObject private var apiClient: CentralAPIClient

    init(site: Site) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site,
                                                                    client: CentralAPIClient.placeholder))
    }

    init(site: Site, client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SiteDetailViewModel(site: site, client: client))
    }

    var body: some View {
        List {
            siteHealthSection
            apSection
            switchSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.site.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Sections

    private var siteHealthSection: some View {
        Section {
            HStack(spacing: 12) {
                StatCardView(title: "APs",
                             value: "\(viewModel.site.apCount)",
                             systemImage: "antenna.radiowaves.left.and.right")
                StatCardView(title: "Switches",
                             value: "\(viewModel.site.switchCount)",
                             systemImage: "network")
                StatCardView(title: "Clients",
                             value: "\(viewModel.site.clientCount)",
                             systemImage: "person.2")
            }
            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            HStack {
                HealthBadgeView(level: viewModel.site.healthLevel)
                Text("Site Health")
            }
        }
    }

    @ViewBuilder
    private var apSection: some View {
        Section {
            switch viewModel.apsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

            case .loaded(let aps):
                if aps.isEmpty {
                    Text("No APs at this site")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(aps) { ap in
                        NavigationLink(value: ap) {
                            DeviceRowView(name: ap.name, model: ap.model,
                                         status: ap.status, uptime: ap.uptime)
                        }
                        .onAppear {
                            if ap.id == aps.last?.id {
                                Task { await viewModel.loadNextAPPage() }
                            }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("Access Points")
        }
    }

    @ViewBuilder
    private var switchSection: some View {
        Section {
            switch viewModel.switchesState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

            case .loaded(let switches):
                if switches.isEmpty {
                    Text("No switches at this site")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(switches) { sw in
                        NavigationLink(value: sw) {
                            DeviceRowView(name: sw.name, model: sw.model,
                                         status: sw.status, uptime: sw.uptime)
                        }
                        .onAppear {
                            if sw.id == switches.last?.id {
                                Task { await viewModel.loadNextSwitchPage() }
                            }
                        }
                    }
                }

            case .error(let error):
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("Switches")
        }
    }
}

// MARK: - Shared device row

struct DeviceRowView: View {
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status == .up ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let uptime {
                        Text("Up \(uptimeString(uptime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(model), \(status == .up ? "online" : "offline")")
    }

    private func uptimeString(_ seconds: Int) -> String {
        let days    = seconds / 86400
        let hours   = (seconds % 86400) / 3600
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
            site: Site(id: "s1", name: "HQ Campus", healthScore: 90,
                       apCount: 24, switchCount: 4, clientCount: 310),
            client: PreviewMockClient()
        )
    }
}
```

- [ ] **Step 6: Wire NavigationDestination in DashboardView**

In `DashboardView.swift`, the `NavigationLink(value: site)` already resolves to `SiteDetailView`. Now add `navigationDestination` for `AccessPoint` and `CentralSwitch` so deeper navigation from Site Detail works. Add to the `NavigationStack` in `RootView.swift` (Dashboard tab):

```swift
// In RootView.swift, Dashboard NavigationStack:
NavigationStack {
    DashboardView(client: apiClient)
        .navigationDestination(for: AccessPoint.self) { ap in
            APDetailPlaceholder(ap: ap)   // replaced in Phase 5
        }
        .navigationDestination(for: CentralSwitch.self) { sw in
            SwitchDetailPlaceholder(sw: sw) // replaced in Phase 5
        }
}
```

Add stubs to `ContentView.swift`:

```swift
struct APDetailPlaceholder: View {
    let ap: AccessPoint
    var body: some View { Text(ap.name).navigationTitle(ap.name) }
}

struct SwitchDetailPlaceholder: View {
    let sw: CentralSwitch
    var body: some View { Text(sw.name).navigationTitle(sw.name) }
}
```

- [ ] **Step 7: Add all files to Xcode targets**

Add to `ArubaCentral`:
- `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailViewModel.swift`
- `ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift`

Add to `ArubaCentralTests`:
- `ArubaCentralTests/Features/Dashboard/SiteDetailViewModelTests.swift`

- [ ] **Step 8: Run all Phase 4 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/DashboardViewModelTests \
  -only-testing:ArubaCentralTests/SiteDetailViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: Both suites pass.

- [ ] **Step 9: Build and verify on simulator**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Run on simulator. Confirm:
- Dashboard shows site list with health badges, AP/switch/client counts
- Tapping a site navigates to Site Detail
- Site Detail shows AP and switch lists with device rows
- Tapping a device shows the placeholder detail (replaced in Phase 5)
- Pull-to-refresh works on both screens

- [ ] **Step 10: Commit**

```bash
git add \
  ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailViewModel.swift \
  ArubaCentral/Features/Dashboard/SiteDetail/SiteDetailView.swift \
  ArubaCentral/ArubaCentral/ContentView.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Dashboard/SiteDetailViewModelTests.swift
git commit -m "feat: add Site Detail — paginated AP and switch list with infinite scroll"
```

---

## Phase 4 Complete

The Dashboard is fully functional end-to-end:

- `DashboardViewModel` — fetches site health, sorts critical-first, exposes `LoadState<[Site]>`; 7 unit tests
- `DashboardView` — site list with `HealthBadgeView`, `StatCardView` counts, `NavigationLink` to Site Detail; pull-to-refresh
- `SiteDetailViewModel` — parallel AP + switch fetch per site, independent pagination with `hasMore` tracking, refresh resets offsets; 10 unit tests
- `SiteDetailView` — two paginated sections with infinite-scroll trigger on last visible row; `DeviceRowView` shared component used by Devices tab in Phase 5
- `PreviewMockClient` — SwiftUI preview support for all feature views

**Next:** Phase 5 — Devices tab (`DevicesView`, `APDetailView`, `SwitchDetailView`, `PortDiagramView`)
