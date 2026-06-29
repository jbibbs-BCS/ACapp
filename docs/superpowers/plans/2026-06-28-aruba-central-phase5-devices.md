# Aruba Central iOS App — Phase 5: Devices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Devices tab (filterable AP + switch list), AP Detail (Overview/Radios/Clients tabs), Switch Detail (Overview/Ports/VLANs tabs), and the visual port diagram.

**Architecture:** Four ViewModels each consume `CentralAPIClientProtocol` and expose `LoadState<T>`. `PortDiagramView` is a pure SwiftUI layout component with no ViewModel. All ViewModels tested with `MockCentralAPIClient`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest

## Global Constraints

- Deployment target: iOS 16.0+
- Page size: 100 for all lists
- AP Detail and Switch Detail detail tabs load data in parallel with `async let`
- Port diagram supports 8, 24, and 48-port switches; scrolls horizontally on iPhone; fixed canvas on iPad
- Bounce Port action is a placeholder (confirmed endpoint TBC — open item #1 from spec)
- Prerequisite: Phases 1–4 complete (`DeviceRowView` from Phase 4 is reused here)

---

### Task 11: DevicesViewModel + DevicesView

**Files:**
- Create: `ArubaCentral/Features/Devices/DevicesViewModel.swift`
- Create: `ArubaCentral/Features/Devices/DevicesView.swift`
- Modify: `ArubaCentral/App/RootView.swift` — replace `DevicesPlaceholder` with `DevicesView`
- Test: `ArubaCentralTests/Features/Devices/DevicesViewModelTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchAPs()`, `fetchSwitches()`, `AccessPoint`, `CentralSwitch`, `PaginatedResponse`, `LoadState`, `DeviceRowView`
- Produces: `DevicesViewModel`, `DevicesView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Devices/DevicesViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class DevicesViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: DevicesViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = DevicesViewModel(client: mockClient)
    }

    override func tearDown() {
        sut = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        if case .idle = sut.devicesState { } else { XCTFail("Expected idle") }
    }

    func testDefaultFilterTypeIsAll() {
        XCTAssertEqual(sut.filterType, .all)
    }

    // MARK: - load

    func testLoadFetchesBothAPsAndSwitches() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertEqual(items.count, 2)
    }

    func testLoadSetsErrorWhenAPsFail() async {
        mockClient.apsResult      = .failure(.serverError(500))
        mockClient.switchesResult = .success(.empty())
        await sut.load()
        guard case .error = sut.devicesState else { return XCTFail("Expected error") }
    }

    // MARK: - Filter type

    func testFilterTypeAPShowsOnlyAPs() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        sut.filterType = .ap
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertTrue(items.allSatisfy { $0.deviceType == .ap })
    }

    func testFilterTypeSwitchShowsOnlySwitches() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.load()
        sut.filterType = .switch_
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertTrue(items.allSatisfy { $0.deviceType == .switch_ })
    }

    // MARK: - Site filter

    func testSiteFilterPassedToAPICall() async {
        mockClient.apsResult      = .success(.empty())
        mockClient.switchesResult = .success(.empty())
        sut.selectedSite = "HQ Campus"
        await sut.load()
        XCTAssertEqual(mockClient.lastSiteFilter, "HQ Campus")
    }

    // MARK: - Search

    func testSearchQueryPassedToAPICall() async {
        mockClient.apsResult      = .success(.empty())
        mockClient.switchesResult = .success(.empty())
        await sut.search(query: "lobby")
        XCTAssertEqual(mockClient.lastSearchQuery, "lobby")
    }

    func testEmptySearchResetsToFullLoad() async {
        mockClient.apsResult      = .success(.of([makeAP("AP1")]))
        mockClient.switchesResult = .success(.of([makeSW("SW1")]))
        await sut.search(query: "")
        guard case .loaded(let items) = sut.devicesState else { return XCTFail() }
        XCTAssertEqual(items.count, 2)
    }

    // MARK: - Helpers

    private func makeAP(_ serial: String) -> AccessPoint {
        AccessPoint(serial: serial, name: serial, model: "AP-635", status: .up,
                    ipAddress: nil, macAddress: nil, firmware: nil, uptime: nil,
                    site: nil, clientCount: nil)
    }

    private func makeSW(_ serial: String) -> CentralSwitch {
        CentralSwitch(serial: serial, name: serial, model: "6300M", status: .up,
                      ipAddress: nil, macAddress: nil, firmware: nil, uptime: nil,
                      site: nil, stackId: nil)
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
  -only-testing:ArubaCentralTests/DevicesViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `DevicesViewModel` not found.

- [ ] **Step 3: Create `DevicesViewModel.swift`**

Create `ArubaCentral/Features/Devices/DevicesViewModel.swift`:

```swift
import Foundation

enum DeviceFilterType: String, CaseIterable, Identifiable {
    case all     = "All"
    case ap      = "APs"
    case switch_ = "Switches"
    var id: String { rawValue }
}

struct DeviceItem: Identifiable {
    enum DeviceType { case ap, switch_ }
    let id: String
    let name: String
    let model: String
    let status: DeviceStatus
    let uptime: Int?
    let site: String?
    let deviceType: DeviceType
    let serial: String
    // Retain originals for navigation
    let ap: AccessPoint?
    let sw: CentralSwitch?
}

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published private(set) var devicesState: LoadState<[DeviceItem]> = .idle
    @Published var filterType: DeviceFilterType = .all {
        didSet { applyFilter() }
    }
    @Published var selectedSite: String? = nil

    private let client: CentralAPIClientProtocol
    private var allItems: [DeviceItem] = []
    private let pageSize = 100

    init(client: CentralAPIClientProtocol) {
        self.client = client
    }

    func load() async {
        devicesState = .loading
        do {
            async let apsPage     = client.fetchAPs(site: selectedSite, search: nil,
                                                     limit: pageSize, offset: 0)
            async let switchesPage = client.fetchSwitches(site: selectedSite, search: nil,
                                                           limit: pageSize, offset: 0)
            let (aps, switches) = try await (apsPage, switchesPage)
            allItems = aps.items.map { DeviceItem(from: $0) }
                      + switches.items.map { DeviceItem(from: $0) }
            applyFilter()
        } catch let error as APIError {
            devicesState = .error(error)
        } catch {
            devicesState = .error(.networkError)
        }
    }

    func search(query: String) async {
        guard !query.isEmpty else { await load(); return }
        devicesState = .loading
        do {
            async let apsPage     = client.fetchAPs(site: selectedSite, search: query,
                                                     limit: pageSize, offset: 0)
            async let switchesPage = client.fetchSwitches(site: selectedSite, search: query,
                                                           limit: pageSize, offset: 0)
            let (aps, switches) = try await (apsPage, switchesPage)
            allItems = aps.items.map { DeviceItem(from: $0) }
                      + switches.items.map { DeviceItem(from: $0) }
            applyFilter()
        } catch let error as APIError {
            devicesState = .error(error)
        } catch {
            devicesState = .error(.networkError)
        }
    }

    func refresh() async { await load() }

    private func applyFilter() {
        let filtered: [DeviceItem]
        switch filterType {
        case .all:     filtered = allItems
        case .ap:      filtered = allItems.filter { $0.deviceType == .ap }
        case .switch_: filtered = allItems.filter { $0.deviceType == .switch_ }
        }
        devicesState = .loaded(filtered)
    }
}

private extension DeviceItem {
    init(from ap: AccessPoint) {
        id = ap.serial; name = ap.name; model = ap.model; status = ap.status
        uptime = ap.uptime; site = ap.site; deviceType = .ap; serial = ap.serial
        self.ap = ap; sw = nil
    }
    init(from sw: CentralSwitch) {
        id = sw.serial; name = sw.name; model = sw.model; status = sw.status
        uptime = sw.uptime; site = sw.site; deviceType = .switch_; serial = sw.serial
        ap = nil; self.sw = sw
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/DevicesViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'DevicesViewModelTests' passed`

- [ ] **Step 5: Create `DevicesView.swift`**

Create `ArubaCentral/Features/Devices/DevicesView.swift`:

```swift
import SwiftUI

struct DevicesView: View {
    @StateObject private var viewModel: DevicesViewModel
    @State private var searchText = ""

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DevicesViewModel(client: client))
    }

    var body: some View {
        LoadStateView(
            state: viewModel.devicesState,
            content: { items in deviceList(items) },
            retry: { Task { await viewModel.load() } }
        )
        .navigationTitle("Devices")
        .searchable(text: $searchText, prompt: "Name, IP, or MAC")
        .onChange(of: searchText) { _, query in
            Task { await viewModel.search(query: query) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Type", selection: $viewModel.filterType) {
                    ForEach(DeviceFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private func deviceList(_ items: [DeviceItem]) -> some View {
        if items.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(items) { item in
                Group {
                    if let ap = item.ap {
                        NavigationLink(value: ap) {
                            DeviceRowView(name: item.name, model: item.model,
                                         status: item.status, uptime: item.uptime)
                        }
                    } else if let sw = item.sw {
                        NavigationLink(value: sw) {
                            DeviceRowView(name: item.name, model: item.model,
                                         status: item.status, uptime: item.uptime)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
```

- [ ] **Step 6: Wire into RootView — replace DevicesPlaceholder**

In `ArubaCentral/App/RootView.swift`, replace the Devices tab:

```swift
// Before:
NavigationStack {
    DevicesPlaceholder()
}
.tabItem { Label("Devices", systemImage: "antenna.radiowaves.left.and.right") }

// After:
NavigationStack {
    DevicesView(client: apiClient)
        .navigationDestination(for: AccessPoint.self) { ap in
            APDetailView(ap: ap, client: apiClient)   // built in Task 12
        }
        .navigationDestination(for: CentralSwitch.self) { sw in
            SwitchDetailView(sw: sw, client: apiClient) // built in Task 13
        }
}
.tabItem { Label("Devices", systemImage: "antenna.radiowaves.left.and.right") }
```

- [ ] **Step 7: Add files to Xcode targets, build, commit**

Add `DevicesViewModel.swift` and `DevicesView.swift` to `ArubaCentral`. Add test file to `ArubaCentralTests`.

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

```bash
git add \
  ArubaCentral/Features/Devices/DevicesViewModel.swift \
  ArubaCentral/Features/Devices/DevicesView.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Devices/DevicesViewModelTests.swift
git commit -m "feat: add Devices tab — filterable AP+switch list with search"
```

---

### Task 12: APDetailViewModel + APDetailView

**Files:**
- Create: `ArubaCentral/Features/Devices/APDetail/APDetailViewModel.swift`
- Create: `ArubaCentral/Features/Devices/APDetail/APDetailView.swift`
- Test: `ArubaCentralTests/Features/Devices/APDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `fetchAPDetail()`, `fetchAPRadios()`, `fetchAPClients()`, `rebootAP()`, `blinkAPLED()`
- Produces: `APDetailViewModel`, `APDetailView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Devices/APDetailViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class APDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: APDetailViewModel!
    let ap = AccessPoint(serial: "AP1", name: "AP-Lobby", model: "AP-635",
                         status: .up, ipAddress: "10.0.1.5", macAddress: "aa:bb:cc:dd:ee:ff",
                         firmware: "10.4.0", uptime: 86400, site: "HQ", clientCount: 8)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = APDetailViewModel(ap: ap, client: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadSetsDetailRadiosAndClients() async {
        mockClient.apDetailResult  = .success(ap)
        mockClient.radiosResult    = .success([makeRadio(index: 0, band: "5GHz")])
        mockClient.apClientsResult = .success(.of([makeClient()]))

        await sut.load()

        guard case .loaded(let detail)   = sut.detailState  else { return XCTFail("detail") }
        guard case .loaded(let radios)   = sut.radiosState  else { return XCTFail("radios") }
        guard case .loaded(let clients)  = sut.clientsState else { return XCTFail("clients") }

        XCTAssertEqual(detail.serial, "AP1")
        XCTAssertEqual(radios.count, 1)
        XCTAssertEqual(clients.count, 1)
    }

    func testLoadSetsErrorWhenDetailFails() async {
        mockClient.apDetailResult  = .failure(.forbidden)
        mockClient.radiosResult    = .success([])
        mockClient.apClientsResult = .success(.empty())

        await sut.load()

        guard case .error(let error) = sut.detailState else { return XCTFail() }
        XCTAssertEqual(error, .forbidden)
    }

    func testRebootAPCallsClient() async throws {
        await sut.rebootAP()
        XCTAssertEqual(mockClient.rebootCallCount, 1)
    }

    func testRebootAPSetsErrorOnFailure() async {
        mockClient.rebootError = .serverError(500)
        await sut.rebootAP()
        XCTAssertNotNil(sut.actionError)
    }

    func testBlinkLEDCallsClient() async {
        await sut.blinkLED()
        XCTAssertEqual(mockClient.blinkCallCount, 1)
    }

    func testBlinkLEDSetsErrorOnFailure() async {
        mockClient.blinkError = .forbidden
        await sut.blinkLED()
        XCTAssertNotNil(sut.actionError)
    }

    private func makeRadio(index: Int, band: String) -> Radio {
        Radio(index: index, band: band, channel: 36, ssid: "Corp", clientCount: 4, throughput: 100)
    }

    private func makeClient() -> CentralClient {
        CentralClient(macAddress: "aa:11:bb:22:cc:33", name: "MacBook",
                      ipAddress: "10.0.1.100", connectionType: .wireless,
                      associatedDeviceSerial: "AP1", site: "HQ",
                      ssid: "Corp", vlan: nil, port: nil,
                      signalStrength: -65, txDataRate: nil, rxDataRate: nil, connectedAt: nil)
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/APDetailViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `APDetailViewModel.swift`**

Create `ArubaCentral/Features/Devices/APDetail/APDetailViewModel.swift`:

```swift
import Foundation

@MainActor
final class APDetailViewModel: ObservableObject {
    @Published private(set) var detailState:  LoadState<AccessPoint>              = .idle
    @Published private(set) var radiosState:  LoadState<[Radio]>                  = .idle
    @Published private(set) var clientsState: LoadState<[CentralClient]>          = .idle
    @Published var actionError: APIError?     = nil
    @Published var showingRebootConfirm       = false
    @Published var showingBlinkConfirm        = false

    let ap: AccessPoint
    private let client: CentralAPIClientProtocol

    init(ap: AccessPoint, client: CentralAPIClientProtocol) {
        self.ap     = ap
        self.client = client
    }

    func load() async {
        detailState  = .loading
        radiosState  = .loading
        clientsState = .loading
        do {
            async let detail  = client.fetchAPDetail(serial: ap.serial)
            async let radios  = client.fetchAPRadios(serial: ap.serial)
            async let clients = client.fetchAPClients(serial: ap.serial, limit: 100, offset: 0)
            let (d, r, c) = try await (detail, radios, clients)
            detailState  = .loaded(d)
            radiosState  = .loaded(r)
            clientsState = .loaded(c.items)
        } catch let error as APIError {
            detailState = .error(error)
        } catch {
            detailState = .error(.networkError)
        }
    }

    func rebootAP() async {
        do {
            try await client.rebootAP(serial: ap.serial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }

    func blinkLED() async {
        do {
            try await client.blinkAPLED(serial: ap.serial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
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
  -only-testing:ArubaCentralTests/APDetailViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'APDetailViewModelTests' passed`

- [ ] **Step 5: Create `APDetailView.swift`**

Create `ArubaCentral/Features/Devices/APDetail/APDetailView.swift`:

```swift
import SwiftUI

struct APDetailView: View {
    @StateObject private var viewModel: APDetailViewModel
    @State private var selectedTab = 0

    init(ap: AccessPoint, client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: APDetailViewModel(ap: ap, client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Radios").tag(1)
                Text("Clients").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
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
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
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

    // MARK: - Tabs

    @ViewBuilder
    private var overviewTab: some View {
        LoadStateView(state: viewModel.detailState,
                      content: { ap in APOverviewContent(ap: ap) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder
    private var radiosTab: some View {
        LoadStateView(state: viewModel.radiosState,
                      content: { radios in
                          List(radios) { radio in
                              RadioRowView(radio: radio)
                          }.listStyle(.insetGrouped)
                      },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder
    private var clientsTab: some View {
        LoadStateView(state: viewModel.clientsState,
                      content: { clients in
                          List(clients) { client in
                              ClientRowView(client: client)
                          }.listStyle(.insetGrouped)
                      },
                      retry: { Task { await viewModel.load() } })
    }

    @ToolbarContentBuilder
    private var actionMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { viewModel.showingRebootConfirm = true } label: {
                    Label("Reboot AP", systemImage: "arrow.clockwise")
                }
                Button { viewModel.showingBlinkConfirm = true } label: {
                    Label("Blink LED", systemImage: "light.beacon.max")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Sub-views

private struct APOverviewContent: View {
    let ap: AccessPoint
    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Model",    value: ap.model)
                LabeledContent("Serial",   value: ap.serial)
                if let fw = ap.firmware { LabeledContent("Firmware", value: fw) }
                if let ip = ap.ipAddress { LabeledContent("IP",      value: ip) }
                if let mac = ap.macAddress { LabeledContent("MAC",   value: mac) }
            }
            Section("Status") {
                LabeledContent("Status",  value: ap.status == .up ? "Online" : "Offline")
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

    private func uptimeString(_ seconds: Int) -> String {
        let d = seconds / 86400; let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct RadioRowView: View {
    let radio: Radio
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(radio.band).font(.headline)
                Spacer()
                Text("\(radio.clientCount) clients").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let ch = radio.channel { Label("Ch \(ch)", systemImage: "dot.radiowaves.left.and.right") }
                if let ssid = radio.ssid  { Label(ssid,        systemImage: "wifi") }
                if let tp = radio.throughput { Label(String(format: "%.0f Mbps", tp), systemImage: "arrow.up.arrow.down") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 6: Add files, build, commit**

```bash
git add \
  ArubaCentral/Features/Devices/APDetail/APDetailViewModel.swift \
  ArubaCentral/Features/Devices/APDetail/APDetailView.swift \
  ArubaCentralTests/Features/Devices/APDetailViewModelTests.swift
git commit -m "feat: add AP Detail — Overview/Radios/Clients tabs with Reboot and Blink actions"
```

---

### Task 13: SwitchDetailViewModel + SwitchDetailView (Overview + VLANs)

**Files:**
- Create: `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailViewModel.swift`
- Create: `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift`
- Test: `ArubaCentralTests/Features/Devices/SwitchDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `fetchSwitchDetail()`, `fetchSwitchInterfaces()`, `fetchSwitchVLANs()`
- Produces: `SwitchDetailViewModel`, `SwitchDetailView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Devices/SwitchDetailViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class SwitchDetailViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: SwitchDetailViewModel!
    let sw = CentralSwitch(serial: "SW1", name: "Core-1", model: "6300M",
                           status: .up, ipAddress: "10.0.0.1", macAddress: nil,
                           firmware: "10.13", uptime: 604800, site: "HQ", stackId: nil)

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = SwitchDetailViewModel(sw: sw, client: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testLoadFetchesDetailInterfacesAndVLANs() async {
        mockClient.switchDetailResult = .success(sw)
        mockClient.interfacesResult   = .success([makeInterface("1/1/1")])
        mockClient.vlansResult        = .success([makeVLAN(10)])

        await sut.load()

        guard case .loaded = sut.detailState    else { return XCTFail("detail") }
        guard case .loaded(let ifaces) = sut.portsState else { return XCTFail("ports") }
        guard case .loaded(let vlans)  = sut.vlansState else { return XCTFail("vlans") }

        XCTAssertEqual(ifaces.count, 1)
        XCTAssertEqual(vlans.count, 1)
    }

    func testLoadSetsErrorOnDetailFailure() async {
        mockClient.switchDetailResult = .failure(.serverError(503))
        mockClient.interfacesResult   = .success([])
        mockClient.vlansResult        = .success([])

        await sut.load()
        guard case .error = sut.detailState else { return XCTFail("Expected error") }
    }

    private func makeInterface(_ portId: String) -> SwitchInterface {
        SwitchInterface(portId: portId, status: .up, speed: "1G",
                        vlan: 10, connectedDevice: nil, txBytes: nil, rxBytes: nil)
    }

    private func makeVLAN(_ id: Int) -> VLAN {
        VLAN(vlanId: id, name: "Corp", taggedPorts: [], untaggedPorts: ["1/1/1"])
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SwitchDetailViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `SwitchDetailViewModel.swift`**

Create `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailViewModel.swift`:

```swift
import Foundation

@MainActor
final class SwitchDetailViewModel: ObservableObject {
    @Published private(set) var detailState: LoadState<CentralSwitch>     = .idle
    @Published private(set) var portsState:  LoadState<[SwitchInterface]> = .idle
    @Published private(set) var vlansState:  LoadState<[VLAN]>            = .idle
    @Published var actionError: APIError? = nil

    let sw: CentralSwitch
    private let client: CentralAPIClientProtocol

    init(sw: CentralSwitch, client: CentralAPIClientProtocol) {
        self.sw     = sw
        self.client = client
    }

    func load() async {
        detailState = .loading
        portsState  = .loading
        vlansState  = .loading
        do {
            async let detail     = client.fetchSwitchDetail(serial: sw.serial)
            async let interfaces = client.fetchSwitchInterfaces(serial: sw.serial)
            async let vlans      = client.fetchSwitchVLANs(serial: sw.serial)
            let (d, i, v) = try await (detail, interfaces, vlans)
            detailState = .loaded(d)
            portsState  = .loaded(i)
            vlansState  = .loaded(v)
        } catch let error as APIError {
            detailState = .error(error)
        } catch {
            detailState = .error(.networkError)
        }
    }

    func refresh() async { await load() }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SwitchDetailViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

- [ ] **Step 5: Create `SwitchDetailView.swift`**

Create `ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift`:

```swift
import SwiftUI

struct SwitchDetailView: View {
    @StateObject private var viewModel: SwitchDetailViewModel
    @State private var selectedTab = 0

    init(sw: CentralSwitch, client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SwitchDetailViewModel(sw: sw, client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Ports").tag(1)
                Text("VLANs").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case 0: overviewTab
                case 1: portsTab
                default: vlansTab
                }
            }
        }
        .navigationTitle(viewModel.sw.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError?.userMessage ?? "") }
    }

    @ViewBuilder private var overviewTab: some View {
        LoadStateView(state: viewModel.detailState,
                      content: { sw in SwitchOverviewContent(sw: sw) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder private var portsTab: some View {
        LoadStateView(state: viewModel.portsState,
                      content: { ports in PortDiagramView(ports: ports, onBounce: { _ in }) },
                      retry: { Task { await viewModel.load() } })
    }

    @ViewBuilder private var vlansTab: some View {
        LoadStateView(state: viewModel.vlansState,
                      content: { vlans in
                          List(vlans) { vlan in VLANRowView(vlan: vlan) }
                              .listStyle(.insetGrouped)
                      },
                      retry: { Task { await viewModel.load() } })
    }
}

private struct SwitchOverviewContent: View {
    let sw: CentralSwitch
    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Model",   value: sw.model)
                LabeledContent("Serial",  value: sw.serial)
                if let fw  = sw.firmware  { LabeledContent("Firmware", value: fw) }
                if let ip  = sw.ipAddress { LabeledContent("IP",       value: ip) }
                if let mac = sw.macAddress { LabeledContent("MAC",     value: mac) }
            }
            Section("Status") {
                LabeledContent("Status", value: sw.status == .up ? "Online" : "Offline")
                if let uptime = sw.uptime { LabeledContent("Uptime", value: uptimeString(uptime)) }
            }
        }.listStyle(.insetGrouped)
    }

    private func uptimeString(_ s: Int) -> String {
        let d = s / 86400; let h = (s % 86400) / 3600; let m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }; if h > 0 { return "\(h)h \(m)m" }; return "\(m)m"
    }
}

struct VLANRowView: View {
    let vlan: VLAN
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("VLAN \(vlan.vlanId)").font(.headline)
                if let name = vlan.name { Text(name).foregroundStyle(.secondary) }
            }
            if !vlan.taggedPorts.isEmpty {
                Text("Tagged: \(vlan.taggedPorts.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
            }
            if !vlan.untaggedPorts.isEmpty {
                Text("Untagged: \(vlan.untaggedPorts.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 2)
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add \
  ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailViewModel.swift \
  ArubaCentral/Features/Devices/SwitchDetail/SwitchDetailView.swift \
  ArubaCentralTests/Features/Devices/SwitchDetailViewModelTests.swift
git commit -m "feat: add Switch Detail — Overview/Ports/VLANs tabs"
```

---

### Task 14: PortDiagramView

**Files:**
- Create: `ArubaCentral/Shared/Components/PortDiagramView.swift`
- Test: `ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift`

**Interfaces:**
- Consumes: `[SwitchInterface]`, `PortStatus`
- Produces: `PortDiagramView(ports:onBounce:)` — used by `SwitchDetailView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class PortDiagramViewTests: XCTestCase {

    func testPortColorUp() {
        XCTAssertEqual(PortStatus.up.color,       "green")
    }

    func testPortColorDown() {
        XCTAssertEqual(PortStatus.down.color,     "gray")
    }

    func testPortColorDisabled() {
        XCTAssertEqual(PortStatus.disabled.color, "orange")
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

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/PortDiagramViewTests \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `PortDiagramView.swift`**

Create `ArubaCentral/Shared/Components/PortDiagramView.swift`:

```swift
import SwiftUI

enum PortDiagramLayout {
    static func columns(for count: Int) -> Int {
        count <= 8 ? 4 : 12
    }
}

extension PortStatus {
    var color: String {
        switch self {
        case .up:       return "green"
        case .down:     return "gray"
        case .disabled: return "orange"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .up:       return .green
        case .down:     return Color(.systemGray4)
        case .disabled: return .orange
        }
    }
}

struct PortDiagramView: View {
    let ports: [SwitchInterface]
    let onBounce: (SwitchInterface) -> Void

    @State private var selectedPort: SwitchInterface? = nil

    private var columns: Int { PortDiagramLayout.columns(for: ports.count) }

    var body: some View {
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
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(port: port, onBounce: {
                onBounce(port)
                selectedPort = nil
            })
            .presentationDetents([.medium])
        }
    }
}

private struct PortCell: View {
    let port: SwitchInterface

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(port.status.swiftUIColor.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(port.status.swiftUIColor, lineWidth: 2)
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

private struct PortDetailSheet: View {
    let port: SwitchInterface
    let onBounce: () -> Void

    @State private var showingBounceConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Port Info") {
                    LabeledContent("Port ID", value: port.portId)
                    LabeledContent("Status",  value: port.status.rawValue)
                    if let speed = port.speed { LabeledContent("Speed", value: speed) }
                    if let vlan  = port.vlan  { LabeledContent("VLAN",  value: "\(vlan)") }
                    if let dev   = port.connectedDevice { LabeledContent("Device", value: dev) }
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
                    // NOTE: Bounce port endpoint TBC (Open Item #1) — button wired but action is placeholder
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
                            status: i % 5 == 0 ? .down : .up,
                            speed: "1G", vlan: 10,
                            connectedDevice: nil,
                            txBytes: 1_000_000, rxBytes: 500_000)
        },
        onBounce: { _ in }
    )
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/PortDiagramViewTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'PortDiagramViewTests' passed`

- [ ] **Step 5: Run all Phase 5 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/DevicesViewModelTests \
  -only-testing:ArubaCentralTests/APDetailViewModelTests \
  -only-testing:ArubaCentralTests/SwitchDetailViewModelTests \
  -only-testing:ArubaCentralTests/PortDiagramViewTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All 4 suites pass.

- [ ] **Step 6: Commit**

```bash
git add \
  ArubaCentral/Shared/Components/PortDiagramView.swift \
  ArubaCentralTests/Shared/Components/PortDiagramViewTests.swift
git commit -m "feat: add PortDiagramView — visual port grid with status colors and bounce action placeholder"
```

---

## Phase 5 Complete

The Devices tab and all device detail screens are functional:

- **`DevicesViewModel`** — parallel AP + switch fetch, `DeviceFilterType` (All/APs/Switches) applied client-side, API-backed search; 9 unit tests
- **`DevicesView`** — searchable list with segmented filter toolbar, `NavigationLink` to AP or Switch Detail
- **`APDetailViewModel`** — parallel fetch of detail + radios + clients, Reboot and Blink actions with error surfacing; 7 unit tests
- **`APDetailView`** — three-tab picker (Overview/Radios/Clients), action menu with confirmation dialogs
- **`SwitchDetailViewModel`** — parallel fetch of detail + interfaces + VLANs; 3 unit tests
- **`SwitchDetailView`** — three-tab picker (Overview/Ports/VLANs)
- **`PortDiagramView`** — lazy grid sized for 8/24/48-port switches, tap-to-detail sheet, Bounce Port placeholder wired to open item #1

**Next:** Phase 6 — Clients tab (`ClientsViewModel`, `ClientsView`, `ClientDetailView`)
