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
        {
          "sites": [
            {
              "site_id": "s1", "site_name": "HQ",
              "health_score": 90, "ap_count": 10,
              "switch_count": 2, "client_count": 100
            }
          ],
          "total": 1
        }
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
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchSiteHealthThrowsServerErrorOn500() async {
        MockURLProtocol.respondWith(statusCode: 500)
        do {
            _ = try await sut.fetchSiteHealth()
            XCTFail("Expected throw")
        } catch let e as APIError {
            XCTAssertEqual(e, .serverError(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchSiteHealthThrowsDecodingErrorOnBadJSON() async {
        MockURLProtocol.respondWith(statusCode: 200, json: "not-json")
        do {
            _ = try await sut.fetchSiteHealth()
            XCTFail("Expected throw")
        } catch let e as APIError {
            XCTAssertEqual(e, .decodingError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - fetchAPs pagination

    func testFetchAPsIncludesLimitAndNextCursor() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let json = #"{"aps":[],"total":0,"next":null}"#
            return (response, Data(json.utf8))
        }

        _ = try await sut.fetchAPs(site: nil, search: nil, limit: 100, next: "cursor50")
        let urlString = capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("next=cursor50"), "Expected next cursor in URL: \(urlString)")
        XCTAssertTrue(urlString.contains("limit=100"))
    }

    func testFetchAPsIncludesSiteFilter() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"aps":[],"total":0,"next":null}"#.utf8))
        }

        _ = try await sut.fetchAPs(site: "HQ Campus", search: nil, limit: 100, next: nil)
        let urlString = capturedURL?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("filter="), "Expected OData filter param in URL: \(urlString)")
        XCTAssertTrue(urlString.lowercased().contains("hq"), "Expected site name in filter: \(urlString)")
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
                let body = #"{"sites":[{"site_id":"s1","site_name":"HQ","health_score":90,"ap_count":1,"switch_count":1,"client_count":1}],"total":1}"#
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
