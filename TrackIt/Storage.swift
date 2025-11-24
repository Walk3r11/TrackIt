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
}

func formatExpiryInput(_ text: String) -> String {
    let digits = text.filter(\.isNumber).prefix(4)
    if digits.count <= 2 { return String(digits) }
    let month = digits.prefix(2)
    let year = digits.dropFirst(2)
    return "\(month)/\(year)"
}

func formatFullNumber(_ digits: String) -> String? {
    guard !digits.isEmpty else { return nil }
    let clean = digits.filter(\.isNumber)
    guard !clean.isEmpty else { return nil }
    let groups = stride(from: 0, to: clean.count, by: 4).map { idx -> String in
        let start = clean.index(clean.startIndex, offsetBy: idx)
        let end = clean.index(start, offsetBy: 4, limitedBy: clean.endIndex) ?? clean.endIndex
        return String(clean[start..<end])
    }
    return groups.joined(separator: " ")
}
