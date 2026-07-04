import XCTest
import Security
@testable import ArubaCentral

/// Security regression tests for plan §1 (credential storage).
/// Maps to docs/security/findings.md: A-6 (keychain accessibility class).
/// (Finding 1.7 "keychain residue after logout" is already covered by
/// AuthTokenManagerTests.testClearCredentialsRemovesAllKeys — not duplicated here.)
/// ASSESSMENT artifact — demonstrates current behavior; does not fix it.
/// Written 2026-07-03.
@MainActor
final class StorageSecurityTests: XCTestCase {

    var keychain: KeychainManager!
    let service = "com.aruba.central"

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
    }
    override func tearDown() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        super.tearDown()
    }

    /// Reads the raw `kSecAttrAccessible` attribute persisted for a stored item.
    private func accessibility(of account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnAttributes: true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attrs = result as? [CFString: Any] else { return nil }
        return attrs[kSecAttrAccessible] as? String
    }

    // MARK: - A-6 (FIXED) — secrets stored ThisDeviceOnly (not backup/iCloud-sync-eligible)

    func test_A6_clientSecretUsesThisDeviceOnly() throws {
        try keychain.save("a-long-lived-tenant-oauth-secret", for: .clientSecret)

        let accessible = accessibility(of: "clientSecret")
        XCTAssertNotNil(accessible, "expected a stored keychain item with an accessibility attribute")
        XCTAssertEqual(accessible, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
            "Client secret must be ...ThisDeviceOnly so it can't leave the device via backup/iCloud (A-6 fixed).")
        XCTAssertNotEqual(accessible, kSecAttrAccessibleWhenUnlocked as String,
            "Must no longer be plain WhenUnlocked.")
    }

    func test_A6_accessTokenAlsoThisDeviceOnly() throws {
        try keychain.save("access-token-value", for: .accessToken)
        XCTAssertEqual(accessibility(of: "accessToken"),
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
            "Access token is also ...ThisDeviceOnly (A-6 fixed).")
    }

    // Guards the retrieve() change: reclassified items must still be readable round-trip.
    func test_A6_saveAndRetrieveStillRoundTrips() throws {
        try keychain.save("round-trip-value", for: .clientId)
        XCTAssertEqual(try keychain.retrieve(for: .clientId), "round-trip-value")
    }

    // Regression: re-saving over an item stored under a DIFFERENT accessibility (e.g. a
    // pre-A-6 WhenUnlocked item from an older build) must overwrite it — not fail with
    // errSecDuplicateItem (-25299). The delete step must match on identity only
    // (class/service/account); kSecAttrAccessible/kSecValueData are not delete-match
    // attributes, so including them leaves the stale item and the add collides.
    func test_A6_reSaveOverItemWithDifferentAccessibilitySucceeds() throws {
        let account = KeychainManager.Key.clientSecret.rawValue
        // Simulate a legacy item written by an older build (plain WhenUnlocked).
        let legacy: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecValueData:      Data("old-secret".utf8)
        ]
        XCTAssertEqual(SecItemAdd(legacy as CFDictionary, nil), errSecSuccess)

        // New build saves again — must succeed and overwrite.
        XCTAssertNoThrow(try keychain.save("new-secret", for: .clientSecret))
        XCTAssertEqual(try keychain.retrieve(for: .clientSecret), "new-secret")
        XCTAssertEqual(accessibility(of: account),
                       kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
                       "Re-saved item must carry the ThisDeviceOnly accessibility (A-6).")
    }
}
