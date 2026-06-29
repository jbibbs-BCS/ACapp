# Phase 11: Global Search

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire a debounced, API-backed search bar into the Dashboard, Devices, and Clients nav bars. Searches by hostname, IP address, and MAC address. Returns unified results regardless of whether the matching records are already loaded in local state.

**Architecture:** A single `GlobalSearchViewModel` drives all three search bars. The VM debounces keystrokes (400 ms), then calls `CentralAPIClient` search endpoints in parallel for APs, Switches, and Clients, collects results into a `[SearchResult]` array, and publishes them. Each host view displays results in a floating list overlay that disappears when the search field is cleared.

**Tech Stack:** SwiftUI `searchable`, Combine `debounce`, `Task`, `CentralAPIClientProtocol`

## Global Constraints

- iOS 16+ minimum deployment target
- `ObservableObject` + `@Published` — no `@Observable` (requires iOS 17)
- Debounce interval: 400 ms
- Search is triggered at ≥ 2 characters; fewer characters clear results immediately
- Search fields accept: hostname (plain text), IP address (`\d+\.\d+\.\d+\.\d+`), MAC address (`[0-9a-fA-F:]{17}` or `[0-9a-fA-F-]{17}`)
- New Central API endpoints for search:
  - APs: `GET /accesspointsv1?search={query}&limit=50&offset=0`
  - Switches: `GET /switchesv1?search={query}&limit=50&offset=0`
  - Clients: `GET /clientsv1?search={query}&limit=50&offset=0`
- Rate limit: 10 calls/second — parallel AP + Switch + Client search counts as 3 calls; respect the limit
- `CentralAPIClientProtocol` is **not** modified — add search to the existing `fetchAPs`, `fetchSwitches`, `fetchClients` methods via the existing `query` parameter (or add dedicated `searchAPs`, `searchSwitches`, `searchClients` methods if the protocol doesn't yet have query params)
- TDD: write failing test → verify fail → implement → verify pass → commit

---

## File Structure

**New files:**
- `ArubaCentral/ViewModels/GlobalSearchViewModel.swift` — `ObservableObject`, debounce logic, parallel search, result aggregation
- `ArubaCentral/Models/SearchResult.swift` — `SearchResult` enum with `.ap(AccessPoint)`, `.switch_(CentralSwitch)`, `.client(CentralClient)` cases
- `ArubaCentral/UI/Components/SearchResultsOverlay.swift` — floating list view, reused by all three tabs
- `ArubaCentral/Tests/ViewModels/GlobalSearchViewModelTests.swift`

**Modified files:**
- `ArubaCentral/Networking/CentralAPIClientProtocol.swift` — add `searchDevices(query:) async throws -> [SearchResult]` if not already present
- `ArubaCentral/Networking/CentralAPIClient.swift` — implement `searchDevices`
- `ArubaCentral/Networking/MockCentralAPIClient.swift` — add `searchDevicesResult` configurable stub
- `ArubaCentral/UI/Dashboard/DashboardView.swift` — add `.searchable` + results overlay
- `ArubaCentral/UI/Devices/DevicesView.swift` — add `.searchable` + results overlay
- `ArubaCentral/UI/Clients/ClientsView.swift` — add `.searchable` + results overlay

---

### Task 25: Global Search

**Files:**
- Create: `ArubaCentral/Models/SearchResult.swift`
- Create: `ArubaCentral/ViewModels/GlobalSearchViewModel.swift`
- Create: `ArubaCentral/UI/Components/SearchResultsOverlay.swift`
- Create: `ArubaCentral/Tests/ViewModels/GlobalSearchViewModelTests.swift`
- Modify: `ArubaCentral/Networking/CentralAPIClientProtocol.swift`
- Modify: `ArubaCentral/Networking/CentralAPIClient.swift`
- Modify: `ArubaCentral/Networking/MockCentralAPIClient.swift`
- Modify: `ArubaCentral/UI/Dashboard/DashboardView.swift`
- Modify: `ArubaCentral/UI/Devices/DevicesView.swift`
- Modify: `ArubaCentral/UI/Clients/ClientsView.swift`

**Interfaces:**
- Consumes:
  - `CentralAPIClientProtocol.searchDevices(query: String) async throws -> [SearchResult]` — added in Step 3
  - `AccessPoint`, `CentralSwitch`, `CentralClient` — from Phase 1
  - `LoadState<T>` — from Phase 1
  - `MockCentralAPIClient` — from Phase 2
- Produces:
  - `SearchResult` — enum, three cases: `.ap(AccessPoint)`, `.switch_(CentralSwitch)`, `.client(CentralClient)`; conforms to `Identifiable` via computed `var id: String`
  - `GlobalSearchViewModel` — `@Published var query: String`, `@Published var results: LoadState<[SearchResult]>`, `@Published var isSearching: Bool`
  - `SearchResultsOverlay(viewModel:)` — `View` struct, takes `@ObservedObject var viewModel: GlobalSearchViewModel`

---

- [ ] **Step 1: Write failing tests for `GlobalSearchViewModel`**

Create `ArubaCentral/Tests/ViewModels/GlobalSearchViewModelTests.swift`:

```swift
import XCTest
import Combine
@testable import ArubaCentral

@MainActor
final class GlobalSearchViewModelTests: XCTestCase {

    private var mockClient: MockCentralAPIClient!
    private var sut: GlobalSearchViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = GlobalSearchViewModel(apiClient: mockClient)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // Query shorter than 2 chars must produce .idle immediately (no search fired)
    func test_shortQuery_staysIdle() async throws {
        sut.query = "a"
        // Allow one runloop pass
        try await Task.sleep(nanoseconds: 10_000_000)
        guard case .idle = sut.results else {
            XCTFail("Expected .idle for 1-character query, got \(sut.results)")
            return
        }
    }

    // Empty query clears results back to .idle
    func test_emptyQuery_clearsResults() async throws {
        mockClient.searchDevicesResult = .success([
            .ap(AccessPoint.stub())
        ])
        sut.query = "myAP"
        // Wait for debounce + simulated async work
        try await Task.sleep(nanoseconds: 600_000_000) // 600ms
        sut.query = ""
        try await Task.sleep(nanoseconds: 10_000_000)
        guard case .idle = sut.results else {
            XCTFail("Expected .idle after clearing query, got \(sut.results)")
            return
        }
    }

    // Successful search yields .loaded with results
    func test_successfulSearch_yieldsLoadedResults() async throws {
        let ap = AccessPoint.stub(name: "TestAP")
        mockClient.searchDevicesResult = .success([.ap(ap)])

        sut.query = "TestAP"
        try await Task.sleep(nanoseconds: 600_000_000) // wait for debounce + fetch

        guard case .loaded(let results) = sut.results else {
            XCTFail("Expected .loaded, got \(sut.results)")
            return
        }
        XCTAssertEqual(results.count, 1)
        if case .ap(let fetchedAP) = results[0] {
            XCTAssertEqual(fetchedAP.name, "TestAP")
        } else {
            XCTFail("Expected .ap case")
        }
    }

    // API error yields .error state
    func test_apiError_yieldsErrorState() async throws {
        mockClient.searchDevicesResult = .failure(APIError.unauthorized)
        sut.query = "broken"
        try await Task.sleep(nanoseconds: 600_000_000)

        guard case .error = sut.results else {
            XCTFail("Expected .error, got \(sut.results)")
            return
        }
    }

    // isSearching is true during fetch, false after
    func test_isSearching_togglesDuringFetch() async throws {
        // Slow stub: 300ms delay
        mockClient.searchDevicesResult = .success([])
        mockClient.searchDevicesDelay = 0.3

        sut.query = "latency"
        try await Task.sleep(nanoseconds: 500_000_000) // after debounce fires, before response

        XCTAssertTrue(sut.isSearching)

        try await Task.sleep(nanoseconds: 400_000_000) // after response
        XCTAssertFalse(sut.isSearching)
    }
}
```

> **Note:** `AccessPoint.stub()` must be a static factory on `AccessPoint` returning a valid instance with default values. Add it in the next step.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/GlobalSearchViewModelTests \
  2>&1 | grep -E "FAILED|error:|GlobalSearchViewModelTests"
```

Expected: FAIL — `GlobalSearchViewModel`, `SearchResult`, `MockCentralAPIClient.searchDevicesResult` not defined.

- [ ] **Step 3: Create `SearchResult` model**

Create `ArubaCentral/Models/SearchResult.swift`:

```swift
import Foundation

enum SearchResult: Identifiable {
    case ap(AccessPoint)
    case switch_(CentralSwitch)
    case client(CentralClient)

    var id: String {
        switch self {
        case .ap(let ap):          return "ap-\(ap.serial)"
        case .switch_(let sw):     return "sw-\(sw.serial)"
        case .client(let client):  return "cl-\(client.macAddress)"
        }
    }

    var displayName: String {
        switch self {
        case .ap(let ap):          return ap.name
        case .switch_(let sw):     return sw.name
        case .client(let client):  return client.name.isEmpty ? client.ipAddress : client.name
        }
    }

    var systemImage: String {
        switch self {
        case .ap:      return "wifi"
        case .switch_: return "rectangle.connected.to.line.below"
        case .client:  return "person.circle"
        }
    }

    var siteName: String {
        switch self {
        case .ap(let ap):          return ap.siteName
        case .switch_(let sw):     return sw.siteName
        case .client(let client):  return client.siteName
        }
    }
}
```

- [ ] **Step 4: Add `searchDevices` to `CentralAPIClientProtocol`**

Open `ArubaCentral/Networking/CentralAPIClientProtocol.swift` and add one method to the protocol:

```swift
/// Search APs, Switches, and Clients in parallel by hostname, IP, or MAC.
func searchDevices(query: String) async throws -> [SearchResult]
```

- [ ] **Step 5: Implement `searchDevices` in `CentralAPIClient`**

Open `ArubaCentral/Networking/CentralAPIClient.swift` and add:

```swift
func searchDevices(query: String) async throws -> [SearchResult] {
    async let aps     = fetchAPs(siteID: nil, search: query, limit: 50, offset: 0)
    async let switches = fetchSwitches(siteID: nil, search: query, limit: 50, offset: 0)
    async let clients  = fetchClients(siteID: nil, search: query, limit: 50, offset: 0)

    let (apPage, swPage, clPage) = try await (aps, switches, clients)

    var results: [SearchResult] = []
    results += apPage.items.map { .ap($0) }
    results += swPage.items.map { .switch_($0) }
    results += clPage.items.map { .client($0) }
    return results
}
```

> `fetchAPs`, `fetchSwitches`, `fetchClients` must already accept optional `siteID` and `search` parameters from Phase 2. If `search` isn't a parameter yet, add it:
> ```swift
> // In fetchAPs signature:
> func fetchAPs(siteID: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint>
> ```
> Update the URL construction in each method to append `&search=\(query)` when `search != nil`.

- [ ] **Step 6: Add stub to `MockCentralAPIClient`**

Open `ArubaCentral/Networking/MockCentralAPIClient.swift` and add:

```swift
var searchDevicesResult: Result<[SearchResult], APIError> = .success([])
var searchDevicesDelay: TimeInterval = 0
private(set) var searchDevicesCallCount = 0
private(set) var lastSearchQuery: String?

func searchDevices(query: String) async throws -> [SearchResult] {
    searchDevicesCallCount += 1
    lastSearchQuery = query
    if searchDevicesDelay > 0 {
        try await Task.sleep(nanoseconds: UInt64(searchDevicesDelay * 1_000_000_000))
    }
    return try searchDevicesResult.get()
}
```

- [ ] **Step 7: Add `AccessPoint.stub()` test helper**

Open or create `ArubaCentral/Tests/Helpers/ModelStubs.swift` and add:

```swift
import Foundation
@testable import ArubaCentral

extension AccessPoint {
    static func stub(
        serial: String = "CNX001",
        name: String = "TestAP",
        model: String = "AP-515",
        status: String = "Up",
        ipAddress: String = "10.0.0.1",
        macAddress: String = "aa:bb:cc:dd:ee:ff",
        firmware: String = "10.7.0.0",
        uptime: Int = 86400,
        siteName: String = "HQ",
        clientCount: Int = 5
    ) -> AccessPoint {
        AccessPoint(
            serial: serial,
            name: name,
            model: model,
            status: status,
            ipAddress: ipAddress,
            macAddress: macAddress,
            firmware: firmware,
            uptime: uptime,
            siteName: siteName,
            clientCount: clientCount
        )
    }
}
```

- [ ] **Step 8: Create `GlobalSearchViewModel`**

Create `ArubaCentral/ViewModels/GlobalSearchViewModel.swift`:

```swift
import Foundation
import Combine

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: LoadState<[SearchResult]> = .idle
    @Published private(set) var isSearching: Bool = false

    private let apiClient: CentralAPIClientProtocol
    private var searchTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: CentralAPIClientProtocol) {
        self.apiClient = apiClient
        setupDebounce()
    }

    private func setupDebounce() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.handleQueryChange(query)
            }
            .store(in: &cancellables)
    }

    private func handleQueryChange(_ query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            results = .idle
            isSearching = false
            return
        }
        searchTask = Task {
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        results = .loading
        do {
            let found = try await apiClient.searchDevices(query: query)
            guard !Task.isCancelled else { return }
            results = .loaded(found)
        } catch {
            guard !Task.isCancelled else { return }
            results = .error(error as? APIError ?? .unknown(error.localizedDescription))
        }
        isSearching = false
    }
}
```

- [ ] **Step 9: Run `GlobalSearchViewModelTests` to verify they pass**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/GlobalSearchViewModelTests \
  2>&1 | grep -E "PASSED|FAILED|GlobalSearchViewModelTests"
```

Expected: PASSED — all 5 tests green.

- [ ] **Step 10: Create `SearchResultsOverlay`**

Create `ArubaCentral/UI/Components/SearchResultsOverlay.swift`:

```swift
import SwiftUI

struct SearchResultsOverlay: View {
    @ObservedObject var viewModel: GlobalSearchViewModel
    var onSelect: (SearchResult) -> Void

    var body: some View {
        switch viewModel.results {
        case .idle:
            EmptyView()
        case .loading:
            HStack {
                ProgressView()
                Text("Searching…").foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        case .loaded(let results) where results.isEmpty:
            HStack {
                Image(systemName: "magnifyingglass")
                Text("No results for "\(viewModel.query)"").foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        case .loaded(let results):
            List(results) { result in
                Button {
                    onSelect(result)
                } label: {
                    HStack {
                        Image(systemName: result.systemImage)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.displayName).font(.body)
                            Text(result.siteName).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .frame(maxHeight: 320)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 6)
            .padding(.horizontal)
        case .error(let err):
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text(err.localizedDescription).foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 4)
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 11: Wire search into `DashboardView`**

Open `ArubaCentral/UI/Dashboard/DashboardView.swift`.

Add a `@StateObject` for search above the existing body:

```swift
@StateObject private var searchVM = GlobalSearchViewModel(apiClient: viewModel.apiClient)
@State private var searchPath = NavigationPath()
```

Add `.searchable` and overlay to the view's `NavigationStack`/list. In the body, after the main list/content:

```swift
.searchable(text: $searchVM.query, prompt: "Search by hostname, IP, or MAC")
.overlay(alignment: .top) {
    if !searchVM.query.isEmpty {
        SearchResultsOverlay(viewModel: searchVM) { result in
            handleSearchSelection(result)
        }
        .padding(.top, 8)
    }
}
```

Add the handler (within `DashboardView`, below body):

```swift
private func handleSearchSelection(_ result: SearchResult) {
    // Navigate to the appropriate detail view
    // Uses NavigationPath on iPhone; on iPad, this is handled by the split view
    searchVM.query = ""
    switch result {
    case .ap(let ap):
        searchPath.append(ap)
    case .switch_(let sw):
        searchPath.append(sw)
    case .client(let client):
        searchPath.append(client)
    }
}
```

> If `DashboardView` doesn't already own a `NavigationPath`, add `@State private var path = NavigationPath()` and wrap the list in `NavigationStack(path: $path)` with `.navigationDestination` for `AccessPoint`, `CentralSwitch`, and `CentralClient`.

- [ ] **Step 12: Wire search into `DevicesView`**

Open `ArubaCentral/UI/Devices/DevicesView.swift`.

Add at the top of `DevicesView`:

```swift
@StateObject private var searchVM = GlobalSearchViewModel(apiClient: viewModel.apiClient)
```

Add `.searchable` and overlay to the view's `NavigationStack`/list body, identical to Step 11 but using the Devices navigation path:

```swift
.searchable(text: $searchVM.query, prompt: "Search by hostname, IP, or MAC")
.overlay(alignment: .top) {
    if !searchVM.query.isEmpty {
        SearchResultsOverlay(viewModel: searchVM) { result in
            handleDeviceSearchSelection(result)
        }
        .padding(.top, 8)
    }
}
```

Add handler:

```swift
private func handleDeviceSearchSelection(_ result: SearchResult) {
    searchVM.query = ""
    switch result {
    case .ap(let ap):
        viewModel.selectedDevice = .ap(ap)
    case .switch_(let sw):
        viewModel.selectedDevice = .switch_(sw)
    case .client:
        break // Clients tab handles clients
    }
}
```

> `viewModel.selectedDevice` is the published property used to drive `NavigationLink` / `NavigationSplitView` detail. If it doesn't exist by this name, use whatever published selection property Phase 5 produced.

- [ ] **Step 13: Wire search into `ClientsView`**

Open `ArubaCentral/UI/Clients/ClientsView.swift`.

Add at the top of `ClientsView`:

```swift
@StateObject private var searchVM = GlobalSearchViewModel(apiClient: viewModel.apiClient)
```

Add `.searchable` and overlay (Clients already has a site picker from Phase 6; the search bar coexists with it):

```swift
.searchable(text: $searchVM.query, prompt: "Search by hostname, IP, or MAC")
.overlay(alignment: .top) {
    if !searchVM.query.isEmpty {
        SearchResultsOverlay(viewModel: searchVM) { result in
            handleClientSearchSelection(result)
        }
        .padding(.top, 8)
    }
}
```

Add handler:

```swift
private func handleClientSearchSelection(_ result: SearchResult) {
    searchVM.query = ""
    if case .client(let client) = result {
        viewModel.selectedClient = client
    }
}
```

> `viewModel.selectedClient` is the `@Published var selectedClient: CentralClient?` that drives `NavigationLink` / detail view. If Phase 6 used a different name, use that name.

- [ ] **Step 14: Build and verify no compile errors**

```bash
xcodebuild build \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 15: Run full test suite**

```bash
xcodebuild test \
  -project ArubaCentral/ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "PASSED|FAILED|Test Suite 'All tests'"
```

Expected: All test suites PASSED.

- [ ] **Step 16: Commit**

```bash
git add \
  ArubaCentral/Models/SearchResult.swift \
  ArubaCentral/ViewModels/GlobalSearchViewModel.swift \
  ArubaCentral/UI/Components/SearchResultsOverlay.swift \
  ArubaCentral/Tests/ViewModels/GlobalSearchViewModelTests.swift \
  ArubaCentral/Tests/Helpers/ModelStubs.swift \
  ArubaCentral/Networking/CentralAPIClientProtocol.swift \
  ArubaCentral/Networking/CentralAPIClient.swift \
  ArubaCentral/Networking/MockCentralAPIClient.swift \
  ArubaCentral/UI/Dashboard/DashboardView.swift \
  ArubaCentral/UI/Devices/DevicesView.swift \
  ArubaCentral/UI/Clients/ClientsView.swift
git commit -m "feat: add global search — debounced API-backed search by hostname, IP, MAC across Dashboard, Devices, Clients"
```
