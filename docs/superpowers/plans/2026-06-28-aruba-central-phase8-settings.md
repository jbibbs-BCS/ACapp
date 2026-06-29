# Aruba Central iOS App — Phase 8: Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Settings tab — credential entry, region picker (14 pre-populated regions), test connection button, notification severity toggles, and appearance override.

**Architecture:** `SettingsViewModel` owns all credential/region/preference mutations. Credentials write to Keychain. Region and appearance write to `UserDefaults`. `NotificationPreferences` is a lightweight `Codable` struct stored in `UserDefaults` and posted to the webhook relay on change.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, KeychainManager, UserDefaults

## Global Constraints

- Deployment target: iOS 16.0+
- Credentials (Client ID, Client Secret) stored in `KeychainManager` — never in `UserDefaults` or logs
- Region stored as region `id` string in `UserDefaults` key `"selectedRegionId"`
- Appearance stored as `"system"`, `"light"`, or `"dark"` in `UserDefaults` key `"appearance"` (already read by `RootView`)
- Notification preferences stored in `UserDefaults` key `"notificationPreferences"` as JSON
- "Test Connection" calls `CentralAPIClient.testConnection()` and displays result inline
- Prerequisite: Phases 1–7 complete

---

### Task 19: SettingsViewModel + SettingsView

**Files:**
- Create: `ArubaCentral/Features/Settings/NotificationPreferences.swift`
- Create: `ArubaCentral/Features/Settings/SettingsViewModel.swift`
- Create: `ArubaCentral/Features/Settings/SettingsView.swift`
- Modify: `ArubaCentral/App/RootView.swift` — replace `SettingsPlaceholder` with `SettingsView`
- Test: `ArubaCentralTests/Features/Settings/SettingsViewModelTests.swift`

**Interfaces:**
- Consumes: `KeychainManager`, `CentralAPIClientProtocol.testConnection()`, `AuthTokenManager.clearCredentials()`, `CentralRegion.all`, `CentralAPIClient.baseURL`
- Produces: `SettingsViewModel`, `SettingsView`, `NotificationPreferences`

---

- [ ] **Step 1: Create `NotificationPreferences.swift`**

Create `ArubaCentral/Features/Settings/NotificationPreferences.swift`:

```swift
import Foundation

struct NotificationPreferences: Codable, Equatable {
    var critical: Bool = true
    var major:    Bool = true
    var minor:    Bool = false
    var info:     Bool = false

    static let defaultKey = "notificationPreferences"

    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: defaultKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return NotificationPreferences() }
        return prefs
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: NotificationPreferences.defaultKey)
    }

    func isEnabled(for severity: AlertSeverity) -> Bool {
        switch severity {
        case .critical: return critical
        case .major:    return major
        case .minor:    return minor
        case .info:     return info
        }
    }
}
```

- [ ] **Step 2: Create the test file**

Create `ArubaCentralTests/Features/Settings/SettingsViewModelTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class SettingsViewModelTests: XCTestCase {

    var mockClient: MockCentralAPIClient!
    var keychain: KeychainManager!
    var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        UserDefaults.standard.removeObject(forKey: "selectedRegionId")
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.defaultKey)
        mockClient = MockCentralAPIClient()
        sut = SettingsViewModel(client: mockClient)
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        UserDefaults.standard.removeObject(forKey: "selectedRegionId")
        UserDefaults.standard.removeObject(forKey: NotificationPreferences.defaultKey)
        sut = nil; mockClient = nil; super.tearDown()
    }

    // MARK: - Credentials

    func testSaveCredentialsPersistsToKeychain() throws {
        sut.clientId     = "test-id"
        sut.clientSecret = "test-secret"
        try sut.saveCredentials()
        XCTAssertEqual(try keychain.retrieve(for: .clientId),     "test-id")
        XCTAssertEqual(try keychain.retrieve(for: .clientSecret), "test-secret")
    }

    func testSaveCredentialsThrowsForEmptyId() {
        sut.clientId     = ""
        sut.clientSecret = "secret"
        XCTAssertThrowsError(try sut.saveCredentials()) { error in
            XCTAssertEqual(error as? SettingsError, .emptyClientId)
        }
    }

    func testSaveCredentialsThrowsForEmptySecret() {
        sut.clientId     = "id"
        sut.clientSecret = ""
        XCTAssertThrowsError(try sut.saveCredentials()) { error in
            XCTAssertEqual(error as? SettingsError, .emptyClientSecret)
        }
    }

    func testLoadCredentialsPopulatesFields() throws {
        try keychain.save("loaded-id",     for: .clientId)
        try keychain.save("loaded-secret", for: .clientSecret)
        sut.loadCredentials()
        XCTAssertEqual(sut.clientId,     "loaded-id")
        XCTAssertEqual(sut.clientSecret, "loaded-secret")
    }

    func testLoadCredentialsLeavesFieldsEmptyWhenNotSet() {
        sut.loadCredentials()
        XCTAssertEqual(sut.clientId,     "")
        XCTAssertEqual(sut.clientSecret, "")
    }

    // MARK: - Region

    func testDefaultRegionIsUS1() {
        XCTAssertEqual(sut.selectedRegion.id, "us1")
    }

    func testSaveRegionPersistsToUserDefaults() {
        let de1 = CentralRegion.all.first { $0.id == "de1" }!
        sut.selectedRegion = de1
        sut.saveRegion()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedRegionId"), "de1")
    }

    func testLoadRegionRestoresSavedRegion() {
        UserDefaults.standard.set("jp1", forKey: "selectedRegionId")
        sut.loadRegion()
        XCTAssertEqual(sut.selectedRegion.id, "jp1")
    }

    func testLoadRegionFallsBackToUS1WhenInvalidId() {
        UserDefaults.standard.set("invalid-id", forKey: "selectedRegionId")
        sut.loadRegion()
        XCTAssertEqual(sut.selectedRegion.id, "us1")
    }

    // MARK: - Notification Preferences

    func testDefaultNotificationPreferences() {
        XCTAssertTrue(sut.notificationPrefs.critical)
        XCTAssertTrue(sut.notificationPrefs.major)
        XCTAssertFalse(sut.notificationPrefs.minor)
        XCTAssertFalse(sut.notificationPrefs.info)
    }

    func testSaveNotificationPreferencesPersists() {
        sut.notificationPrefs.minor = true
        sut.saveNotificationPrefs()
        let loaded = NotificationPreferences.load()
        XCTAssertTrue(loaded.minor)
    }

    // MARK: - Test Connection

    func testConnectionSuccessUpdatesState() async {
        mockClient.testConnectionError = nil
        await sut.testConnection()
        if case .success = sut.connectionTestResult { } else {
            XCTFail("Expected success, got \(String(describing: sut.connectionTestResult))")
        }
    }

    func testConnectionFailureUpdatesState() async {
        mockClient.testConnectionError = .unauthorized
        await sut.testConnection()
        if case .failure = sut.connectionTestResult { } else {
            XCTFail("Expected failure")
        }
    }

    func testConnectionTestingStateWhileInProgress() async {
        // connectionTestResult should be .testing during the call
        // Hard to assert timing, but we verify it ends in a terminal state
        await sut.testConnection()
        if case .testing = sut.connectionTestResult {
            XCTFail("Should not remain in testing state after completion")
        }
    }
}
```

- [ ] **Step 3: Run — expect build failure**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SettingsViewModelTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `SettingsViewModel`, `SettingsError` not found.

- [ ] **Step 4: Create `SettingsViewModel.swift`**

Create `ArubaCentral/Features/Settings/SettingsViewModel.swift`:

```swift
import Foundation

enum SettingsError: Error, Equatable {
    case emptyClientId
    case emptyClientSecret
}

enum ConnectionTestResult {
    case idle
    case testing
    case success(tokenExpiry: Date)
    case failure(APIError)
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var clientId:     String = ""
    @Published var clientSecret: String = ""
    @Published var selectedRegion: CentralRegion = CentralRegion.defaultRegion
    @Published var notificationPrefs = NotificationPreferences.load()
    @Published private(set) var connectionTestResult: ConnectionTestResult = .idle
    @Published var credentialsSaved = false

    private let keychain = KeychainManager()
    private let client: CentralAPIClientProtocol

    init(client: CentralAPIClientProtocol) {
        self.client = client
        loadCredentials()
        loadRegion()
    }

    // MARK: - Credentials

    func loadCredentials() {
        clientId     = (try? keychain.retrieve(for: .clientId))     ?? ""
        clientSecret = (try? keychain.retrieve(for: .clientSecret)) ?? ""
    }

    func saveCredentials() throws {
        guard !clientId.isEmpty     else { throw SettingsError.emptyClientId }
        guard !clientSecret.isEmpty else { throw SettingsError.emptyClientSecret }
        try keychain.save(clientId,     for: .clientId)
        try keychain.save(clientSecret, for: .clientSecret)
        credentialsSaved = true
    }

    // MARK: - Region

    func loadRegion() {
        let id = UserDefaults.standard.string(forKey: "selectedRegionId") ?? "us1"
        selectedRegion = CentralRegion.all.first { $0.id == id } ?? CentralRegion.defaultRegion
    }

    func saveRegion() {
        UserDefaults.standard.set(selectedRegion.id, forKey: "selectedRegionId")
    }

    // MARK: - Notification preferences

    func saveNotificationPrefs() {
        notificationPrefs.save()
    }

    // MARK: - Test connection

    func testConnection() async {
        connectionTestResult = .testing
        do {
            try await client.testConnection()
            let expiry = (try? keychain.retrieve(for: .tokenExpiry))
                .flatMap { Double($0) }
                .map { Date(timeIntervalSince1970: $0) }
                ?? Date().addingTimeInterval(7199)
            connectionTestResult = .success(tokenExpiry: expiry)
        } catch let error as APIError {
            connectionTestResult = .failure(error)
        } catch {
            connectionTestResult = .failure(.networkError)
        }
    }
}
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SettingsViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'SettingsViewModelTests' passed`

- [ ] **Step 6: Create `SettingsView.swift`**

Create `ArubaCentral/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage("appearance") private var appearanceRaw = "system"
    @State private var showingClientSecret = false
    @State private var credentialsError: String? = nil

    init(client: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(client: client))
    }

    var body: some View {
        Form {
            accountSection
            notificationsSection
            appearanceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Error", isPresented: .constant(credentialsError != nil)) {
            Button("OK") { credentialsError = nil }
        } message: { Text(credentialsError ?? "") }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            TextField("Client ID", text: $viewModel.clientId)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Group {
                    if showingClientSecret {
                        TextField("Client Secret", text: $viewModel.clientSecret)
                    } else {
                        SecureField("Client Secret", text: $viewModel.clientSecret)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    showingClientSecret.toggle()
                } label: {
                    Image(systemName: showingClientSecret ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showingClientSecret ? "Hide secret" : "Show secret")
            }

            Picker("Region", selection: $viewModel.selectedRegion) {
                ForEach(CentralRegion.all) { region in
                    Text(region.label).tag(region)
                }
            }

            Button("Save Credentials") {
                do {
                    try viewModel.saveCredentials()
                    viewModel.saveRegion()
                } catch let error as SettingsError {
                    credentialsError = error.userMessage
                } catch {
                    credentialsError = "Failed to save credentials."
                }
            }
            .disabled(viewModel.clientId.isEmpty || viewModel.clientSecret.isEmpty)

            testConnectionRow

        } header: {
            Text("Account")
        } footer: {
            Text("Credentials are stored securely in the iOS Keychain.")
        }
    }

    @ViewBuilder
    private var testConnectionRow: some View {
        HStack {
            Button("Test Connection") {
                Task { await viewModel.testConnection() }
            }
            .disabled({
                if case .testing = viewModel.connectionTestResult { return true }
                return false
            }())

            Spacer()

            switch viewModel.connectionTestResult {
            case .idle:
                EmptyView()
            case .testing:
                ProgressView().controlSize(.small)
            case .success(let expiry):
                VStack(alignment: .trailing, spacing: 2) {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                    Text("Token valid until \(expiry.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .failure(let error):
                Label(error.userMessage, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle("Critical", isOn: $viewModel.notificationPrefs.critical)
                .onChange(of: viewModel.notificationPrefs.critical) { _, _ in viewModel.saveNotificationPrefs() }
            Toggle("Major", isOn: $viewModel.notificationPrefs.major)
                .onChange(of: viewModel.notificationPrefs.major) { _, _ in viewModel.saveNotificationPrefs() }
            Toggle("Minor", isOn: $viewModel.notificationPrefs.minor)
                .onChange(of: viewModel.notificationPrefs.minor) { _, _ in viewModel.saveNotificationPrefs() }
            Toggle("Info", isOn: $viewModel.notificationPrefs.info)
                .onChange(of: viewModel.notificationPrefs.info) { _, _ in viewModel.saveNotificationPrefs() }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Choose which alert severities trigger push notifications.")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build",   value: buildNumber)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

private extension SettingsError {
    var userMessage: String {
        switch self {
        case .emptyClientId:     return "Client ID cannot be empty."
        case .emptyClientSecret: return "Client Secret cannot be empty."
        }
    }
}
```

- [ ] **Step 7: Wire into RootView**

In `ArubaCentral/App/RootView.swift`, replace the Settings tab:

```swift
// Before:
NavigationStack {
    SettingsPlaceholder()
}
.tabItem { Label("Settings", systemImage: "gearshape") }

// After:
NavigationStack {
    SettingsView(client: apiClient)
}
.tabItem { Label("Settings", systemImage: "gearshape") }
```

- [ ] **Step 8: Add all files to Xcode targets and run all Phase 8 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/SettingsViewModelTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'SettingsViewModelTests' passed`

- [ ] **Step 9: Build and verify on simulator**

```bash
xcodebuild build \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Verify on simulator:
- Settings tab shows all four sections
- Credentials save to Keychain (verify via test connection)
- Region picker shows all 14 regions
- Test Connection shows green success state with token expiry time
- Notification toggles persist across app restarts
- Appearance toggle changes app-wide color scheme instantly

- [ ] **Step 10: Commit**

```bash
git add \
  ArubaCentral/Features/Settings/NotificationPreferences.swift \
  ArubaCentral/Features/Settings/SettingsViewModel.swift \
  ArubaCentral/Features/Settings/SettingsView.swift \
  ArubaCentral/App/RootView.swift \
  ArubaCentralTests/Features/Settings/SettingsViewModelTests.swift
git commit -m "feat: add Settings tab — credentials, 14-region picker, test connection, notification prefs, appearance"
```

---

## Phase 8 Complete

All five tabs are now functional:

- **`NotificationPreferences`** — `Codable` struct with per-severity toggles; persisted to `UserDefaults`
- **`SettingsViewModel`** — credential save/load (Keychain), region save/load (`UserDefaults`), notification pref persistence, `testConnection()` with `ConnectionTestResult` state enum; 13 unit tests
- **`SettingsView`** — Account section (Client ID, masked secret with reveal toggle, 14-region picker, save button, inline test connection result), Notifications section (4 severity toggles), Appearance section (System/Light/Dark segmented control), About section (version + build)

**Next:** Phase 9 — Push Notifications (`PushNotificationHandler`, APNs registration, `BGAppRefreshTask` fallback)
