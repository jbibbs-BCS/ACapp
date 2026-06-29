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
