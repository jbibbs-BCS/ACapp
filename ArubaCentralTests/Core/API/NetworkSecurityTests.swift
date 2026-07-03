import XCTest
@testable import ArubaCentral

/// Security regression tests for plan §3 (network / transport).
/// Maps to docs/security/findings.md: 3.5 (region-SSRF via UserDefaults).
/// 3.1 (no TLS pinning) is code-confirmed and needs a MITM proxy to demonstrate at
/// runtime; it is not unit-testable and is not covered here.
/// Written 2026-07-03.
@MainActor
final class NetworkSecurityTests: XCTestCase {

    /// Mirrors ArubaCentralApp.init's region resolution (ArubaCentralApp.swift:12-13).
    private func resolveRegion(fromStoredId regionId: String) -> CentralRegion {
        CentralRegion.all.first { $0.id == regionId } ?? CentralRegion.defaultRegion
    }

    // MARK: - 3.5 — attacker-writable selectedRegionId cannot redirect to a rogue host

    func test_3_5_maliciousRegionIdFallsBackToHTTPSAllowlist() {
        let hostileIds = [
            "http://evil.example",
            "https://attacker.test",
            "us1' OR '1'='1",
            "../../etc/passwd",
            "javascript:alert(1)",
            "",
            "US1",          // wrong case -> not an exact id match
        ]
        for rid in hostileIds {
            let region = resolveRegion(fromStoredId: rid)
            XCTAssertTrue(CentralRegion.all.contains(region),
                "Stored id \(rid.debugDescription) must resolve to an ALLOWLISTED region (3.5 mitigated).")
            XCTAssertEqual(region.baseURL.scheme, "https",
                "Resolved base URL must be HTTPS for id \(rid.debugDescription).")
        }
    }

    func test_3_5_validRegionIdResolvesExactly() {
        XCTAssertEqual(resolveRegion(fromStoredId: "de1").id, "de1")
        XCTAssertEqual(resolveRegion(fromStoredId: "garbage").id, CentralRegion.defaultRegion.id)
    }

    // MARK: - N-2 residual (FIXED) — updateBaseURL only accepts allowlisted region URLs

    func test_N2_updateBaseURLRejectsNonAllowlistedURL() {
        let auth = AuthTokenManager(session: MockURLProtocol.makeSession())
        let client = CentralAPIClient(authManager: auth,
                                      session: MockURLProtocol.makeSession(),
                                      baseURL: CentralRegion.defaultRegion.baseURL)
        let original = client.baseURL

        client.updateBaseURL(URL(string: "https://attacker.example")!)
        XCTAssertEqual(client.baseURL, original,
            "A non-allowlisted base URL is rejected (N-2 residual fixed).")

        let de1 = CentralRegion.all.first { $0.id == "de1" }!.baseURL
        client.updateBaseURL(de1)
        XCTAssertEqual(client.baseURL, de1, "An allowlisted region URL is accepted.")
    }
}
