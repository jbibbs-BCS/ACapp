import XCTest
@testable import ArubaCentral

/// Security regression tests for plan §2 (auth / session management).
/// Maps to docs/security/findings.md: A-7 (refresh stampede), A-8 (isAuthenticated semantics).
/// ASSESSMENT artifacts — they demonstrate current behavior; they do not fix it.
/// Written 2026-07-03.
@MainActor
final class AuthSecurityTests: XCTestCase {

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

    // MARK: - A-7 (FIXED) — concurrent refreshes coalesce into one token fetch

    func test_A7_concurrentRefreshCoalescesToSingleFetch() async throws {
        // Expired token + credentials => every validToken() call would refresh.
        try keychain.save("expired-token", for: .accessToken)
        try keychain.save(String(Date().timeIntervalSince1970 - 100), for: .tokenExpiry)
        try keychain.save("id", for: .clientId)
        try keychain.save("secret", for: .clientSecret)

        let hits = HitCounter()
        MockURLProtocol.requestHandler = { request in
            hits.inc()   // every request here is a token POST
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(#"{"access_token":"new","token_type":"Bearer","expires_in":7199}"#.utf8))
        }

        // Fire 10 concurrent refreshes; single-flight must collapse them to ONE fetch.
        let manager = sut!
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 { group.addTask { _ = try? await manager.validToken() } }
        }

        XCTAssertEqual(hits.value, 1,
            "10 concurrent refreshes coalesced into a single token fetch (A-7 fixed). Got \(hits.value).")
    }

    // MARK: - A-8 (FIXED) — isAuthenticated requires an unexpired token, not mere presence

    func test_A8_falseForTokenWithoutExpiry() {
        // A token string with no stored expiry must NOT count as authenticated.
        try! keychain.save("some-token", for: .accessToken)
        let fresh = AuthTokenManager(session: MockURLProtocol.makeSession())
        XCTAssertFalse(fresh.isAuthenticated,
            "Presence of a token string alone no longer implies authenticated (A-8 fixed).")
    }

    func test_A8_falseForExpiredToken() {
        try! keychain.save("some-token", for: .accessToken)
        try! keychain.save(String(Date().timeIntervalSince1970 - 100), for: .tokenExpiry)
        let fresh = AuthTokenManager(session: MockURLProtocol.makeSession())
        XCTAssertFalse(fresh.isAuthenticated, "Expired token => not authenticated (A-8 fixed).")
    }

    func test_A8_trueForUnexpiredToken() {
        try! keychain.save("some-token", for: .accessToken)
        try! keychain.save(String(Date().timeIntervalSince1970 + 3600), for: .tokenExpiry)
        let fresh = AuthTokenManager(session: MockURLProtocol.makeSession())
        XCTAssertTrue(fresh.isAuthenticated, "Unexpired token => authenticated.")
    }

    func test_A8_falseWhenNoToken() {
        let fresh = AuthTokenManager(session: MockURLProtocol.makeSession())
        XCTAssertFalse(fresh.isAuthenticated)
    }
}

private final class HitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func inc() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
