# Aruba Central iOS App — Phase 2: Networking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `AuthTokenManager` (OAuth 2.0 token lifecycle) and `CentralAPIClient` (all 18 New Central API calls) — the complete networking layer the entire app depends on.

**Architecture:** `AuthTokenManager` is a class injected into `CentralAPIClient`. Both are tested via `URLProtocol` stubbing — no real network calls in tests. A `MockCentralAPIClient` conforming to `CentralAPIClientProtocol` is produced here for use by all ViewModel tests in later phases.

**Tech Stack:** Swift 5.9, URLSession async/await, XCTest, URLProtocol stubbing

## Global Constraints

- Deployment target: iOS 16.0+
- No third-party networking libraries — URLSession only
- Token endpoint: `https://sso.common.cloud.hpe.com/as/token.oauth2`
- Token lifetime: 7199 seconds (Central credentials); refresh buffer: 60 seconds
- On 401: refresh token once, retry original request; if second attempt also fails, throw `.sessionExpired`
- Rate limit: 10 req/s — callers are responsible for not exceeding this; client does not implement global throttling
- All POST action endpoints send `application/json` body; all GET endpoints use URL query parameters
- Prerequisite: Phase 1 complete (`APIError`, `LoadState`, `PaginatedResponse`, all models, `KeychainManager`)

---

### Task 4: AuthTokenManager — OAuth token lifecycle

**Files:**
- Create: `ArubaCentral/Core/API/AuthTokenManager.swift`
- Create: `ArubaCentralTests/Helpers/MockURLProtocol.swift`
- Test: `ArubaCentralTests/Core/API/AuthTokenManagerTests.swift`

**Interfaces:**
- Consumes: `KeychainManager`, `APIError`
- Produces: `AuthTokenManager` — used by `CentralAPIClient` to obtain a valid Bearer token before every request

---

- [ ] **Step 1: Create MockURLProtocol helper**

Create `ArubaCentralTests/Helpers/MockURLProtocol.swift`:

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func respondWith(statusCode: Int, json: String) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    static func respondWith(statusCode: Int, data: Data = Data()) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: [:]
            )!
            return (response, data)
        }
    }
}
```

- [ ] **Step 2: Create AuthTokenManager test file**

Create `ArubaCentralTests/Core/API/AuthTokenManagerTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class AuthTokenManagerTests: XCTestCase {

    var sut: AuthTokenManager!
    var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        sut = AuthTokenManager(session: MockURLProtocol.makeSession())
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        MockURLProtocol.requestHandler = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - fetchNewToken

    func testFetchNewTokenSuccess() async throws {
        try keychain.save("test-client-id", for: .clientId)
        try keychain.save("test-client-secret", for: .clientSecret)

        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "tok123", "token_type": "Bearer", "expires_in": 7199}
        """)

        let token = try await sut.fetchNewToken()
        XCTAssertEqual(token, "tok123")
    }

    func testFetchNewTokenStoresInKeychain() async throws {
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)

        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "stored-token", "token_type": "Bearer", "expires_in": 7199}
        """)

        _ = try await sut.fetchNewToken()
        let stored = try keychain.retrieve(for: .accessToken)
        XCTAssertEqual(stored, "stored-token")
    }

    func testFetchNewTokenStoresExpiry() async throws {
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)

        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "tok", "token_type": "Bearer", "expires_in": 7199}
        """)

        let before = Date().timeIntervalSince1970
        _ = try await sut.fetchNewToken()
        let expiry = Double(try keychain.retrieve(for: .tokenExpiry))!
        XCTAssertGreaterThan(expiry, before + 7100)
        XCTAssertLessThan(expiry, before + 7300)
    }

    func testFetchNewTokenThrowsOnMissingCredentials() async {
        do {
            _ = try await sut.fetchNewToken()
            XCTFail("Expected throw")
        } catch {
            // KeychainError.notFound — credentials not set
            XCTAssertTrue(error is KeychainError)
        }
    }

    func testFetchNewTokenThrowsUnauthorizedOn401() async throws {
        try keychain.save("bad-id", for: .clientId)
        try keychain.save("bad-secret", for: .clientSecret)
        MockURLProtocol.respondWith(statusCode: 401)

        do {
            _ = try await sut.fetchNewToken()
            XCTFail("Expected throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: - validToken (cache hit)

    func testValidTokenReturnsCachedTokenWhenFresh() async throws {
        try keychain.save("cached-token", for: .accessToken)
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        try keychain.save(String(futureExpiry), for: .tokenExpiry)

        // No MockURLProtocol handler set — would crash if network is called
        MockURLProtocol.requestHandler = { _ in
            XCTFail("Network should not be called for a valid cached token")
            throw URLError(.badURL)
        }

        let token = try await sut.validToken()
        XCTAssertEqual(token, "cached-token")
    }

    func testValidTokenRefreshesWhenExpired() async throws {
        try keychain.save("old-token", for: .accessToken)
        let pastExpiry = Date().timeIntervalSince1970 - 100
        try keychain.save(String(pastExpiry), for: .tokenExpiry)
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)

        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "new-token", "token_type": "Bearer", "expires_in": 7199}
        """)

        let token = try await sut.validToken()
        XCTAssertEqual(token, "new-token")
    }

    func testValidTokenRefreshesWhenWithin60SecondBuffer() async throws {
        try keychain.save("expiring-soon", for: .accessToken)
        let nearExpiry = Date().timeIntervalSince1970 + 30  // within 60s buffer
        try keychain.save(String(nearExpiry), for: .tokenExpiry)
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)

        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "refreshed-token", "token_type": "Bearer", "expires_in": 7199}
        """)

        let token = try await sut.validToken()
        XCTAssertEqual(token, "refreshed-token")
    }

    // MARK: - clearCredentials

    func testClearCredentialsRemovesAllKeys() throws {
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)
        try keychain.save("token", for: .accessToken)
        try keychain.save("12345", for: .tokenExpiry)

        sut.clearCredentials()

        for key in KeychainManager.Key.allCases {
            XCTAssertThrowsError(try keychain.retrieve(for: key), "Key \(key.rawValue) should be cleared")
        }
    }

    func testClearCredentialsSetsIsAuthenticatedFalse() async throws {
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)
        MockURLProtocol.respondWith(statusCode: 200, json: """
        {"access_token": "t", "token_type": "Bearer", "expires_in": 7199}
        """)
        _ = try await sut.fetchNewToken()

        sut.clearCredentials()
        XCTAssertFalse(sut.isAuthenticated)
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
  -only-testing:ArubaCentralTests/AuthTokenManagerTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `AuthTokenManager` not found.

- [ ] **Step 4: Create `AuthTokenManager.swift`**

Create `ArubaCentral/Core/API/AuthTokenManager.swift`:

```swift
import Foundation
import Combine

@MainActor
final class AuthTokenManager: ObservableObject {
    private let keychain = KeychainManager()
    private let tokenURL = URL(string: "https://sso.common.cloud.hpe.com/as/token.oauth2")!
    private let session: URLSession
    private let refreshBuffer: TimeInterval = 60

    @Published private(set) var isAuthenticated = false

    init(session: URLSession = .shared) {
        self.session = session
        isAuthenticated = (try? keychain.retrieve(for: .accessToken)) != nil
    }

    func validToken() async throws -> String {
        if let token = try? keychain.retrieve(for: .accessToken),
           let expiryString = try? keychain.retrieve(for: .tokenExpiry),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry - refreshBuffer {
            return token
        }
        return try await fetchNewToken()
    }

    @discardableResult
    func fetchNewToken() async throws -> String {
        let clientId     = try keychain.retrieve(for: .clientId)
        let clientSecret = try keychain.retrieve(for: .clientSecret)

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        guard http.statusCode == 200 else { throw APIError.unauthorized }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiry = Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn)

        try keychain.save(tokenResponse.accessToken, for: .accessToken)
        try keychain.save(String(expiry), for: .tokenExpiry)

        isAuthenticated = true
        return tokenResponse.accessToken
    }

    func clearCredentials() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        isAuthenticated = false
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
    }
}
```

- [ ] **Step 5: Add files to Xcode targets**

Add `AuthTokenManager.swift` to the `ArubaCentral` target. Add `MockURLProtocol.swift` and the test file to `ArubaCentralTests`.

- [ ] **Step 6: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/AuthTokenManagerTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'AuthTokenManagerTests' passed`

- [ ] **Step 7: Commit**

```bash
git add ArubaCentral/Core/API/AuthTokenManager.swift \
        ArubaCentralTests/Helpers/MockURLProtocol.swift \
        ArubaCentralTests/Core/API/AuthTokenManagerTests.swift
git commit -m "feat: add AuthTokenManager — OAuth token lifecycle with Keychain caching"
```

---

### Task 5: CentralAPIClient — Protocol + Implementation + Mock

**Files:**
- Create: `ArubaCentral/Core/API/CentralAPIClientProtocol.swift`
- Create: `ArubaCentral/Core/API/CentralAPIClient.swift`
- Create: `ArubaCentral/Core/API/CentralRegion.swift`
- Create: `ArubaCentralTests/Helpers/MockCentralAPIClient.swift`
- Test: `ArubaCentralTests/Core/API/CentralAPIClientTests.swift`

**Interfaces:**
- Consumes: `AuthTokenManager`, `APIError`, all models, `PaginatedResponse<T>`
- Produces: `CentralAPIClientProtocol` (consumed by every ViewModel), `CentralAPIClient` (injected at app root), `CentralRegion` (used by Settings), `MockCentralAPIClient` (used by all ViewModel tests in Phases 4–8)

---

- [ ] **Step 1: Create `CentralRegion.swift`**

Create `ArubaCentral/Core/API/CentralRegion.swift`:

```swift
import Foundation

struct CentralRegion: Identifiable, Hashable {
    let id: String
    let label: String
    let baseURL: URL

    static let all: [CentralRegion] = [
        .init(id: "us1", label: "US-1",        baseURL: URL(string: "https://us1.api.central.arubanetworks.com")!),
        .init(id: "us2", label: "US-2",        baseURL: URL(string: "https://us2.api.central.arubanetworks.com")!),
        .init(id: "us4", label: "US-West-4",   baseURL: URL(string: "https://us4.api.central.arubanetworks.com")!),
        .init(id: "us5", label: "US-West-5",   baseURL: URL(string: "https://us5.api.central.arubanetworks.com")!),
        .init(id: "us6", label: "US-East-1",   baseURL: URL(string: "https://us6.api.central.arubanetworks.com")!),
        .init(id: "ca1", label: "Canada-1",    baseURL: URL(string: "https://ca1.api.central.arubanetworks.com")!),
        .init(id: "de1", label: "EU-1",        baseURL: URL(string: "https://de1.api.central.arubanetworks.com")!),
        .init(id: "de2", label: "EU-Central-2",baseURL: URL(string: "https://de2.api.central.arubanetworks.com")!),
        .init(id: "de3", label: "EU-Central-3",baseURL: URL(string: "https://de3.api.central.arubanetworks.com")!),
        .init(id: "gb1", label: "UK",          baseURL: URL(string: "https://gb1.api.central.arubanetworks.com")!),
        .init(id: "in1", label: "APAC-1",      baseURL: URL(string: "https://in1.api.central.arubanetworks.com")!),
        .init(id: "jp1", label: "APAC-East-1", baseURL: URL(string: "https://jp1.api.central.arubanetworks.com")!),
        .init(id: "au1", label: "APAC-South-1",baseURL: URL(string: "https://au1.api.central.arubanetworks.com")!),
        .init(id: "ae1", label: "UAE",         baseURL: URL(string: "https://ae1.api.central.arubanetworks.com")!),
    ]

    static let defaultRegion = all[0]
}
```

- [ ] **Step 2: Create `CentralAPIClientProtocol.swift`**

Create `ArubaCentral/Core/API/CentralAPIClientProtocol.swift`:

```swift
import Foundation

protocol CentralAPIClientProtocol: AnyObject {
    // Sites
    func fetchSiteHealth() async throws -> [Site]

    // APs
    func fetchAPs(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint>
    func fetchAPDetail(serial: String) async throws -> AccessPoint
    func fetchAPRadios(serial: String) async throws -> [Radio]
    func fetchAPClients(serial: String, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient>

    // Switches
    func fetchSwitches(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralSwitch>
    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch
    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface]
    func fetchSwitchVLANs(serial: String) async throws -> [VLAN]

    // Clients
    func fetchClients(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient>
    func fetchClientDetail(macAddress: String) async throws -> CentralClient

    // Alerts
    func fetchAlerts(limit: Int, offset: Int) async throws -> PaginatedResponse<CentralAlert>
    func clearAlert(alertId: String) async throws

    // Actions
    func rebootAP(serial: String) async throws
    func blinkAPLED(serial: String) async throws
    func disconnectAllClientsFromAP(serial: String) async throws

    // Settings
    func testConnection() async throws
}
```

- [ ] **Step 3: Create `CentralAPIClient.swift`**

Create `ArubaCentral/Core/API/CentralAPIClient.swift`:

```swift
import Foundation

@MainActor
final class CentralAPIClient: ObservableObject, CentralAPIClientProtocol {
    private let authManager: AuthTokenManager
    private let session: URLSession
    private let decoder: JSONDecoder

    @Published var baseURL: URL

    init(authManager: AuthTokenManager,
         session: URLSession = .shared,
         baseURL: URL = CentralRegion.defaultRegion.baseURL) {
        self.authManager = authManager
        self.session = session
        self.baseURL = baseURL
        self.decoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .secondsSince1970
            return d
        }()
    }

    // MARK: - Private helpers

    private func buildRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        let token = try await authManager.validToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }

            switch http.statusCode {
            case 200...299:
                do { return try decoder.decode(T.self, from: data) }
                catch { throw APIError.decodingError }
            case 401:
                return try await retryAfterRefresh(request)
            case 403: throw APIError.forbidden
            case 429: throw APIError.rateLimited
            default:  throw APIError.serverError(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError
        }
    }

    private func retryAfterRefresh<T: Decodable>(_ original: URLRequest) async throws -> T {
        try await authManager.fetchNewToken()
        let newToken = try await authManager.validToken()
        var retried = original
        retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: retried)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        guard (200...299).contains(http.statusCode) else { throw APIError.sessionExpired }

        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingError }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let _: EmptyResponse = try await perform(request)
    }

    private func postRequest(path: String, body: Encodable) async throws -> URLRequest {
        var request = try await buildRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Sites

    func fetchSiteHealth() async throws -> [Site] {
        let request = try await buildRequest(path: "/getsitehealthv1")
        return try await perform(request)
    }

    // MARK: - APs

    func fetchAPs(site: String? = nil, search: String? = nil,
                  limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<AccessPoint> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/accesspointsv1", queryItems: items)
        return try await perform(request)
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        let request = try await buildRequest(path: "/accesspointdetailsv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        let request = try await buildRequest(path: "/accesspointradiolistv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchAPClients(serial: String, limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralClient> {
        let request = try await buildRequest(path: "/listunifiedclients", queryItems: [
            .init(name: "associated_device", value: serial),
            .init(name: "limit",             value: "\(limit)"),
            .init(name: "offset",            value: "\(offset)")
        ])
        return try await perform(request)
    }

    // MARK: - Switches

    func fetchSwitches(site: String? = nil, search: String? = nil,
                       limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralSwitch> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/switchesv1", queryItems: items)
        return try await perform(request)
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        let request = try await buildRequest(path: "/switchv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        let request = try await buildRequest(path: "/listinterfacesv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        let request = try await buildRequest(path: "/listvlansv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    // MARK: - Clients

    func fetchClients(site: String? = nil, search: String? = nil,
                      limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralClient> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/listunifiedclients", queryItems: items)
        return try await perform(request)
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        let request = try await buildRequest(path: "/getclientdetails",
                                             queryItems: [.init(name: "mac_address", value: macAddress)])
        return try await perform(request)
    }

    // MARK: - Alerts

    func fetchAlerts(limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralAlert> {
        let request = try await buildRequest(path: "/getalertlistv1", queryItems: [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
        return try await perform(request)
    }

    func clearAlert(alertId: String) async throws {
        let request = try await postRequest(path: "/clearalerts",
                                            body: ["alert_id": alertId])
        try await performVoid(request)
    }

    // MARK: - Actions

    func rebootAP(serial: String) async throws {
        let request = try await postRequest(path: "/rebootapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    func blinkAPLED(serial: String) async throws {
        let request = try await postRequest(path: "/locateapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        let request = try await postRequest(path: "/disconnectallusersapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    // MARK: - Settings

    func testConnection() async throws {
        let _ = try await fetchSiteHealth()
    }
}

private struct EmptyResponse: Codable {}
```

- [ ] **Step 4: Create MockCentralAPIClient for ViewModel tests**

Create `ArubaCentralTests/Helpers/MockCentralAPIClient.swift`:

```swift
import Foundation
@testable import ArubaCentral

final class MockCentralAPIClient: CentralAPIClientProtocol {

    // MARK: - Configurable responses
    var sitesResult:         Result<[Site], APIError>                            = .success([])
    var apsResult:           Result<PaginatedResponse<AccessPoint>, APIError>    = .success(.empty())
    var apDetailResult:      Result<AccessPoint, APIError>                       = .failure(.networkError)
    var radiosResult:        Result<[Radio], APIError>                           = .success([])
    var apClientsResult:     Result<PaginatedResponse<CentralClient>, APIError>  = .success(.empty())
    var switchesResult:      Result<PaginatedResponse<CentralSwitch>, APIError>  = .success(.empty())
    var switchDetailResult:  Result<CentralSwitch, APIError>                     = .failure(.networkError)
    var interfacesResult:    Result<[SwitchInterface], APIError>                 = .success([])
    var vlansResult:         Result<[VLAN], APIError>                            = .success([])
    var clientsResult:       Result<PaginatedResponse<CentralClient>, APIError>  = .success(.empty())
    var clientDetailResult:  Result<CentralClient, APIError>                     = .failure(.networkError)
    var alertsResult:        Result<PaginatedResponse<CentralAlert>, APIError>   = .success(.empty())
    var clearAlertError:     APIError?                                           = nil
    var rebootError:         APIError?                                           = nil
    var blinkError:          APIError?                                           = nil
    var disconnectError:     APIError?                                           = nil
    var testConnectionError: APIError?                                           = nil

    // MARK: - Call tracking
    var fetchSitesCallCount      = 0
    var fetchAPsCallCount        = 0
    var rebootCallCount          = 0
    var blinkCallCount           = 0
    var clearAlertCallCount      = 0
    var disconnectCallCount      = 0
    var lastSearchQuery: String? = nil
    var lastSiteFilter: String?  = nil

    // MARK: - Protocol conformance

    func fetchSiteHealth() async throws -> [Site] {
        fetchSitesCallCount += 1
        return try sitesResult.get()
    }

    func fetchAPs(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint> {
        fetchAPsCallCount += 1
        lastSiteFilter  = site
        lastSearchQuery = search
        return try apsResult.get()
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        return try apDetailResult.get()
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        return try radiosResult.get()
    }

    func fetchAPClients(serial: String, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        return try apClientsResult.get()
    }

    func fetchSwitches(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralSwitch> {
        lastSiteFilter  = site
        lastSearchQuery = search
        return try switchesResult.get()
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        return try switchDetailResult.get()
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        return try interfacesResult.get()
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        return try vlansResult.get()
    }

    func fetchClients(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        lastSiteFilter  = site
        lastSearchQuery = search
        return try clientsResult.get()
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        return try clientDetailResult.get()
    }

    func fetchAlerts(limit: Int, offset: Int) async throws -> PaginatedResponse<CentralAlert> {
        return try alertsResult.get()
    }

    func clearAlert(alertId: String) async throws {
        clearAlertCallCount += 1
        if let error = clearAlertError { throw error }
    }

    func rebootAP(serial: String) async throws {
        rebootCallCount += 1
        if let error = rebootError { throw error }
    }

    func blinkAPLED(serial: String) async throws {
        blinkCallCount += 1
        if let error = blinkError { throw error }
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        disconnectCallCount += 1
        if let error = disconnectError { throw error }
    }

    func testConnection() async throws {
        if let error = testConnectionError { throw error }
    }
}

// MARK: - Convenience

extension PaginatedResponse {
    static func empty() -> PaginatedResponse<T> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }

    static func of(_ items: [T]) -> PaginatedResponse<T> {
        PaginatedResponse(items: items, total: items.count, offset: 0, limit: 100)
    }
}
```

- [ ] **Step 5: Create `CentralAPIClientTests.swift`**

Create `ArubaCentralTests/Core/API/CentralAPIClientTests.swift`:

```swift
import XCTest
@testable import ArubaCentral

@MainActor
final class CentralAPIClientTests: XCTestCase {

    var authManager: AuthTokenManager!
    var sut: CentralAPIClient!
    var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        try! keychain.save("test-id",     for: .clientId)
        try! keychain.save("test-secret", for: .clientSecret)
        try! keychain.save("valid-token", for: .accessToken)
        let expiry = Date().timeIntervalSince1970 + 3600
        try! keychain.save(String(expiry), for: .tokenExpiry)

        authManager = AuthTokenManager(session: MockURLProtocol.makeSession())
        sut = CentralAPIClient(
            authManager: authManager,
            session: MockURLProtocol.makeSession(),
            baseURL: URL(string: "https://us1.api.central.arubanetworks.com")!
        )
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        MockURLProtocol.requestHandler = nil
        sut = nil
        authManager = nil
        super.tearDown()
    }

    // MARK: - fetchSiteHealth

    func testFetchSiteHealthDecodesResponse() async throws {
        MockURLProtocol.respondWith(statusCode: 200, json: """
        [
          {
            "site_id": "s1", "site_name": "HQ",
            "health_score": 90, "ap_count": 10,
            "switch_count": 2, "client_count": 100
          }
        ]
        """)
        let sites = try await sut.fetchSiteHealth()
        XCTAssertEqual(sites.count, 1)
        XCTAssertEqual(sites[0].name, "HQ")
    }

    func testFetchSiteHealthThrowsForbiddenOn403() async {
        MockURLProtocol.respondWith(statusCode: 403)
        do {
            _ = try await sut.fetchSiteHealth()
            XCTFail("Expected throw")
        } catch let e as APIError {
            XCTAssertEqual(e, .forbidden)
        }
    }

    func testFetchSiteHealthThrowsServerErrorOn500() async {
        MockURLProtocol.respondWith(statusCode: 500)
        do {
            _ = try await sut.fetchSiteHealth()
            XCTFail("Expected throw")
        } catch let e as APIError {
            XCTAssertEqual(e, .serverError(500))
        }
    }

    func testFetchSiteHealthThrowsDecodingErrorOnBadJSON() async {
        MockURLProtocol.respondWith(statusCode: 200, json: "not-json")
        do {
            _ = try await sut.fetchSiteHealth()
            XCTFail("Expected throw")
        } catch let e as APIError {
            XCTAssertEqual(e, .decodingError)
        }
    }

    // MARK: - fetchAPs pagination

    func testFetchAPsIncludesLimitAndOffset() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let json = """
            {"items":[],"total":0,"offset":50,"limit":100}
            """
            return (response, Data(json.utf8))
        }

        _ = try await sut.fetchAPs(site: nil, search: nil, limit: 100, offset: 50)
        let urlString = capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("offset=50"))
        XCTAssertTrue(urlString.contains("limit=100"))
    }

    func testFetchAPsIncludesSiteFilter() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"items":[],"total":0,"offset":0,"limit":100}"#.utf8))
        }

        _ = try await sut.fetchAPs(site: "HQ Campus", search: nil, limit: 100, offset: 0)
        let urlString = capturedURL?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("site_name=HQ%20Campus") || urlString.contains("site_name=HQ+Campus"))
    }

    // MARK: - 401 retry

    func testFetchSiteHealthRetriesAfter401() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                // First call returns 401 to trigger token refresh
                let r = HTTPURLResponse(url: request.url!, statusCode: 401,
                                        httpVersion: nil, headerFields: nil)!
                return (r, Data())
            } else if callCount == 2 {
                // Token refresh call
                let r = HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"new-tok","token_type":"Bearer","expires_in":7199}"#
                return (r, Data(body.utf8))
            } else {
                // Retry of original request
                let r = HTTPURLResponse(url: request.url!, statusCode: 200,
                                        httpVersion: nil, headerFields: nil)!
                let body = #"[{"site_id":"s1","site_name":"HQ","health_score":90,"ap_count":1,"switch_count":1,"client_count":1}]"#
                return (r, Data(body.utf8))
            }
        }

        let sites = try await sut.fetchSiteHealth()
        XCTAssertEqual(sites.count, 1)
        XCTAssertGreaterThanOrEqual(callCount, 3)
    }

    // MARK: - CentralRegion

    func testCentralRegionAllContains14Regions() {
        XCTAssertEqual(CentralRegion.all.count, 14)
    }

    func testCentralRegionLabelsAreUnique() {
        let labels = CentralRegion.all.map(\.label)
        XCTAssertEqual(labels.count, Set(labels).count)
    }

    func testCentralRegionBaseURLsAreHTTPS() {
        for region in CentralRegion.all {
            XCTAssertEqual(region.baseURL.scheme, "https",
                           "\(region.label) should use HTTPS")
        }
    }

    func testCentralRegionDefaultIsUS1() {
        XCTAssertEqual(CentralRegion.defaultRegion.id, "us1")
    }
}
```

- [ ] **Step 6: Run — expect build failure**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/CentralAPIClientTests \
  2>&1 | grep -E "(error:|FAILED)"
```

Expected: Build error — `CentralAPIClient`, `CentralRegion` not found.

- [ ] **Step 7: Add all files to Xcode targets**

Add to `ArubaCentral` target:
- `ArubaCentral/Core/API/CentralRegion.swift`
- `ArubaCentral/Core/API/CentralAPIClientProtocol.swift`
- `ArubaCentral/Core/API/CentralAPIClient.swift`

Add to `ArubaCentralTests` target:
- `ArubaCentralTests/Helpers/MockCentralAPIClient.swift`
- `ArubaCentralTests/Core/API/CentralAPIClientTests.swift`

- [ ] **Step 8: Run tests — expect all pass**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/CentralAPIClientTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: `Test Suite 'CentralAPIClientTests' passed`

- [ ] **Step 9: Run all Phase 2 tests**

```bash
xcodebuild test \
  -project ArubaCentral.xcodeproj \
  -scheme ArubaCentral \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArubaCentralTests/AuthTokenManagerTests \
  -only-testing:ArubaCentralTests/CentralAPIClientTests \
  2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: Both suites pass.

- [ ] **Step 10: Commit**

```bash
git add \
  ArubaCentral/Core/API/CentralRegion.swift \
  ArubaCentral/Core/API/CentralAPIClientProtocol.swift \
  ArubaCentral/Core/API/CentralAPIClient.swift \
  ArubaCentralTests/Helpers/MockCentralAPIClient.swift \
  ArubaCentralTests/Core/API/CentralAPIClientTests.swift
git commit -m "feat: add CentralAPIClient — all 18 New Central API endpoints + mock for ViewModel tests"
```

---

## Phase 2 Complete

The full networking layer is in place:

- `AuthTokenManager` — OAuth fetch, 60-second proactive refresh, Keychain caching, 401 retry signaling
- `CentralRegion` — 14 pre-populated regional base URLs
- `CentralAPIClientProtocol` — the interface every ViewModel depends on (never the concrete class)
- `CentralAPIClient` — all 18 API calls with 401 retry, error mapping, paginated responses
- `MockCentralAPIClient` — drop-in test double with configurable `Result` responses and call tracking, ready for Phases 4–8

**Next:** Phase 3 — App Shell (`NetworkMonitor`, `TabView` root, shared UI components)
