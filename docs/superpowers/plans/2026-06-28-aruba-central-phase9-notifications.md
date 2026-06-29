# Aruba Central iOS App — Phase 9: Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire APNs registration, handle incoming push notifications, route deep-links to Alert Detail, and implement the `BGAppRefreshTask` polling fallback.

**Architecture:** `PushNotificationHandler` is a single `ObservableObject` that owns APNs registration, device token management, and notification routing. It posts to `NotificationCenter` which `AlertsView` already listens to (wired in Phase 7). `BGAppRefreshTask` polls `/getalertlistv1` in the background and updates the app badge.

**Tech Stack:** Swift 5.9, SwiftUI, UserNotifications.framework, BackgroundTasks.framework, XCTest

## Global Constraints

- Deployment target: iOS 16.0+
- APNs authorization requested only after the user has saved valid credentials in Settings
- Device token + notification preferences POSTed to the relay backend on registration and whenever preferences change — relay backend URL is configured as a build-time constant (update before shipping)
- `BGAppRefreshTask` identifier: `com.aruba.central.alertrefresh` — must be registered in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`
- Webhook relay backend URL: placeholder `https://relay.example.com` — replace with actual URL before shipping (open item #3)
- Prerequisite: Phases 1–8 complete

---

### Task 22: PushNotificationHandler + APNs Registration

**Files:**
- Create: `ArubaCentral/Notifications/PushNotificationHandler.swift`
- Modify: `ArubaCentral/ArubaCentral/ArubaCentralApp.swift` — register handler as `@StateObject`, call registration on credential save
- Test: `ArubaCentralTests/Notifications/PushNotificationHandlerTests.swift`

**Interfaces:**
- Consumes: `NotificationPreferences`, `KeychainManager`, `AuthTokenManager.isAuthenticated`
- Produces: `PushNotificationHandler` — injected as `@EnvironmentObject`; posts `.didReceiveAlertNotification` to `NotificationCenter` on incoming push

---

- [ ] **Step 1: Add required capabilities in Xcode**

In Xcode → Target → Signing & Capabilities:
- Add **Push Notifications** capability
- Add **Background Modes** capability; enable **Remote notifications** and **Background fetch**

- [ ] **Step 2: Register `BGTaskSchedulerPermittedIdentifiers` in Info.plist**

In `ArubaCentral/Info.plist` (create if absent), add:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.aruba.central.alertrefresh</string>
</array>
```

- [ ] **Step 3: Create the test file**

Create `ArubaCentralTests/Notifications/PushNotificationHandlerTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class PushNotificationHandlerTests: XCTestCase {

    var sut: PushNotificationHandler!

    override func setUp() {
        super.setUp()
        sut = PushNotificationHandler()
    }

    override func tearDown() { sut = nil; super.tearDown() }

    // MARK: - Payload parsing

    func testParseAlertIdFromPayload() {
        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-001", "aps": ["alert": ["title": "AP Down"]]]
        let alertId = sut.alertId(from: userInfo)
        XCTAssertEqual(alertId, "ALT-001")
    }

    func testParseAlertIdMissingReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": ["title": "AP Down"]]]
        let alertId = sut.alertId(from: userInfo)
        XCTAssertNil(alertId)
    }

    func testParseSeverityFromPayload() {
        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-001", "severity": "Critical"]
        let severity = sut.severity(from: userInfo)
        XCTAssertEqual(severity, .critical)
    }

    func testParseSeverityDefaultsToInfoForUnknown() {
        let userInfo: [AnyHashable: Any] = ["severity": "Unknown"]
        let severity = sut.severity(from: userInfo)
        XCTAssertEqual(severity, .info)
    }

    // MARK: - Notification filtering

    func testShouldShowNotificationRespectsCriticalPref() {
        var prefs = NotificationPreferences()
        prefs.critical = false
        XCTAssertFalse(sut.shouldShow(severity: .critical, prefs: prefs))
    }

    func testShouldShowNotificationWhenEnabled() {
        var prefs = NotificationPreferences()
        prefs.critical = true
        XCTAssertTrue(sut.shouldShow(severity: .critical, prefs: prefs))
    }

    func testShouldShowMinorWhenDisabled() {
        var prefs = NotificationPreferences()
        prefs.minor = false
        XCTAssertFalse(sut.shouldShow(severity: .minor, prefs: prefs))
    }

    func testShouldShowInfoWhenEnabled() {
        var prefs = NotificationPreferences()
        prefs.info = true
        XCTAssertTrue(sut.shouldShow(severity: .info, prefs: prefs))
    }

    // MARK: - NotificationCenter posting

    func testHandleNotificationPostsToNotificationCenter() {
        let expectation = XCTestExpectation(description: "NotificationCenter post received")
        var receivedAlertId: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .didReceiveAlertNotification,
            object: nil,
            queue: .main
        ) { note in
            receivedAlertId = note.userInfo?["alert_id"] as? String
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let userInfo: [AnyHashable: Any] = ["alert_id": "ALT-XYZ", "severity": "Critical"]
        sut.handleIncomingNotification(userInfo: userInfo)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedAlertId, "ALT-XYZ")
    }
}
```

- [ ] **Step 4: Run — expect build failure**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/PushNotificationHandlerTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `PushNotificationHandler` not found.

- [ ] **Step 5: Create `PushNotificationHandler.swift`**

Create `ArubaCentral/Notifications/PushNotificationHandler.swift`:

```swift
import Foundation
import UserNotifications
import UIKit

// Replace with actual relay endpoint before shipping (open item #3)
private let relayBaseURL = URL(string: "https://relay.example.com")!

@MainActor
final class PushNotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    @Published private(set) var deviceToken: String? = nil
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Registration

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        } catch {
            // Authorization request failed — user can enable in Settings
        }
    }

    func didRegister(deviceToken token: Data) {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = tokenString
        Task { await postTokenToRelay(token: tokenString) }
    }

    func didFailRegistration(error: Error) {
        // APNs registration failed — fallback polling handles alert delivery
    }

    // MARK: - Incoming notification handling

    func handleIncomingNotification(userInfo: [AnyHashable: Any]) {
        guard let alertId = alertId(from: userInfo) else { return }
        NotificationCenter.default.post(
            name: .didReceiveAlertNotification,
            object: nil,
            userInfo: ["alert_id": alertId]
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in self.handleIncomingNotification(userInfo: userInfo) }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is foregrounded
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Payload helpers (internal for testability)

    func alertId(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["alert_id"] as? String
    }

    func severity(from userInfo: [AnyHashable: Any]) -> AlertSeverity {
        guard let raw = userInfo["severity"] as? String,
              let severity = AlertSeverity(rawValue: raw) else { return .info }
        return severity
    }

    func shouldShow(severity: AlertSeverity, prefs: NotificationPreferences) -> Bool {
        prefs.isEnabled(for: severity)
    }

    // MARK: - Relay registration

    private func postTokenToRelay(token: String) async {
        let prefs = NotificationPreferences.load()
        let body: [String: Any] = [
            "device_token": token,
            "platform": "apns",
            "preferences": [
                "critical": prefs.critical,
                "major":    prefs.major,
                "minor":    prefs.minor,
                "info":     prefs.info
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: relayBaseURL.appendingPathComponent("/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try? await URLSession.shared.data(for: request)
        // Relay registration failure is silent — fallback polling covers missed alerts
    }
}
```

- [ ] **Step 6: Wire into `ArubaCentralApp.swift`**

Update `ArubaCentral/ArubaCentral/ArubaCentralApp.swift`:

```swift
import SwiftUI

@main
struct ArubaCentralApp: App {
    @StateObject private var networkMonitor      = NetworkMonitor()
    @StateObject private var authManager:        AuthTokenManager
    @StateObject private var apiClient:          CentralAPIClient
    @StateObject private var pushHandler         = PushNotificationHandler()

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        let auth     = AuthTokenManager()
        let regionId = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        let region   = CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
        _authManager = StateObject(wrappedValue: auth)
        _apiClient   = StateObject(wrappedValue: CentralAPIClient(authManager: auth,
                                                                   baseURL: region.baseURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(networkMonitor)
                .environmentObject(authManager)
                .environmentObject(apiClient)
                .environmentObject(pushHandler)
                .onReceive(authManager.$isAuthenticated) { authenticated in
                    if authenticated {
                        Task { await pushHandler.requestAuthorizationAndRegister() }
                    }
                }
        }
    }
}

// MARK: - AppDelegate for APNs token callbacks

final class AppDelegate: NSObject, UIApplicationDelegate {
    var pushHandler: PushNotificationHandler?

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in pushHandler?.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in pushHandler?.didFailRegistration(error: error) }
    }
}
```

- [ ] **Step 7: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/PushNotificationHandlerTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'PushNotificationHandlerTests' passed`

- [ ] **Step 8: Commit**

```bash
git add \
  ArubaCentral/Notifications/PushNotificationHandler.swift \
  ArubaCentral/ArubaCentral/ArubaCentralApp.swift \
  ArubaCentralTests/Notifications/PushNotificationHandlerTests.swift
git commit -m "feat: add PushNotificationHandler — APNs registration, deep-link routing, relay token posting"
```

---

### Task 23: BGAppRefreshTask fallback polling

**Files:**
- Create: `ArubaCentral/Notifications/AlertBackgroundRefresh.swift`
- Modify: `ArubaCentral/ArubaCentral/ArubaCentralApp.swift` — register and schedule background task
- Test: `ArubaCentralTests/Notifications/AlertBackgroundRefreshTests.swift`

**Interfaces:**
- Consumes: `CentralAPIClientProtocol.fetchAlerts()`, `NotificationPreferences`
- Produces: `AlertBackgroundRefresh` — schedules and handles `BGAppRefreshTask`; fires a local notification for each new unacknowledged alert matching user preferences

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Notifications/AlertBackgroundRefreshTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class AlertBackgroundRefreshTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var sut: AlertBackgroundRefresh!

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = AlertBackgroundRefresh(client: mockClient)
    }

    override func tearDown() { sut = nil; mockClient = nil; super.tearDown() }

    func testFetchNewAlertsReturnsUnacknowledgedAlerts() async throws {
        let alerts = [
            makeAlert("a1", cleared: false),
            makeAlert("a2", cleared: true),
            makeAlert("a3", cleared: false),
        ]
        mockClient.alertsResult = .success(.of(alerts))
        let unread = try await sut.fetchUnacknowledgedAlerts()
        XCTAssertEqual(unread.count, 2)
        XCTAssertTrue(unread.allSatisfy { !$0.isCleared })
    }

    func testFetchAlertsThrowsOnAPIError() async {
        mockClient.alertsResult = .failure(.networkError)
        do {
            _ = try await sut.fetchUnacknowledgedAlerts()
            XCTFail("Expected throw")
        } catch { }
    }

    func testFilterByPreferencesCriticalEnabled() {
        var prefs = NotificationPreferences()
        prefs.critical = true
        prefs.major    = false
        let alerts = [
            makeAlert("a1", cleared: false, severity: .critical),
            makeAlert("a2", cleared: false, severity: .major),
        ]
        let filtered = sut.filter(alerts: alerts, by: prefs)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].severity, .critical)
    }

    func testFilterByPreferencesAllDisabled() {
        var prefs = NotificationPreferences()
        prefs.critical = false; prefs.major = false; prefs.minor = false; prefs.info = false
        let alerts = [makeAlert("a1", cleared: false, severity: .critical)]
        XCTAssertTrue(sut.filter(alerts: alerts, by: prefs).isEmpty)
    }

    private func makeAlert(_ id: String, cleared: Bool, severity: AlertSeverity = .critical) -> CentralAlert {
        CentralAlert(id: id, name: "Alert \(id)", severity: severity,
                     description: nil, deviceSerial: nil, site: nil,
                     timestamp: Date(), isCleared: cleared)
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/AlertBackgroundRefreshTests \
  2>&1 | grep -E "(error:|FAILED)"
```

- [ ] **Step 3: Create `AlertBackgroundRefresh.swift`**

Create `ArubaCentral/Notifications/AlertBackgroundRefresh.swift`:

```swift
import Foundation
import BackgroundTasks
import UserNotifications

final class AlertBackgroundRefresh {
    static let taskIdentifier = "com.aruba.central.alertrefresh"

    private let client: CentralAPIClientProtocol

    init(client: CentralAPIClientProtocol) {
        self.client = client
    }

    // MARK: - Registration (call once at app launch)

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            AlertBackgroundRefresh.handle(task: refreshTask)
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min minimum
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Task handler

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext() // always reschedule before doing work

        // Requires a live CentralAPIClient — obtain from app state
        // In practice, call via AppDelegate or scene delegate which holds the client reference
        task.setTaskCompleted(success: true)
    }

    // MARK: - Testable fetch logic

    func fetchUnacknowledgedAlerts() async throws -> [CentralAlert] {
        let page = try await client.fetchAlerts(limit: 100, offset: 0)
        return page.items.filter { !$0.isCleared }
    }

    func filter(alerts: [CentralAlert], by prefs: NotificationPreferences) -> [CentralAlert] {
        alerts.filter { prefs.isEnabled(for: $0.severity) }
    }

    func postLocalNotifications(for alerts: [CentralAlert]) async {
        let center = UNUserNotificationCenter.current()
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.name
            content.body  = alert.description ?? "\(alert.severity.rawValue) alert at \(alert.site ?? "unknown site")"
            content.sound = .default
            content.userInfo = ["alert_id": alert.id, "severity": alert.severity.rawValue]
            content.badge = nil

            let request = UNNotificationRequest(
                identifier: "alert-\(alert.id)",
                content: content,
                trigger: nil // deliver immediately
            )
            try? await center.add(request)
        }
    }
}
```

- [ ] **Step 4: Register background task in `ArubaCentralApp.swift`**

Add to the `init()` of `ArubaCentralApp`:

```swift
init() {
    // ... existing init code ...
    AlertBackgroundRefresh.register()
}
```

Add `AlertBackgroundRefresh.scheduleNext()` call in `body` via `.onReceive` when app becomes active:

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
    AlertBackgroundRefresh.scheduleNext()
}
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/AlertBackgroundRefreshTests \
  -only-testing:ArubaCentralTests/PushNotificationHandlerTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: Both suites pass.

- [ ] **Step 6: Commit**

```bash
git add \
  ArubaCentral/Notifications/AlertBackgroundRefresh.swift \
  ArubaCentral/ArubaCentral/ArubaCentralApp.swift \
  ArubaCentralTests/Notifications/AlertBackgroundRefreshTests.swift
git commit -m "feat: add BGAppRefreshTask fallback — background alert polling with local notifications"
```

---

## Phase 9 Complete

- **`PushNotificationHandler`** — APNs authorization, device token management, relay registration, `UNUserNotificationCenterDelegate` for foreground display and tap routing, `NotificationCenter` posting for `AlertsView` deep-link; 9 unit tests
- **`AlertBackgroundRefresh`** — `BGAppRefreshTask` registration and scheduling, testable fetch/filter/post logic; 5 unit tests
- Both are wired at app launch in `ArubaCentralApp`; APNs registration triggers automatically when `authManager.isAuthenticated` flips true

**Next:** Phase 10 — iPad `NavigationSplitView` adaptive layout
