import Foundation
import Security

protocol EBirdKeyStore: Sendable {
    func read() throws -> String?
    func save(_ key: String) throws
    func remove() throws
}

enum EBirdKeychainError: LocalizedError {
    case inaccessible
    var errorDescription: String? { "De eBird-sleutel kon niet veilig worden opgeslagen of gelezen. Probeer opnieuw." }
}

struct EBirdKeychainStore: EBirdKeyStore {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "BirdingCompanion") + ".ebird",
         kSecAttrAccount as String: "personal-api-key"]
    }
    func read() throws -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { throw EBirdKeychainError.inaccessible }
        return key
    }
    func save(_ key: String) throws {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw EBirdError.invalidKey }
        let attributes: [String: Any] = [kSecValueData as String: Data(cleaned.utf8),
                                       kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = query.merging(attributes) { _, new in new }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw EBirdKeychainError.inaccessible }
        } else if status != errSecSuccess { throw EBirdKeychainError.inaccessible }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw EBirdKeychainError.inaccessible }
    }
}
