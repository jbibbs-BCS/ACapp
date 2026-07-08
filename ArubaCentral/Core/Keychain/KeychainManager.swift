import Foundation
import Security

enum KeychainError: Error, Equatable {
    case notFound
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case dataCorrupted
}

final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.aruba.central"

    enum Key: String, CaseIterable {
        case clientId     = "clientId"
        case clientSecret = "clientSecret"
        case accessToken  = "accessToken"
        case tokenExpiry  = "tokenExpiry"
        case region       = "region"
    }

    init() {}

    // MARK: - Generic Key-based API (used by AuthTokenManager)

    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.dataCorrupted }
        // Identity attributes only — used to locate and remove any existing item
        // regardless of how it was stored. kSecAttrAccessible and kSecValueData are NOT
        // delete-match attributes: including them lets a stale item (e.g. a pre-A-6
        // WhenUnlocked item, or one holding a different value) survive the delete, so the
        // subsequent SecItemAdd collides with errSecDuplicateItem (-25299).
        let identity: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(identity as CFDictionary)

        var addQuery = identity
        // ThisDeviceOnly (A-6): the tenant OAuth secret & tokens must not ride iCloud
        // Keychain sync or device backups off this device.
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData]      = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    func retrieve(for key: Key) throws -> String {
        // Note: kSecAttrAccessible is not a match attribute for lookups; it is set on save
        // (A-6). Omitting it here keeps retrieval working regardless of the stored class.
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     key.rawValue,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var result: CFTypeRef?
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

    // MARK: - Credential-specific convenience API (legacy / backward compat)

    func saveClientID(_ value: String) {
        try? save(value, for: .clientId)
    }

    func clientID() -> String? {
        try? retrieve(for: .clientId)
    }

    func saveClientSecret(_ value: String) {
        try? save(value, for: .clientSecret)
    }

    func clientSecret() -> String? {
        try? retrieve(for: .clientSecret)
    }

    func saveRegion(_ value: String) {
        try? save(value, for: .region)
    }

    func region() -> String? {
        try? retrieve(for: .region)
    }

    func clearAll() {
        Key.allCases.forEach { delete(for: $0) }
    }
}
