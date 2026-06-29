# Aruba Central iOS App — Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the typed foundation — errors, load state, paginated responses, all five Codable models, and secure Keychain storage — that every subsequent phase depends on.

**Architecture:** Pure Swift structs and enums with no SwiftUI imports. All types are Codable, Identifiable, and tested in isolation via XCTest. No networking yet.

**Tech Stack:** Swift 5.9, XCTest, Security.framework (Keychain)

## Global Constraints

- Deployment target: iOS 16.0+
- Language: Swift 5.9
- No third-party dependencies
- All model CodingKeys use explicit mapping (snake_case API → camelCase Swift) — do NOT rely on `.convertFromSnakeCase` so field names are visible and auditable
- NOTE: CodingKey values are best-effort based on available API docs — verify each against the live `/getsitehealthv1`, `/accesspointsv1`, `/switchesv1`, `/listunifiedclients`, `/getalertlistv1` responses before shipping
- Test target name: `ArubaCentralTests`
- Project file: `ArubaCentral.xcodeproj`
- Simulator: `iPhone 16` (adjust to available simulator if needed)

---

### Task 1: Foundation Types — APIError, LoadState, PaginatedResponse

**Files:**
- Create: `ArubaCentral/Core/API/APIError.swift`
- Create: `ArubaCentral/Core/API/LoadState.swift`
- Create: `ArubaCentral/Core/API/PaginatedResponse.swift`
- Test: `ArubaCentralTests/Core/API/FoundationTypesTests.swift`

**Interfaces:**
- Produces: `APIError` (used by every ViewModel and CentralAPIClient), `LoadState<T>` (used by every ViewModel), `PaginatedResponse<T>` (used by list endpoints)

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Core/API/FoundationTypesTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class FoundationTypesTests: XCTestCase {

    // MARK: - APIError

    func testAPIErrorUserMessageUnauthorized() {
        XCTAssertFalse(APIError.unauthorized.userMessage.isEmpty)
    }

    func testAPIErrorUserMessageForbidden() {
        XCTAssertFalse(APIError.forbidden.userMessage.isEmpty)
    }

    func testAPIErrorUserMessageServerError() {
        let msg = APIError.serverError(500).userMessage
        XCTAssertTrue(msg.contains("500"))
    }

    func testAPIErrorEquality() {
        XCTAssertEqual(APIError.unauthorized, APIError.unauthorized)
        XCTAssertEqual(APIError.serverError(503), APIError.serverError(503))
        XCTAssertNotEqual(APIError.serverError(500), APIError.serverError(503))
    }

    // MARK: - LoadState

    func testLoadStateIsLoadingTrue() {
        let state: LoadState<String> = .loading
        XCTAssertTrue(state.isLoading)
    }

    func testLoadStateIsLoadingFalse() {
        let state: LoadState<String> = .loaded("hello")
        XCTAssertFalse(state.isLoading)
    }

    func testLoadStateValue() {
        let state: LoadState<Int> = .loaded(42)
        XCTAssertEqual(state.value, 42)
    }

    func testLoadStateValueNilWhenNotLoaded() {
        let state: LoadState<Int> = .loading
        XCTAssertNil(state.value)
    }

    func testLoadStateError() {
        let state: LoadState<Int> = .error(.forbidden)
        XCTAssertEqual(state.error, .forbidden)
    }

    func testLoadStateErrorNilWhenLoaded() {
        let state: LoadState<Int> = .loaded(1)
        XCTAssertNil(state.error)
    }

    // MARK: - PaginatedResponse

    func testPaginatedResponseDecoding() throws {
        let json = """
        {
            "items": [1, 2, 3],
            "total": 100,
            "offset": 0,
            "limit": 3
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertEqual(response.items, [1, 2, 3])
        XCTAssertEqual(response.total, 100)
        XCTAssertEqual(response.offset, 0)
        XCTAssertEqual(response.limit, 3)
    }

    func testPaginatedResponseHasMore() throws {
        let json = """
        {"items": [], "total": 50, "offset": 0, "limit": 100}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertFalse(response.hasMore)
    }

    func testPaginatedResponseHasMoreTrue() throws {
        let json = """
        {"items": [], "total": 150, "offset": 0, "limit": 100}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertTrue(response.hasMore)
    }
}
```

- [ ] **Step 2: Run tests — expect build failure (types don't exist yet)**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/FoundationTypesTests \
  2>&1 | grep -E "(error:|FAILED|passed|failed)"
```

Expected: Build error — `APIError`, `LoadState`, `PaginatedResponse` not found.

- [ ] **Step 3: Create `APIError.swift`**

Create `ArubaCentral/Core/API/APIError.swift`:

```swift
import Foundation

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case rateLimited
    case serverError(Int)
    case networkError
    case decodingError
    case sessionExpired

    var userMessage: String {
        switch self {
        case .unauthorized, .sessionExpired:
            return "Session expired — please re-authenticate in Settings."
        case .forbidden:
            return "Your account doesn't have permission to view this."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError:
            return "No network connection."
        case .decodingError:
            return "Unexpected response format."
        }
    }
}
```

- [ ] **Step 4: Create `LoadState.swift`**

Create `ArubaCentral/Core/API/LoadState.swift`:

```swift
enum LoadState<T> {
    case idle
    case loading
    case loaded(T)
    case error(APIError)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var error: APIError? {
        if case .error(let e) = self { return e }
        return nil
    }
}
```

- [ ] **Step 5: Create `PaginatedResponse.swift`**

Create `ArubaCentral/Core/API/PaginatedResponse.swift`:

```swift
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let offset: Int
    let limit: Int

    var hasMore: Bool { total > offset + items.count }
}
```

- [ ] **Step 6: Add new files to Xcode target**

In Xcode: File → Add Files to "ArubaCentral", select `Core/API/APIError.swift`, `Core/API/LoadState.swift`, `Core/API/PaginatedResponse.swift`. Ensure target membership is `ArubaCentral`. Add test file to `ArubaCentralTests`.

- [ ] **Step 7: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/FoundationTypesTests \
  2>&1 | grep -E "(error:|Test.*passed|Test.*failed|FAILED)"
```

Expected: `Test Suite 'FoundationTypesTests' passed`

- [ ] **Step 8: Commit**

```bash
cd /Users/joshuaebibbs/XcodeProj/ArubaCentral
git add ArubaCentral/Core/API/APIError.swift \
        ArubaCentral/Core/API/LoadState.swift \
        ArubaCentral/Core/API/PaginatedResponse.swift \
        ArubaCentralTests/Core/API/FoundationTypesTests.swift
git commit -m "feat: add foundation types — APIError, LoadState, PaginatedResponse"
```

---

### Task 2: Models — Site, AccessPoint, CentralSwitch, CentralClient, CentralAlert

**Files:**
- Create: `ArubaCentral/Core/Models/HealthLevel.swift`
- Create: `ArubaCentral/Core/Models/DeviceStatus.swift`
- Create: `ArubaCentral/Core/Models/Site.swift`
- Create: `ArubaCentral/Core/Models/AccessPoint.swift`
- Create: `ArubaCentral/Core/Models/Radio.swift`
- Create: `ArubaCentral/Core/Models/CentralSwitch.swift`
- Create: `ArubaCentral/Core/Models/SwitchInterface.swift`
- Create: `ArubaCentral/Core/Models/VLAN.swift`
- Create: `ArubaCentral/Core/Models/CentralClient.swift`
- Create: `ArubaCentral/Core/Models/CentralAlert.swift`
- Test: `ArubaCentralTests/Core/Models/ModelDecodingTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: all model types used by `CentralAPIClient` responses and every ViewModel

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Core/Models/ModelDecodingTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - Site

    func testSiteDecoding() throws {
        let json = """
        {
            "site_id": "abc123",
            "site_name": "HQ Campus",
            "health_score": 92,
            "ap_count": 24,
            "switch_count": 4,
            "client_count": 310
        }
        """.data(using: .utf8)!
        let site = try decoder.decode(Site.self, from: json)
        XCTAssertEqual(site.id, "abc123")
        XCTAssertEqual(site.name, "HQ Campus")
        XCTAssertEqual(site.healthScore, 92)
        XCTAssertEqual(site.apCount, 24)
        XCTAssertEqual(site.switchCount, 4)
        XCTAssertEqual(site.clientCount, 310)
    }

    func testSiteHealthLevelGood() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 85))
        XCTAssertEqual(site.healthLevel, .good)
    }

    func testSiteHealthLevelWarning() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 65))
        XCTAssertEqual(site.healthLevel, .warning)
    }

    func testSiteHealthLevelCritical() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 30))
        XCTAssertEqual(site.healthLevel, .critical)
    }

    // MARK: - AccessPoint

    func testAccessPointDecoding() throws {
        let json = """
        {
            "serial": "SN001",
            "name": "AP-Lobby",
            "model": "AP-635",
            "status": "Up",
            "ip_address": "10.0.1.5",
            "mac_address": "aa:bb:cc:dd:ee:ff",
            "firmware": "10.4.0.0",
            "uptime": 86400,
            "site_name": "HQ Campus",
            "client_count": 12
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertEqual(ap.serial, "SN001")
        XCTAssertEqual(ap.name, "AP-Lobby")
        XCTAssertEqual(ap.status, .up)
        XCTAssertEqual(ap.id, "SN001")
        XCTAssertEqual(ap.clientCount, 12)
    }

    func testAccessPointOptionalFieldsMissing() throws {
        let json = """
        {
            "serial": "SN002",
            "name": "AP-Down",
            "model": "AP-515",
            "status": "Down"
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertNil(ap.ipAddress)
        XCTAssertNil(ap.clientCount)
        XCTAssertEqual(ap.status, .down)
    }

    // MARK: - CentralSwitch

    func testSwitchDecoding() throws {
        let json = """
        {
            "serial": "SW001",
            "name": "Core-Switch-1",
            "model": "6300M",
            "status": "Up",
            "ip_address": "10.0.0.1",
            "mac_address": "11:22:33:44:55:66",
            "firmware": "10.13.1010",
            "uptime": 604800,
            "site_name": "HQ Campus"
        }
        """.data(using: .utf8)!
        let sw = try decoder.decode(CentralSwitch.self, from: json)
        XCTAssertEqual(sw.serial, "SW001")
        XCTAssertEqual(sw.id, "SW001")
        XCTAssertEqual(sw.status, .up)
    }

    // MARK: - CentralClient

    func testWirelessClientDecoding() throws {
        let json = """
        {
            "mac_address": "aa:11:bb:22:cc:33",
            "name": "MacBook-Josh",
            "ip_address": "10.0.1.100",
            "client_type": "WIRELESS",
            "associated_device": "SN001",
            "site_name": "HQ Campus",
            "ssid": "Corp-WiFi",
            "signal_strength": -65,
            "connected_at": 1751000000
        }
        """.data(using: .utf8)!
        let client = try decoder.decode(CentralClient.self, from: json)
        XCTAssertEqual(client.macAddress, "aa:11:bb:22:cc:33")
        XCTAssertEqual(client.connectionType, .wireless)
        XCTAssertEqual(client.ssid, "Corp-WiFi")
        XCTAssertEqual(client.signalStrength, -65)
        XCTAssertNotNil(client.connectedAt)
    }

    func testWiredClientDecoding() throws {
        let json = """
        {
            "mac_address": "dd:44:ee:55:ff:66",
            "name": "Printer-Floor2",
            "ip_address": "10.0.2.50",
            "client_type": "WIRED",
            "associated_device": "SW001",
            "site_name": "HQ Campus",
            "vlan": 20,
            "port": "1/1/4",
            "connected_at": 1751000000
        }
        """.data(using: .utf8)!
        let client = try decoder.decode(CentralClient.self, from: json)
        XCTAssertEqual(client.connectionType, .wired)
        XCTAssertEqual(client.vlan, 20)
        XCTAssertEqual(client.port, "1/1/4")
        XCTAssertNil(client.ssid)
    }

    // MARK: - CentralAlert

    func testAlertDecoding() throws {
        let json = """
        {
            "alert_id": "ALT001",
            "alert_name": "AP Down",
            "severity": "Critical",
            "alert_description": "AP-Lobby is unreachable",
            "device_serial": "SN001",
            "site_name": "HQ Campus",
            "created_at": 1751000000,
            "is_cleared": false
        }
        """.data(using: .utf8)!
        let alert = try decoder.decode(CentralAlert.self, from: json)
        XCTAssertEqual(alert.id, "ALT001")
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertFalse(alert.isCleared)
    }

    func testAlertSeverityOrdering() {
        XCTAssertLessThan(AlertSeverity.critical, AlertSeverity.major)
        XCTAssertLessThan(AlertSeverity.major, AlertSeverity.minor)
        XCTAssertLessThan(AlertSeverity.minor, AlertSeverity.info)
    }

    // MARK: - Radio

    func testRadioDecoding() throws {
        let json = """
        {
            "radio_index": 0,
            "band": "5GHz",
            "channel": 36,
            "ssid": "Corp-WiFi",
            "client_count": 8,
            "throughput": 245.5
        }
        """.data(using: .utf8)!
        let radio = try decoder.decode(Radio.self, from: json)
        XCTAssertEqual(radio.band, "5GHz")
        XCTAssertEqual(radio.channel, 36)
        XCTAssertEqual(radio.clientCount, 8)
    }

    // MARK: - SwitchInterface

    func testSwitchInterfaceDecoding() throws {
        let json = """
        {
            "port_id": "1/1/1",
            "port_status": "Up",
            "speed": "1G",
            "vlan": 10,
            "connected_device": "MacBook-Josh",
            "tx_bytes": 1000000,
            "rx_bytes": 500000
        }
        """.data(using: .utf8)!
        let iface = try decoder.decode(SwitchInterface.self, from: json)
        XCTAssertEqual(iface.portId, "1/1/1")
        XCTAssertEqual(iface.status, .up)
        XCTAssertEqual(iface.speed, "1G")
    }

    // MARK: - VLAN

    func testVLANDecoding() throws {
        let json = """
        {
            "vlan_id": 10,
            "vlan_name": "Corp",
            "tagged_ports": ["1/1/1", "1/1/2"],
            "untagged_ports": ["1/1/3"]
        }
        """.data(using: .utf8)!
        let vlan = try decoder.decode(VLAN.self, from: json)
        XCTAssertEqual(vlan.vlanId, 10)
        XCTAssertEqual(vlan.name, "Corp")
        XCTAssertEqual(vlan.taggedPorts.count, 2)
    }

    // MARK: - Helpers

    private func siteJSON(score: Int) -> Data {
        """
        {
            "site_id": "s1",
            "site_name": "Test",
            "health_score": \(score),
            "ap_count": 1,
            "switch_count": 1,
            "client_count": 1
        }
        """.data(using: .utf8)!
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/ModelDecodingTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build errors — model types not found.

- [ ] **Step 3: Create shared enums**

Create `ArubaCentral/Core/Models/HealthLevel.swift`:

```swift
enum HealthLevel: Equatable {
    case good       // health_score 80-100
    case warning    // health_score 50-79
    case critical   // health_score 0-49
}
```

Create `ArubaCentral/Core/Models/DeviceStatus.swift`:

```swift
enum DeviceStatus: String, Codable, Equatable {
    case up = "Up"
    case down = "Down"
    case unknown = "Unknown"
}
```

Create `ArubaCentral/Core/Models/PortStatus.swift`:

```swift
enum PortStatus: String, Codable, Equatable {
    case up = "Up"
    case down = "Down"
    case disabled = "Disabled"
}
```

Create `ArubaCentral/Core/Models/AlertSeverity.swift`:

```swift
enum AlertSeverity: String, Codable, Comparable, Equatable {
    case critical = "Critical"
    case major = "Major"
    case minor = "Minor"
    case info = "Info"

    private var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .major:    return 1
        case .minor:    return 2
        case .info:     return 3
        }
    }

    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
```

Create `ArubaCentral/Core/Models/ClientConnectionType.swift`:

```swift
enum ClientConnectionType: String, Codable, Equatable {
    case wireless = "WIRELESS"
    case wired = "WIRED"
}
```

- [ ] **Step 4: Create model structs**

Create `ArubaCentral/Core/Models/Site.swift`:

```swift
import Foundation

struct Site: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let healthScore: Int
    let apCount: Int
    let switchCount: Int
    let clientCount: Int

    var healthLevel: HealthLevel {
        switch healthScore {
        case 80...100: return .good
        case 50...79:  return .warning
        default:       return .critical
        }
    }

    enum CodingKeys: String, CodingKey {
        case id           = "site_id"
        case name         = "site_name"
        case healthScore  = "health_score"
        case apCount      = "ap_count"
        case switchCount  = "switch_count"
        case clientCount  = "client_count"
    }
}
```

Create `ArubaCentral/Core/Models/AccessPoint.swift`:

```swift
import Foundation

struct AccessPoint: Codable, Identifiable, Equatable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String?
    let firmware: String?
    let uptime: Int?
    let site: String?
    let clientCount: Int?

    var id: String { serial }

    enum CodingKeys: String, CodingKey {
        case serial
        case name
        case model
        case status
        case ipAddress   = "ip_address"
        case macAddress  = "mac_address"
        case firmware
        case uptime
        case site        = "site_name"
        case clientCount = "client_count"
    }
}
```

Create `ArubaCentral/Core/Models/Radio.swift`:

```swift
struct Radio: Codable, Identifiable, Equatable {
    let index: Int
    let band: String
    let channel: Int?
    let ssid: String?
    let clientCount: Int
    let throughput: Double?

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index       = "radio_index"
        case band
        case channel
        case ssid
        case clientCount = "client_count"
        case throughput
    }
}
```

Create `ArubaCentral/Core/Models/CentralSwitch.swift`:

```swift
import Foundation

// Named CentralSwitch to avoid collision with Swift's switch keyword
struct CentralSwitch: Codable, Identifiable, Equatable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String?
    let firmware: String?
    let uptime: Int?
    let site: String?
    let stackId: String?

    var id: String { serial }

    enum CodingKeys: String, CodingKey {
        case serial
        case name
        case model
        case status
        case ipAddress  = "ip_address"
        case macAddress = "mac_address"
        case firmware
        case uptime
        case site       = "site_name"
        case stackId    = "stack_id"
    }
}
```

Create `ArubaCentral/Core/Models/SwitchInterface.swift`:

```swift
struct SwitchInterface: Codable, Identifiable, Equatable {
    let portId: String
    let status: PortStatus
    let speed: String?
    let vlan: Int?
    let connectedDevice: String?
    let txBytes: Int?
    let rxBytes: Int?

    var id: String { portId }

    enum CodingKeys: String, CodingKey {
        case portId          = "port_id"
        case status          = "port_status"
        case speed
        case vlan
        case connectedDevice = "connected_device"
        case txBytes         = "tx_bytes"
        case rxBytes         = "rx_bytes"
    }
}
```

Create `ArubaCentral/Core/Models/VLAN.swift`:

```swift
struct VLAN: Codable, Identifiable, Equatable {
    let vlanId: Int
    let name: String?
    let taggedPorts: [String]
    let untaggedPorts: [String]

    var id: Int { vlanId }

    enum CodingKeys: String, CodingKey {
        case vlanId        = "vlan_id"
        case name          = "vlan_name"
        case taggedPorts   = "tagged_ports"
        case untaggedPorts = "untagged_ports"
    }
}
```

Create `ArubaCentral/Core/Models/CentralClient.swift`:

```swift
import Foundation

struct CentralClient: Codable, Identifiable, Equatable {
    let macAddress: String
    let name: String?
    let ipAddress: String?
    let connectionType: ClientConnectionType
    let associatedDeviceSerial: String?
    let site: String?
    let ssid: String?
    let vlan: Int?
    let port: String?
    let signalStrength: Int?
    let txDataRate: Double?
    let rxDataRate: Double?
    let connectedAt: Date?

    var id: String { macAddress }

    enum CodingKeys: String, CodingKey {
        case macAddress            = "mac_address"
        case name
        case ipAddress             = "ip_address"
        case connectionType        = "client_type"
        case associatedDeviceSerial = "associated_device"
        case site                  = "site_name"
        case ssid
        case vlan
        case port
        case signalStrength        = "signal_strength"
        case txDataRate            = "tx_data_rate"
        case rxDataRate            = "rx_data_rate"
        case connectedAt           = "connected_at"
    }
}
```

Create `ArubaCentral/Core/Models/CentralAlert.swift`:

```swift
import Foundation

struct CentralAlert: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let severity: AlertSeverity
    let description: String?
    let deviceSerial: String?
    let site: String?
    let timestamp: Date
    let isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case id          = "alert_id"
        case name        = "alert_name"
        case severity
        case description = "alert_description"
        case deviceSerial = "device_serial"
        case site        = "site_name"
        case timestamp   = "created_at"
        case isCleared   = "is_cleared"
    }
}
```

- [ ] **Step 5: Add all files to Xcode target**

In Xcode: Add all files under `ArubaCentral/Core/Models/` to the `ArubaCentral` target. Add the test file to `ArubaCentralTests`.

- [ ] **Step 6: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/ModelDecodingTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'ModelDecodingTests' passed`

- [ ] **Step 7: Commit**

```bash
git add ArubaCentral/Core/Models/ ArubaCentralTests/Core/Models/
git commit -m "feat: add Codable models — Site, AccessPoint, CentralSwitch, CentralClient, CentralAlert"
```

---

### Task 3: KeychainManager — Secure credential storage

**Files:**
- Create: `ArubaCentral/Core/Keychain/KeychainManager.swift`
- Test: `ArubaCentralTests/Core/Keychain/KeychainManagerTests.swift`

**Interfaces:**
- Produces: `KeychainManager` (used by `AuthTokenManager` and `SettingsViewModel`), `KeychainError`

---

- [ ] **Step 1: Create the test file**

Create `ArubaCentralTests/Core/Keychain/KeychainManagerTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

final class KeychainManagerTests: XCTestCase {

    var sut: KeychainManager!

    override func setUp() {
        super.setUp()
        sut = KeychainManager()
        // Clean up any leftover test data
        KeychainManager.Key.allCases.forEach { sut.delete(for: $0) }
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { sut.delete(for: $0) }
        sut = nil
        super.tearDown()
    }

    func testSaveAndRetrieveClientId() throws {
        try sut.save("my-client-id", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "my-client-id")
    }

    func testSaveAndRetrieveClientSecret() throws {
        try sut.save("super-secret-value", for: .clientSecret)
        let retrieved = try sut.retrieve(for: .clientSecret)
        XCTAssertEqual(retrieved, "super-secret-value")
    }

    func testOverwriteExistingValue() throws {
        try sut.save("first-value", for: .clientId)
        try sut.save("second-value", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "second-value")
    }

    func testRetrieveNonExistentKeyThrows() {
        XCTAssertThrowsError(try sut.retrieve(for: .accessToken)) { error in
            XCTAssertEqual(error as? KeychainError, .notFound)
        }
    }

    func testDeleteRemovesValue() throws {
        try sut.save("to-be-deleted", for: .clientId)
        sut.delete(for: .clientId)
        XCTAssertThrowsError(try sut.retrieve(for: .clientId))
    }

    func testDeleteNonExistentKeyDoesNotThrow() {
        // Should not crash or throw
        sut.delete(for: .tokenExpiry)
    }

    func testSaveEmptyString() throws {
        try sut.save("", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "")
    }

    func testSaveSpecialCharacters() throws {
        let special = "abc!@#$%^&*()_+-=[]{}|;':\",./<>?"
        try sut.save(special, for: .clientSecret)
        let retrieved = try sut.retrieve(for: .clientSecret)
        XCTAssertEqual(retrieved, special)
    }

    func testAllKeysIndependent() throws {
        try sut.save("id-value", for: .clientId)
        try sut.save("secret-value", for: .clientSecret)
        try sut.save("token-value", for: .accessToken)
        try sut.save("12345.678", for: .tokenExpiry)

        XCTAssertEqual(try sut.retrieve(for: .clientId), "id-value")
        XCTAssertEqual(try sut.retrieve(for: .clientSecret), "secret-value")
        XCTAssertEqual(try sut.retrieve(for: .accessToken), "token-value")
        XCTAssertEqual(try sut.retrieve(for: .tokenExpiry), "12345.678")
    }
}
```

- [ ] **Step 2: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/KeychainManagerTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `KeychainManager` not found.

- [ ] **Step 3: Create `KeychainManager.swift`**

Create `ArubaCentral/Core/Keychain/KeychainManager.swift`:

```swift
import Foundation
import Security

struct KeychainManager {
    private let service = "com.aruba.central"

    enum Key: String, CaseIterable {
        case clientId     = "client_id"
        case clientSecret = "client_secret"
        case accessToken  = "access_token"
        case tokenExpiry  = "token_expiry"
    }

    func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecValueData:   data
        ]
        // Delete existing item first to allow overwrite
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(for key: Key) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return string
    }

    func delete(for key: Key) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case notFound
}
```

- [ ] **Step 4: Add to Xcode target**

Add `ArubaCentral/Core/Keychain/KeychainManager.swift` to the `ArubaCentral` target and the test file to `ArubaCentralTests`.

- [ ] **Step 5: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/KeychainManagerTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'KeychainManagerTests' passed`

- [ ] **Step 6: Run all Phase 1 tests together**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/FoundationTypesTests \
  -only-testing:ArubaCentralTests/ModelDecodingTests \
  -only-testing:ArubaCentralTests/KeychainManagerTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All three suites pass.

- [ ] **Step 7: Commit**

```bash
git add ArubaCentral/Core/Keychain/KeychainManager.swift \
        ArubaCentralTests/Core/Keychain/KeychainManagerTests.swift
git commit -m "feat: add KeychainManager for secure credential storage"
```

---

## Phase 1 Complete

All three tasks done. The codebase now has:
- `APIError`, `LoadState<T>`, `PaginatedResponse<T>` — shared throughout the app
- All 10 model types — `Site`, `AccessPoint`, `Radio`, `CentralSwitch`, `SwitchInterface`, `VLAN`, `CentralClient`, `CentralAlert`, and supporting enums — all `Codable`, `Identifiable`, `Equatable`, tested with realistic JSON
- `KeychainManager` — secure Keychain read/write for credentials and token

**Next:** Phase 2 — Networking (`AuthTokenManager` + `CentralAPIClient`)
