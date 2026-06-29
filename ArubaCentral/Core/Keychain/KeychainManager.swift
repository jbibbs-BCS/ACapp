import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.aruba.central"

    private init() {}

    // MARK: - clientID

    func saveClientID(_ value: String) {
        save(value, key: "clientID")
    }

    func clientID() -> String? {
        retrieve(key: "clientID")
    }

    // MARK: - clientSecret

    func saveClientSecret(_ value: String) {
        save(value, key: "clientSecret")
    }

    func clientSecret() -> String? {
        retrieve(key: "clientSecret")
    }

    // MARK: - region

    func saveRegion(_ value: String) {
        save(value, key: "region")
    }

    func region() -> String? {
        retrieve(key: "region")
    }

    // MARK: - clearAll

    func clearAll() {
        delete(key: "clientID")
        delete(key: "clientSecret")
        delete(key: "region")
    }

    // MARK: - Private

    private func save(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     key,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlocked,
            kSecValueData:       data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func retrieve(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlocked,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
