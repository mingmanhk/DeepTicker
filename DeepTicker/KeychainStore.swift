import Foundation
import Security

public struct KeychainStore {
    public enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed

        public var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return "Keychain error: \(message) (\(status))"
                } else {
                    return "Keychain error with status: \(status)"
                }
            case .dataConversionFailed:
                return "Failed to convert data to string."
            }
        }
    }

    public init() {}

    // Save or update a string for the given account
    public func set(_ value: String, account: String, service: String = Bundle.main.bundleIdentifier ?? "DeepTicker") throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // Try update first
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Add if not existing
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    // Retrieve string for the given account
    public func get(account: String, service: String = Bundle.main.bundleIdentifier ?? "DeepTicker") throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
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

    // Delete item for the given account
    public func delete(account: String, service: String = Bundle.main.bundleIdentifier ?? "DeepTicker") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
