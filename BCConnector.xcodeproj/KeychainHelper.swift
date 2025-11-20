import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case dataConversionFailed
}

struct KeychainHelper {
    static func set(_ value: String?, for key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") throws {
        let account = key
        let service = service

        // Delete existing item first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        guard let value = value else { return }
        guard let data = value.data(using: .utf8) else { throw KeychainError.dataConversionFailed }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func get(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") throws -> String? {
        let account = key
        let service = service

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    static func delete(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") {
        let account = key
        let service = service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
