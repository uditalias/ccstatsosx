import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case unexpectedData
    case osError(OSStatus)
}

struct KeychainService {
    private static let service = "Claude Code-credentials"
    private static let account = NSUserName()

    static func readCredentials() throws -> KeychainCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.osError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        return try JSONDecoder().decode(KeychainCredentials.self, from: data)
    }

    static func saveCredentials(_ credentials: KeychainCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.osError(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.osError(status)
        }
    }
}
