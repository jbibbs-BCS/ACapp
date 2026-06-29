# Aruba Central iOS App — Phase 7: Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Alerts tab (paginated alert list with severity icons and unread badge), Alert Detail screen, and the Acknowledge action.

**Architecture:** `AlertsViewModel` fetches alerts, tracks unacknowledged count for the tab badge, and exposes a `clearAlert` action. `AlertDetailView` is a stateless view passed a `CentralAlert`. Deep-link routing from push notifications is wired via `NavigationPath`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest

## Global Constraints

- Deployment target: iOS 16.0+
- Page size: 100 alerts per fetch; sorted newest-first (API default)
- Unacknowledged alert count = alerts where `isCleared == false`; drives tab badge
- Acknowledge maps to `POST /clearalerts`; on success remove from list without refetching
- Deep-link: alert notifications carry `alert_id`; `AlertsViewModel.navigateTo(alertId:)` sets `NavigationPath`
- Prerequisite: Phases 1–6 complete

---

### Task 17: AlertsViewModel + AlertsView

**Files:**
- Create: `ArubaCentral/Features/Alerts/AlertsViewModel.swift`
- Create: `ArubaCentral/Features/Alerts/AlertsView.swift`
- Modify: `ArubaCentral/App/RootView.swift` — replace `AlertsPlaceholder`, wire badge count
- Test: `ArubaCentralTests/Features/Alerts/AlertsViewModelTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchAlerts()`, `clearAlert()`, `CentralAlert`, `AlertSeverity`, `PaginatedResponse`, `LoadState`
- Produces: `AlertsViewModel`, `AlertsView`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Features/Alerts/AlertsViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class AlertsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: AlertsViewModel!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = AlertsViewModel(client: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    // MARK: - load

    func testLoadSetsLoadedState() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertEqual(alerts.count, 1)
    }

    func testLoadSetsErrorOnFailure() async {
        mockClient.alertsResult = .failure(.networkError)
        await sut.load()
        guard case .error = sut.alertsState else { return XCTFail("Expected error") }
    }

    // MARK: - unacknowledgedCount

    func testUnacknowledgedCountExcludesCleared() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: true),
            makeAlert("a3", cleared: false),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 2)
    }

    func testUnacknowledgedCountZeroWhenAllCleared() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: true),
            makeAlert("a2", cleared: true),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 0)
    }

    // MARK: - acknowledge

    func testAcknowledgeCallsClearAlert() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        XCTAssertEqual(mockClient.clearAlertCallCount, 1)
    }

    func testAcknowledgeMarksAlertClearedLocally() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertTrue(alerts.first(where: { $0.id == "a1" })?.isCleared ?? false)
    }

    func testAcknowledgeDecrementsUnacknowledgedCount() async {
        mockClient.alertsResult = .success(.of([
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: false),
        ]))
        await sut.load()
        XCTAssertEqual(sut.unacknowledgedCount, 2)
        await sut.acknowledge(alertId: "a1")
        XCTAssertEqual(sut.unacknowledgedCount, 1)
    }

    func testAcknowledgeSetsErrorOnAPIFailure() async {
        mockClient.alertsResult  = .success(.of([makeAlert("a1", cleared: false)]))
        mockClient.clearAlertError = .serverError(500)
        await sut.load()
        await sut.acknowledge(alertId: "a1")
        XCTAssertNotNil(sut.actionError)
    }

    // MARK: - Pagination

    func testLoadNextPageAppendsAlerts() async {
        let firstPage  = (0..<100).map { makeAlert("a\($0)", cleared: false) }
        let secondPage = (100..<120).map { makeAlert("b\($0)", cleared: false) }

        mockClient.alertsResult = .success(PaginatedResponse(items: firstPage, total: 120, offset: 0, limit: 100))
        await sut.load()

        mockClient.alertsResult = .success(PaginatedResponse(items: secondPage, total: 120, offset: 100, limit: 100))
        await sut.loadNextPage()

        guard case .loaded(let alerts) = sut.alertsState else { return XCTFail() }
        XCTAssertEqual(alerts.count, 120)
    }

    func testLoadNextPageDoesNothingWhenNoMore() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        let callsBefore = mockClient.clearAlertCallCount
        await sut.loadNextPage()
        XCTAssertEqual(mockClient.clearAlertCallCount, callsBefore)
    }

    // MARK: - navigateTo

    func testNavigateToAlertIdSelectsAlert() async {
        let alert = makeAlert("target-id", cleared: false)
        mockClient.alertsResult = .success(.of([alert]))
        await sut.load()
        sut.navigateTo(alertId: "target-id")
        XCTAssertEqual(sut.selectedAlertId, "target-id")
    }

    func testNavigateToUnknownAlertIdLoadsFirst() async {
        mockClient.alertsResult = .success(.of([makeAlert("a1", cleared: false)]))
        await sut.load()
        sut.navigateTo(alertId: "unknown-id")
        // Should load but not crash
        XCTAssertEqual(sut.selectedAlertId, "unknown-id")
    }

    // MARK: - Helpers

    private func makeAlert(_ id: String, cleared: Bool) -> CentralAlert {
        CentralAlert(id: id, name: "AP Down", severity: .critical,
                     description: "AP unreachable", deviceSerial: "SN001",
                     site: "HQ", timestamp: Date(), isCleared: cleared)
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
  -only-testing:ArubaCentralTests/AlertsViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `AlertsViewModel` not found.

- [ ] **Step 3: Create `AlertsViewModel.swift`**

Create `ArubaCentral/Features/Alerts/AlertsViewModel.swift`:

```swift
import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var alertsState: LoadState<[CentralAlert]> = .idle
    @Published var actionError: APIError? = nil
    @Published var selectedAlertId: String? = nil

    private let client: CentralAPIClientProtocol
    private let pageSize = 100
    private var offset   = 0
    private var hasMore  = false
    private var isLoadingMore = false

    var unacknowledgedCount: Int {
        guard case .loaded(let alerts) = alertsState else { return 0 }
        return alerts.filter { !$0.isCleared }.count
    }

    init(client: CentralAPIClientProtocol) {
        self.client = client
    }

    func load() async {
        alertsState = .loading
        offset = 0
        await fetchAlerts(offset: 0, appending: false)
    }

    func refresh() async {
        offset = 0
        await fetchAlerts(offset: 0, appending: false)
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchAlerts(offset: offset, appending: true)
    }

    func acknowledge(alertId: String) async {
        do {
            try await client.clearAlert(alertId: alertId)
            // Update locally — mark as cleared without a full refetch
            if case .loaded(let alerts) = alertsState {
                let updated = alerts.map { alert in
                    guard alert.id == alertId else { return alert }
                    return CentralAlert(id: alert.id, name: alert.name,
                                        severity: alert.severity,
                                        description: alert.description,
                                        deviceSerial: alert.deviceSerial,
                                        site: alert.site,
                                        timestamp: alert.timestamp,
                                        isCleared: true)
                }
                alertsState = .loaded(updated)
            }
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }

    func navigateTo(alertId: String) {
        selectedAlertId = alertId
    }

    private func fetchAlerts(offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchAlerts(limit: pageSize, offset: offset)
            self.offset  = offset + page.items.count
            self.hasMore = page.hasMore

            if appending, case .loaded(let existing) = alertsState {
                alertsState = .loaded(existing + page.items)
            } else {
                alertsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { alertsState = .error(error) }
        } catch {
            if !appending { alertsState = .error(.networkError) }
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
  -only-testing:ArubaCentralTests/AlertsViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'AlertsViewModelTests' passed`

- [ ] **Step 5: Create `AlertsView.swift`**

Create `ArubaCentral/Features/Alerts/AlertsView.swift`:

```swift
import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel
    @State private var navigationPath = NavigationPath()

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: AlertsViewModel(client: client))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LoadStateView(
                state: viewModel.alertsState,
                content: { alerts in alertList(alerts) },
                retry: { Task { await viewModel.load() } }
            )
            .navigationTitle("Alerts")
            .navigationDestination(for: CentralAlert.self) { alert in
                AlertDetailView(alert: alert, onAcknowledge: {
                    Task { await viewModel.acknowledge(alertId: alert.id) }
                })
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAlertNotification)) { note in
            if let alertId = note.userInfo?["alert_id"] as? String {
                viewModel.navigateTo(alertId: alertId)
            }
        }
        .onChange(of: viewModel.selectedAlertId) { _, alertId in
            guard let alertId,
                  case .loaded(let alerts) = viewModel.alertsState,
                  let alert = alerts.first(where: { $0.id == alertId }) else { return }
            navigationPath.append(alert)
            viewModel.selectedAlertId = nil
        }
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError?.userMessage ?? "") }
    }

    @ViewBuilder
    private func alertList(_ alerts: [CentralAlert]) -> some View {
        if alerts.isEmpty {
            ContentUnavailableView("No Alerts", systemImage: "bell.slash",
                                   description: Text("Your network has no alerts."))
        } else {
            List(alerts) { alert in
                NavigationLink(value: alert) {
                    AlertRowView(alert: alert)
                }
                .onAppear {
                    if alert.id == alerts.last?.id { Task { await viewModel.loadNextPage() } }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.refresh() }
        }
    }
}

struct AlertRowView: View {
    let alert: CentralAlert

    var body: some View {
        HStack(spacing: 12) {
            // Unacknowledged left border indicator
            Rectangle()
                .fill(alert.isCleared ? Color.clear : alert.severity.color)
                .frame(width: 4)
                .clipShape(Capsule())
                .accessibilityHidden(true)

            Image(systemName: alert.severity.systemImage)
                .foregroundStyle(alert.severity.color)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.name)
                    .font(.headline)
                    .foregroundStyle(alert.isCleared ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let site = alert.site { Text(site).font(.caption).foregroundStyle(.secondary) }
                    Text(alert.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if alert.isCleared {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
                    .accessibilityLabel("Acknowledged")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let status = alert.isCleared ? "acknowledged" : "unacknowledged"
        return "\(alert.severity.rawValue) alert: \(alert.name), \(status)"
    }
}

extension Notification.Name {
    static let didReceiveAlertNotification = Notification.Name("didReceiveAlertNotification")
}
```

- [ ] **Step 6: Add `AlertSeverity` visual properties**

Add to `ArubaCentral/Core/Models/AlertSeverity.swift`:

```swift
extension AlertSeverity {
    var color: Color {
        switch self {
        case .critical: return .red
        case .major:    return .orange
        case .minor:    return .yellow
        case .info:     return .blue
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

- [ ] **Step 7: Wire into RootView with badge**

In `ArubaCentral/App/RootView.swift`:

1. Add `@StateObject private var alertsViewModel: AlertsViewModel` initialised with `apiClient`
2. Replace the Alerts tab:

```swift
// Before:
NavigationStack {
    AlertsPlaceholder()
}
.tabItem { Label("Alerts", systemImage: "bell") }

// After:
AlertsView(client: apiClient)
    .tabItem {
        Label("Alerts", systemImage: alertsViewModel.unacknowledgedCount > 0 ? "bell.badge" : "bell")
    }
    .badge(alertsViewModel.unacknowledgedCount > 0 ? alertsViewModel.unacknowledgedCount : nil)
```

- [ ] **Step 8: Commit**

```bash
git add \
  ArubaCentral/Features/Alerts/AlertsViewModel.swift \
  ArubaCentral/Features/Alerts/AlertsView.swift \
  ArubaCentral/Core/Models/AlertSeverity.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Alerts/AlertsViewModelTests.swift
git commit -m "feat: add Alerts tab — paginated list with severity icons, unread badge, and acknowledge action"
```

---

### Task 18: AlertDetailView + deep-link navigation

**Files:**
- Create: `ArubaCentral/Features/Alerts/AlertDetailView.swift`

**Interfaces:**
- Consumes: `CentralAlert`, `onAcknowledge: () -> Void` closure
- Produces: `AlertDetailView` — stateless; all state lives in `AlertsViewModel`

---

- [ ] **Step 1: Create `AlertDetailView.swift`**

Create `ArubaCentral/Features/Alerts/AlertDetailView.swift`:

```swift
import SwiftUI

struct AlertDetailView: View {
    let alert: CentralAlert
    let onAcknowledge: () -> Void

    @State private var showingConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: alert.severity.systemImage)
                        .foregroundStyle(alert.severity.color)
                        .font(.title2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.name).font(.headline)
                        Text(alert.severity.rawValue)
                            .font(.caption)
                            .foregroundStyle(alert.severity.color)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                if let desc = alert.description {
                    Text(desc).font(.body).foregroundStyle(.secondary)
                }
                if let device = alert.deviceSerial {
                    LabeledContent("Device", value: device)
                }
                if let site = alert.site {
                    LabeledContent("Site", value: site)
                }
                LabeledContent("Time", value: alert.timestamp.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Status") {
                if alert.isCleared {
                    Label("Acknowledged", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        showingConfirm = true
                    } label: {
                        Label("Acknowledge Alert", systemImage: "checkmark.circle")
                    }
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
                description: "AP-Lobby (SN001) is unreachable. Check power and uplink.",
                deviceSerial: "SN001", site: "HQ Campus",
                timestamp: Date(), isCleared: false
            ),
            onAcknowledge: {}
        )
    }
}
```

- [ ] **Step 2: Run all Phase 7 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/AlertsViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'AlertsViewModelTests' passed`

- [ ] **Step 3: Build and verify on simulator**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Verify on simulator:
- Alerts tab shows badge when unacknowledged alerts exist
- Alert list shows severity icon, colored left border for unread, relative timestamp
- Tapping alert navigates to Alert Detail
- Acknowledge button triggers confirmation and marks alert cleared (badge decrements)

- [ ] **Step 4: Commit**

```bash
git add \
  ArubaCentral/Features/Alerts/AlertDetailView.swift
git commit -m "feat: add Alert Detail — severity info, device/site context, acknowledge confirmation"
```

---

## Phase 7 Complete

- **`AlertsViewModel`** — paginated alert fetch, local acknowledge (no refetch), `unacknowledgedCount` for badge, `navigateTo(alertId:)` for deep-link routing; 12 unit tests
- **`AlertsView`** — paginated list with severity icons, unread left-border indicator, tab badge, `NotificationCenter` deep-link receiver
- **`AlertRowView`** — severity color, acknowledged checkmark, full accessibility label
- **`AlertDetailView`** — stateless detail driven by `CentralAlert`; acknowledge confirmation dialog

**Next:** Phase 8 — Settings tab (`SettingsViewModel`, `SettingsView`, region picker, notification preferences, appearance, test connection)
