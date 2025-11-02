import Foundation
import Security
import os.log

// MARK: - Keychain Helper
/// A helper class for securely storing and retrieving sensitive data like API keys in iOS Keychain
final class KeychainHelper {
    static let standard = KeychainHelper()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.DeepTicker", category: "KeychainHelper")

    private init() {}

    /// Save a string value to the keychain
    /// - Parameters:
    ///   - data: The string data to save
    ///   - service: The service identifier (usually bundle identifier)
    ///   - account: The account/key identifier
    @discardableResult
    func save(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode string to data for account: \(account)")
            return false
        }

        // Delete existing item first (if it exists)
        delete(service: service, account: account)

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add item to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.info("Successfully saved keychain item for account: \(account)")
            return true
        } else {
            logger.error("Failed to save keychain item for account: \(account), status: \(status) - \(Self.keychainErrorDescription(for: status))")
            return false
        }
    }

    /// Read a string value from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account/key identifier
    /// - Returns: The stored string value, or nil if not found
    func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let data = result as? Data,
               let string = String(data: data, encoding: .utf8) {
                logger.info("Successfully read keychain item for account: \(account)")
                return string
            } else {
                logger.error("Failed to convert data to string for account: \(account)")
                return nil
            }
        } else if status == errSecItemNotFound {
            // Item not found is an expected case, so we just return nil
            return nil
        } else {
            logger.error("Failed to read keychain item for account: \(account), status: \(status) - \(Self.keychainErrorDescription(for: status))")
            return nil
        }
    }

    /// Delete an item from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account/key identifier
    @discardableResult
    func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            logger.info("Successfully deleted keychain item for account: \(account)")
            return true
        } else if status == errSecItemNotFound {
            // Consider this a success since the item is not there
            return true
        } else {
            logger.error("Failed to delete keychain item for account: \(account), status: \(status) - \(Self.keychainErrorDescription(for: status))")
            return false
        }
    }

    /// Delete all items for a given service
    /// - Parameter service: The service identifier
    @discardableResult
    func deleteAll(service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            logger.info("Successfully deleted all keychain items for service: \(service)")
            return true
        } else if status == errSecItemNotFound {
            // No items found is considered success
            return true
        } else {
            logger.error("Failed to delete all keychain items for service: \(service), status: \(status) - \(Self.keychainErrorDescription(for: status))")
            return false
        }
    }
}

// MARK: - Keychain Status Extensions
extension KeychainHelper {
    /// Get a human-readable description of a Keychain Services error
    /// - Parameter status: The OSStatus returned from a Keychain Services function
    /// - Returns: A readable error description
    static func keychainErrorDescription(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Memory allocation failure"
        case errSecNotAvailable:
            return "Service not available"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecUnimplemented:
            return "Function not implemented"
        case errSecDecode:
            return "Decode error"
        default:
            return "Unknown error (\(status))"
        }
    }
}
