import Foundation
import Security

enum InstallIdentity {
    private static let kInstallIdKey   = "coinstreak.installId"
    private static let kInstallSideKey = "coinstreak.installSide"

    /// Returns a stable UUID stored in Keychain (survives uninstall/reinstall).
    static func getOrCreateInstallId() -> String {
        if let existing = readKeychain(key: kInstallIdKey) { return existing }
        let newId = UUID().string
        _ = saveKeychain(key: kInstallIdKey, value: newId)
        return newId
    }

    // MARK: - Lock side in Keychain (H/T)
    static func getLockedSide() -> String? {
        readKeychain(key: kInstallSideKey) // "H" or "T"
    }

    static func setLockedSide(_ side: String) { // pass "H" or "T"
        _ = saveKeychain(key: kInstallSideKey, value: side)
    }

    // MARK: - Debug helpers (remove keys)  // NEW
    @discardableResult
    static func removeLockedSide() -> Bool {     // NEW
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: kInstallSideKey
        ] as CFDictionary) == errSecSuccess
    }

    @discardableResult
    static func removeInstallId() -> Bool {      // NEW
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: kInstallIdKey
        ] as CFDictionary) == errSecSuccess
    }

    // MARK: - Minimal Keychain helpers
    private static func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecReturnData as String:       true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func saveKeychain(key: String, value: String) -> Bool {
        let data = Data(value.utf8)
        // Idempotent write
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:        data
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

private extension UUID {
    var string: String { uuidString }
}
