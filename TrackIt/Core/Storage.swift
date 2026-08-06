import Foundation
import Security

enum SecureStore {
    private static func query(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value) else { return }
        var q = query(for: key)
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = data
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        var q = query(for: key)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func delete(key: String) {
        let q = query(for: key)
        SecItemDelete(q as CFDictionary)
    }

    static func delete(keys: [String]) {
        keys.forEach { delete(key: $0) }
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(query as CFDictionary)
    }
}
