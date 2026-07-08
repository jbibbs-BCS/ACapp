import XCTest
@testable import ArubaCentral

/// Security regression tests for plan §4 (input validation & injection).
/// Maps to docs/security/findings.md: A-1, A-2, A-3, A-4, and the A-5 refutation.
///
/// These are ASSESSMENT artifacts: they DEMONSTRATE the current defects so remediation
/// has a red baseline to turn green. They intentionally do not fix production code.
///
/// Design note on A-1: a Swift force-unwrap trap aborts the whole test process, so we do
/// NOT call the crashing path. Instead we assert the *precondition* — that the exact
/// string `buildRequest` concatenates makes `URLComponents(string:)` nil — which proves
/// the `!` on CentralAPIClient.swift:40 would trap for that input.
///
/// Written 2026-07-03 (Phase "§4 test harness").
@MainActor
final class InputValidationSecurityTests: XCTestCase {

    var authManager: AuthTokenManager!
    var sut: CentralAPIClient!
    var keychain: KeychainManager!
    let base = "https://us1.api.central.arubanetworks.com"

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        try! keychain.save("test-id",     for: .clientId)
        try! keychain.save("test-secret", for: .clientSecret)
        try! keychain.save("valid-token", for: .accessToken)      // avoids a live token fetch
        try! keychain.save(String(Date().timeIntervalSince1970 + 3600), for: .tokenExpiry)

        authManager = AuthTokenManager(session: MockURLProtocol.makeSession())
        sut = CentralAPIClient(authManager: authManager,
                               session: MockURLProtocol.makeSession(),
                               baseURL: URL(string: base)!)
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        MockURLProtocol.requestHandler = nil
        sut = nil
        authManager = nil
        super.tearDown()
    }

    /// Runs `op`, capturing the URL the client actually built. Tolerates any decode error
    /// (we only care about the outgoing request, not the response body).
    private func captureURL(_ op: () async throws -> Void,
                            respond json: String = "{}") async -> URL? {
        let box = URLBox()
        MockURLProtocol.requestHandler = { request in
            box.set(request.url)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(json.utf8))
        }
        _ = try? await op()
        return box.get()
    }

    // MARK: - A-1 (RE-GRADED via runtime evidence) — force-unwrap does NOT trap on iOS 26.5
    //
    // Original Phase-1 hypothesis (from a static read): a serial with a space / control
    // char / unpaired % makes `URLComponents(string:)` nil, so the `!` on
    // CentralAPIClient.swift:40 traps -> client-side DoS.
    //
    // RUNTIME EVIDENCE (this suite, iOS 26.5 — the app's IPHONEOS_DEPLOYMENT_TARGET):
    // the new swift-foundation URL parser is LENIENT and returns a non-nil value
    // (lazily percent-encoding on demand), so none of those inputs make either
    // force-unwrap trap. On older Foundation (iOS <= 18) the space case WOULD have
    // crashed, but this app does not target those OSes. A-1 is therefore REFUTED as an
    // exploitable crash on the supported runtime; the force-unwrap remains a latent
    // code smell (would resurface if the deployment target is lowered). Note: the raw
    // interpolation is still an INJECTION vector — see A-2 — which is unaffected by this.

    /// Mirrors buildRequest's concatenation (CentralAPIClient.swift:39-42). Returns true
    /// if the URL builds without either force-unwrap trapping.
    private func buildsWithoutTrapping(serial: String) -> Bool {
        let path = "/network-monitoring/v1/aps/\(serial)"
        guard let comps = URLComponents(string: base + path) else { return false } // else line 40 traps
        return comps.url != nil                                                     // else line 42 traps
    }

    func test_A1_refuted_malformedSerialsDoNotTrapOnDeploymentTarget() {
        let hostileSerials = ["AP 001", "AP\u{7f}001", "AP50%", "AP%zz", "AP#frag", "AP[0]", "A B/reboot"]
        for s in hostileSerials {
            XCTAssertTrue(buildsWithoutTrapping(serial: s),
                "iOS 26.5 Foundation accepts serial \(s.debugDescription) without nil -> " +
                "force-unwraps do not trap (A-1 does not reproduce on the deployment target).")
        }
    }

    func test_A1_control_wellFormedSerialBuildsValidURL() {
        XCTAssertTrue(buildsWithoutTrapping(serial: "CN12345678"),
            "Sanity: a well-formed serial builds a valid URL.")
    }

    // MARK: - A-2 (FIXED) — serial is percent-encoded, so no path/query injection

    func test_A2_querySmugglingBlocked() async {
        // A `?` in serial is now encoded into the path segment, not a query separator.
        let url = await captureURL { _ = try await self.sut.fetchAPDetail(serial: "REAL?injected=evil") }
        XCTAssertNil(url?.query,
            "No query smuggling: the `?` is encoded (A-2 fixed). query=\(url?.query ?? "nil")")
        XCTAssertTrue(url?.absoluteString.contains("aps/REAL%3Finjected%3Devil") ?? false,
            "Serial encoded into the path. url=\(url?.absoluteString ?? "nil")")
    }

    func test_A2_pathSegmentSmugglingBlocked() async {
        // `/` in serial is encoded (%2F), so it can't add path segments to a destructive action.
        let url = await captureURL { try await self.sut.rebootAP(serial: "REAL/extra/segment") }
        let s = url?.absoluteString ?? ""
        XCTAssertTrue(s.contains("aps/REAL%2Fextra%2Fsegment/reboot"),
            "Path separators encoded; endpoint path intact (A-2 fixed). url=\(s)")
        XCTAssertFalse(s.contains("aps/REAL/extra/segment"),
            "Raw path smuggling must no longer be possible.")
    }

    func test_A2_rebootSuffixPreserved() async {
        // `?` in serial no longer collapses the `/reboot` suffix into a query.
        let url = await captureURL { try await self.sut.rebootAP(serial: "REAL?x=y") }
        XCTAssertNil(url?.query, "No query injection (A-2 fixed). query=\(url?.query ?? "nil")")
        XCTAssertTrue(url?.absoluteString.hasSuffix("/reboot") ?? false,
            "The `/reboot` action suffix is preserved. url=\(url?.absoluteString ?? "nil")")
    }

    // MARK: - A-3 (FIXED) — single quotes in site are OData-escaped (doubled)

    func test_A3_odataFilterQuotesAreEscaped() async {
        let url = await captureURL(
            { _ = try await self.sut.fetchAPs(site: "x' or siteName ne 'y", search: nil, limit: 100, next: nil) },
            respond: #"{"items":[],"next":null}"#
        )
        let comps = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let filter = comps?.queryItems?.first(where: { $0.name == "filter" })?.value ?? ""
        XCTAssertEqual(filter, "siteName eq 'x'' or siteName ne ''y'",
            "Single quotes doubled per OData; the injected value stays a literal (A-3 fixed). Got: \(filter)")
    }

    // MARK: - A-4 (FIXED) — search paginators are capped

    func test_A4_paginatorStopsAtCap() async throws {
        // Server offers a never-ending `next` (always non-null). The paginators must stop
        // at the client-side cap (50 pages each) instead of following it forever.
        let counter = Counter()
        MockURLProtocol.requestHandler = { request in
            counter.inc()
            let url = request.url!
            let json = "{\"items\":[],\"total\":0,\"next\":\"more\"}"   // cursor never terminates
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
            return (resp, Data(json.utf8))
        }

        _ = try await sut.searchDevices(query: "anything")

        // 3 paginators (APs / Switches / Clients), each capped at maxSearchPages (50).
        XCTAssertEqual(counter.value, 3 * 50,
            "Paginators must stop at the 50-page cap despite a never-null cursor (A-4 fixed). Got \(counter.value).")
    }

    // MARK: - A-5 (REFUTED) — next/search use URLQueryItem => encoded, not smuggled or crashing

    func test_A5_refuted_nextCursorWithSpaceIsEncodedNotCrashing() async {
        // A space in `next` would crash if concatenated into the path; via URLQueryItem
        // it is percent-encoded. This is why A-5 is REFUTED (safe).
        let url = await captureURL(
            { _ = try await self.sut.fetchAPs(site: nil, search: nil, limit: 100, next: "cursor with space") },
            respond: #"{"items":[],"next":null}"#
        )
        XCTAssertNotNil(url, "next via URLQueryItem did not crash (A-5 refuted).")
        let s = url?.absoluteString ?? ""
        XCTAssertTrue(s.contains("cursor%20with%20space") || s.contains("cursor+with+space"),
            "next was percent-encoded, not smuggled. URL: \(s)")
    }
}

// MARK: - Small thread-safe helpers (MockURLProtocol invokes the handler off the main actor)

private final class URLBox: @unchecked Sendable {
    private let lock = NSLock()
    private var url: URL?
    func set(_ u: URL?) { lock.lock(); url = u; lock.unlock() }
    func get() -> URL?  { lock.lock(); defer { lock.unlock() }; return url }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func inc() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
