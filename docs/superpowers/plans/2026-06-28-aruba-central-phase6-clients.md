# Aruba Central iOS App — Phase 6: Clients Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Clients tab (site picker + global search + unified wireless/wired list) and Client Detail screen with Disconnect action placeholder.

**Architecture:** `ClientsViewModel` manages site selection, search debouncing, and paginated client loading. `ClientDetailView` is a stateless detail screen driven by a passed `CentralClient`. Both ViewModel tests use `MockCentralAPIClient`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest

## Global Constraints

- Deployment target: iOS 16.0+
- Page size: 100 clients per fetch
- Default state: empty list — user must select a site or enter a search query
- Global search queries API with `search=` param across all clients regardless of site filter
- Search is debounced 300ms via `Task.sleep`
- Disconnect individual client is a placeholder (open item #2 from spec); fallback is `disconnectAllClientsFromAP`
- Prerequisite: Phases 1–5 complete

---

### Task 15: ClientsViewModel + ClientsView

**Files:**
- Create: `ArubaCentral/Features/Clients/ClientsViewModel.swift`
- Create: `ArubaCentral/Features/Clients/ClientsView.swift`
- Modify: `ArubaCentral/App/RootView.swift` — replace `ClientsPlaceholder` with `ClientsView`
- Test: `ArubaCentralTests/Features/Clients/ClientsViewModelTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchClients()`, `CentralClient`, `PaginatedResponse`, `LoadState`
- Produces: `ClientsViewModel`, `ClientsView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Clients/ClientsViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class ClientsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: ClientsViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = ClientsViewModel(client: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle") }
    }

    func testInitialSelectedSiteIsNil() {
        XCTAssertNil(sut.selectedSite)
    }

    // MARK: - selectSite

    func testSelectSiteLoadsClients() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ Campus")
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ Campus")
        guard case .loaded(let items) = sut.clientsState else { return XCTFail() }
        XCTAssertEqual(items.count, 1)
    }

    func testSelectSiteUpdatesSelectedSite() async {
        mockClient.clientsResult = .success(.empty())
        await sut.selectSite("Branch")
        XCTAssertEqual(sut.selectedSite, "Branch")
    }

    func testSelectNilSiteResetsToIdle() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        await sut.selectSite(nil)
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle after clearing site") }
    }

    // MARK: - search

    func testSearchQuerySentToAPI() async {
        mockClient.clientsResult = .success(.empty())
        await sut.search(query: "10.0.1.5")
        XCTAssertEqual(mockClient.lastSearchQuery, "10.0.1.5")
    }

    func testSearchWithSiteFilterKeepsSite() async {
        mockClient.clientsResult = .success(.empty())
        sut.selectedSite = "HQ"
        await sut.search(query: "mac-addr")
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
        XCTAssertEqual(mockClient.lastSearchQuery, "mac-addr")
    }

    func testEmptySearchWithSiteReloadsForSite() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        await sut.search(query: "")
        // Should reload for site, not search
        XCTAssertNil(mockClient.lastSearchQuery)
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ")
    }

    func testEmptySearchWithNoSiteResetsToIdle() async {
        await sut.search(query: "")
        if case .idle = sut.clientsState { } else { XCTFail("Expected idle") }
    }

    // MARK: - Pagination

    func testLoadNextPageAppendsClients() async {
        let firstPage  = (0..<100).map { makeClient("aa:\($0)") }
        let secondPage = (100..<130).map { makeClient("bb:\($0)") }

        mockClient.clientsResult = .success(PaginatedResponse(items: firstPage, total: 130, offset: 0, limit: 100))
        await sut.selectSite("HQ")

        mockClient.clientsResult = .success(PaginatedResponse(items: secondPage, total: 130, offset: 100, limit: 100))
        await sut.loadNextPage()

        guard case .loaded(let items) = sut.clientsState else { return XCTFail() }
        XCTAssertEqual(items.count, 130)
    }

    func testLoadNextPageDoesNothingWhenNoMore() async {
        mockClient.clientsResult = .success(.of([makeClient("aa:11")]))
        await sut.selectSite("HQ")
        let callsBefore = mockClient.fetchSitesCallCount
        await sut.loadNextPage()
        // fetchClients call count should not increase
        XCTAssertEqual(mockClient.fetchSitesCallCount, callsBefore)
    }

    // MARK: - wireless/wired grouping

    func testWirelessClientsCount() async {
        let clients = [
            makeClient("aa:11", type: .wireless),
            makeClient("bb:22", type: .wireless),
            makeClient("cc:33", type: .wired),
        ]
        mockClient.clientsResult = .success(.of(clients))
        await sut.selectSite("HQ")
        XCTAssertEqual(sut.wirelessClients.count, 2)
        XCTAssertEqual(sut.wiredClients.count, 1)
    }

    // MARK: - Helpers

    private func makeClient(_ mac: String, type: ClientConnectionType = .wireless) -> CentralClient {
        CentralClient(macAddress: mac, name: "Device-\(mac)", ipAddress: "10.0.0.1",
                      connectionType: type, associatedDeviceSerial: nil, site: "HQ",
                      ssid: type == .wireless ? "Corp" : nil, vlan: nil, port: nil,
                      signalStrength: nil, txDataRate: nil, rxDataRate: nil, connectedAt: nil)
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
  -only-testing:ArubaCentralTests/ClientsViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `ClientsViewModel` not found.

- [ ] **Step 3: Create `ClientsViewModel.swift`**

Create `ArubaCentral/Features/Clients/ClientsViewModel.swift`:

```swift
import Foundation

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published private(set) var clientsState: LoadState<[CentralClient]> = .idle
    @Published private(set) var selectedSite: String? = nil

    private let client: CentralAPIClientProtocol
    private let pageSize = 100
    private var offset   = 0
    private var hasMore  = false
    private var isLoadingMore = false
    private var allClients: [CentralClient] = []

    var wirelessClients: [CentralClient] {
        guard case .loaded(let items) = clientsState else { return [] }
        return items.filter { $0.connectionType == .wireless }
    }

    var wiredClients: [CentralClient] {
        guard case .loaded(let items) = clientsState else { return [] }
        return items.filter { $0.connectionType == .wired }
    }

    init(client: CentralAPIClientProtocol) {
        self.client = client
    }

    func selectSite(_ site: String?) async {
        selectedSite = site
        guard let site else { clientsState = .idle; return }
        offset = 0
        clientsState = .loading
        await fetchClients(site: site, search: nil, offset: 0, appending: false)
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            if let site = selectedSite { await selectSite(site) }
            else { clientsState = .idle }
            return
        }
        offset = 0
        clientsState = .loading
        await fetchClients(site: selectedSite, search: query, offset: 0, appending: false)
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        guard let site = selectedSite else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchClients(site: site, search: nil, offset: offset, appending: true)
    }

    func refresh() async {
        guard let site = selectedSite else { return }
        offset = 0
        await fetchClients(site: site, search: nil, offset: 0, appending: false)
    }

    private func fetchClients(site: String?, search: String?, offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchClients(site: site, search: search,
                                                      limit: pageSize, offset: offset)
            self.offset = offset + page.items.count
            self.hasMore = page.hasMore

            if appending, case .loaded(let existing) = clientsState {
                clientsState = .loaded(existing + page.items)
            } else {
                clientsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { clientsState = .error(error) }
        } catch {
            if !appending { clientsState = .error(.networkError) }
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
  -only-testing:ArubaCentralTests/ClientsViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'ClientsViewModelTests' passed`

- [ ] **Step 5: Create `ClientsView.swift`**

Create `ArubaCentral/Features/Clients/ClientsView.swift`:

```swift
import SwiftUI

struct ClientsView: View {
    @StateObject private var viewModel: ClientsViewModel
    @State private var searchText = ""
    @State private var showingSitePicker = false

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: ClientsViewModel(client: client))
    }

    var body: some View {
        Group {
            switch viewModel.clientsState {
            case .idle:
                emptyPrompt

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                clientList

            case .error(let error):
                VStack(spacing: 16) {
                    Spacer()
                    Text(error.userMessage).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    Button("Try Again") { Task { await viewModel.refresh() } }.buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .navigationTitle("Clients")
        .searchable(text: $searchText, prompt: "IP, MAC, or hostname")
        .onChange(of: searchText) { _, q in Task { await viewModel.search(query: q) } }
        .toolbar { sitePickerToolbar }
        .sheet(isPresented: $showingSitePicker) {
            SitePickerSheet { site in
                Task { await viewModel.selectSite(site) }
                showingSitePicker = false
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Sub-views

    private var emptyPrompt: some View {
        ContentUnavailableView(
            "Select a Site or Search",
            systemImage: "person.2",
            description: Text("Choose a site from the filter, or search by IP, MAC, or hostname.")
        )
    }

    @ViewBuilder
    private var clientList: some View {
        List {
            wirelessSection
            wiredSection
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var wirelessSection: some View {
        if !viewModel.wirelessClients.isEmpty {
            Section("Wireless (\(viewModel.wirelessClients.count))") {
                ForEach(viewModel.wirelessClients) { client in
                    NavigationLink(value: client) {
                        ClientRowView(client: client)
                    }
                    .onAppear {
                        if client.id == viewModel.wirelessClients.last?.id {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wiredSection: some View {
        if !viewModel.wiredClients.isEmpty {
            Section("Wired (\(viewModel.wiredClients.count))") {
                ForEach(viewModel.wiredClients) { client in
                    NavigationLink(value: client) {
                        ClientRowView(client: client)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var sitePickerToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSitePicker = true
            } label: {
                Label(viewModel.selectedSite ?? "All Sites", systemImage: "building.2")
                    .labelStyle(.titleAndIcon)
            }
        }
    }
}

// MARK: - ClientRowView

struct ClientRowView: View {
    let client: CentralClient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: client.connectionType == .wireless ? "wifi" : "cable.connector")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name ?? client.macAddress)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let ip = client.ipAddress {
                        Text(ip).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(client.macAddress).font(.caption).foregroundStyle(.secondary)
                }

                if client.connectionType == .wireless, let ssid = client.ssid {
                    Text(ssid).font(.caption2).foregroundStyle(.secondary)
                } else if client.connectionType == .wired, let port = client.port {
                    Text("Port \(port)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let name = client.name ?? client.macAddress
        let conn = client.connectionType == .wireless ? "wireless" : "wired"
        let ip   = client.ipAddress ?? "unknown IP"
        return "\(name), \(conn), \(ip)"
    }
}

// MARK: - SitePickerSheet (placeholder — uses fetched site list in Phase 4)

private struct SitePickerSheet: View {
    let onSelect: (String?) -> Void

    // In production this list comes from the Dashboard's site data.
    // Passed as a static list here; integrate with shared site state in polish phase.
    private let sites = ["HQ Campus", "Branch Office", "Warehouse", "Data Center"]

    var body: some View {
        NavigationStack {
            List {
                Button("All Sites") { onSelect(nil) }
                    .foregroundStyle(.primary)
                ForEach(sites, id: \.self) { site in
                    Button(site) { onSelect(site) }
                        .foregroundStyle(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Site")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
```

- [ ] **Step 6: Wire into RootView**

In `ArubaCentral/App/RootView.swift`, replace the Clients tab:

```swift
// Before:
NavigationStack {
    ClientsPlaceholder()
}
.tabItem { Label("Clients", systemImage: "person.2") }

// After:
NavigationStack {
    ClientsView(client: apiClient)
        .navigationDestination(for: CentralClient.self) { client in
            ClientDetailView(client: client, client: apiClient)
        }
}
.tabItem { Label("Clients", systemImage: "person.2") }
```

- [ ] **Step 7: Add files, build, commit**

```bash
git add \
  ArubaCentral/Features/Clients/ClientsViewModel.swift \
  ArubaCentral/Features/Clients/ClientsView.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Clients/ClientsViewModelTests.swift
git commit -m "feat: add Clients tab — site picker, wireless/wired sections, global search, pagination"
```

---

### Task 16: ClientDetailView + Disconnect action

**Files:**
- Create: `ArubaCentral/Features/Clients/ClientDetailView.swift`
- Test: `ArubaCentralTests/Features/Clients/ClientDetailViewTests.swift`

**Interfaces:**
- Consumes: `CentralClient`, `CentralAPIClientProtocol.fetchClientDetail()`, `disconnectAllClientsFromAP()`
- Produces: `ClientDetailView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Clients/ClientDetailViewTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class ClientDetailViewTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: ClientDetailViewModel!

    let client = CentralClient(
        macAddress: "aa:11:bb:22:cc:33", name: "MacBook-Josh",
        ipAddress: "10.0.1.100", connectionType: .wireless,
        associatedDeviceSerial: "AP-SN001", site: "HQ",
        ssid: "Corp-WiFi", vlan: nil, port: nil,
        signalStrength: -65, txDataRate: 120.0, rxDataRate: 45.0,
        connectedAt: Date(timeIntervalSince1970: 1_751_000_000)
    )

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = ClientDetailViewModel(client: client, apiClient: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadFetchesClientDetail() async {
        mockClient.clientDetailResult = .success(client)
        await sut.load()
        guard case .loaded(let detail) = sut.detailState else { return XCTFail() }
        XCTAssertEqual(detail.macAddress, "aa:11:bb:22:cc:33")
    }

    func testLoadSetsErrorOnFailure() async {
        mockClient.clientDetailResult = .failure(.networkError)
        await sut.load()
        guard case .error = sut.detailState else { return XCTFail("Expected error") }
    }

    func testDisconnectCallsAPIWithAPSerial() async {
        await sut.disconnect()
        XCTAssertEqual(mockClient.disconnectCallCount, 1)
    }

    func testDisconnectSetsErrorOnFailure() async {
        mockClient.disconnectError = .serverError(500)
        await sut.disconnect()
        XCTAssertNotNil(sut.actionError)
    }

    func testDisconnectDoesNothingWhenNoAPSerial() async {
        let clientWithNoAP = CentralClient(
            macAddress: "aa:11", name: nil, ipAddress: nil,
            connectionType: .wired, associatedDeviceSerial: nil,
            site: nil, ssid: nil, vlan: nil, port: nil,
            signalStrength: nil, txDataRate: nil, rxDataRate: nil, connectedAt: nil
        )
        sut = ClientDetailViewModel(client: clientWithNoAP, apiClient: mockClient)
        await sut.disconnect()
        XCTAssertEqual(mockClient.disconnectCallCount, 0)
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/ClientDetailViewTests \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `ClientDetailView.swift`**

Create `ArubaCentral/Features/Clients/ClientDetailView.swift`:

```swift
import SwiftUI

@MainActor
final class ClientDetailViewModel: ObservableObject {
    @Published private(set) var detailState: LoadState<CentralClient> = .idle
    @Published var actionError: APIError? = nil
    @Published var showingDisconnectConfirm = false

    let client: CentralClient
    private let apiClient: CentralAPIClientProtocol

    init(client: CentralClient, apiClient: CentralAPIClientProtocol) {
        self.client    = client
        self.apiClient = apiClient
    }

    func load() async {
        detailState = .loading
        do {
            let detail = try await apiClient.fetchClientDetail(macAddress: client.macAddress)
            detailState = .loaded(detail)
        } catch let error as APIError {
            detailState = .error(error)
        } catch {
            detailState = .error(.networkError)
        }
    }

    func disconnect() async {
        // NOTE: Per-client disconnect endpoint TBC (open item #2).
        // Fallback: disconnect all clients from the associated AP.
        guard let apSerial = client.associatedDeviceSerial else { return }
        do {
            try await apiClient.disconnectAllClientsFromAP(serial: apSerial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }
}

struct ClientDetailView: View {
    @StateObject private var viewModel: ClientDetailViewModel

    init(client: CentralClient, client apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(client: client,
                                                                      apiClient: apiClient))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.detailState,
            content: { detail in detailContent(detail) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle(viewModel.client.name ?? viewModel.client.macAddress)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { disconnectButton }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError?.userMessage ?? "") }
        .confirmationDialog("Disconnect client?",
                            isPresented: $viewModel.showingDisconnectConfirm,
                            titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task { await viewModel.disconnect() }
            }
        } message: {
            Text("This will disconnect the client from the network. (Note: currently disconnects all clients on the AP — open item #2)")
        }
    }

    @ViewBuilder
    private func detailContent(_ client: CentralClient) -> some View {
        List {
            Section("Identity") {
                if let name = client.name { LabeledContent("Name",    value: name) }
                LabeledContent("MAC",     value: client.macAddress)
                if let ip = client.ipAddress { LabeledContent("IP",  value: ip) }
            }
            Section("Connection") {
                LabeledContent("Type",  value: client.connectionType == .wireless ? "Wireless" : "Wired")
                if let ssid = client.ssid    { LabeledContent("SSID",   value: ssid) }
                if let port = client.port    { LabeledContent("Port",   value: port) }
                if let vlan = client.vlan    { LabeledContent("VLAN",   value: "\(vlan)") }
                if let dev  = client.associatedDeviceSerial {
                    LabeledContent("Device", value: dev)
                }
                if let site = client.site    { LabeledContent("Site",   value: site) }
            }
            if client.connectionType == .wireless {
                Section("Signal") {
                    if let rssi = client.signalStrength {
                        LabeledContent("Signal",   value: "\(rssi) dBm")
                    }
                    if let tx = client.txDataRate {
                        LabeledContent("TX Rate",  value: String(format: "%.0f Mbps", tx))
                    }
                    if let rx = client.rxDataRate {
                        LabeledContent("RX Rate",  value: String(format: "%.0f Mbps", rx))
                    }
                }
            }
            if let connectedAt = client.connectedAt {
                Section("Session") {
                    LabeledContent("Connected", value: connectedAt.formatted(.relative(presentation: .named)))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var disconnectButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(role: .destructive) {
                viewModel.showingDisconnectConfirm = true
            } label: {
                Label("Disconnect", systemImage: "wifi.slash")
            }
        }
    }
}
```

- [ ] **Step 4: Run all Phase 6 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/ClientsViewModelTests \
  -only-testing:ArubaCentralTests/ClientDetailViewTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: Both suites pass.

- [ ] **Step 5: Build and verify on simulator**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Verify: Clients tab opens empty with prompt, site picker works, list shows wireless/wired sections, tapping a client navigates to detail.

- [ ] **Step 6: Commit**

```bash
git add \
  ArubaCentral/Features/Clients/ClientDetailView.swift \
  ArubaCentralTests/Features/Clients/ClientDetailViewTests.swift
git commit -m "feat: add Client Detail — signal/session info with Disconnect action placeholder"
```

---

## Phase 6 Complete

- **`ClientsViewModel`** — site selection, global search, wireless/wired computed groupings, pagination; 11 unit tests
- **`ClientsView`** — empty-prompt default state, segmented wireless/wired sections, site picker sheet, searchable nav bar, infinite scroll
- **`ClientRowView`** — shared row component reused wherever clients appear
- **`ClientDetailViewModel`** — fetches full detail, disconnect falls back to `disconnectAllClientsFromAP` pending open item #2; 5 unit tests
- **`ClientDetailView`** — full detail screen with identity, connection, signal, and session sections; confirmation dialog for disconnect

**Next:** Phase 7 — Alerts tab (`AlertsViewModel`, `AlertsView`, `AlertDetailView`, badge count)
