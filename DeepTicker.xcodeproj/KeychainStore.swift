// KeychainStore.swift
// DeepTicker
//
// A lightweight Keychain wrapper for storing sensitive strings like API keys.
// Uses kSecClassGenericPassword with service+account to namespace entries.

import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case stringEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error (\(status)): \(message)"
            } else {
                return "Keychain error (\(status))"
            }
        case .stringEncodingFailed:
            return "Failed to encode string for Keychain."
        }
    }
}

struct KeychainStore {
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "DeepTicker") {
        self.service = service
    }

    func set(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.stringEncodingFailed }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // Try update first
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }

        if status == errSecItemNotFound {
            // Add new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func get(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }

        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.stringEncodingFailed
        }
        return string
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
