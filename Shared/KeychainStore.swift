import Foundation
import OSLog
import Security

private let logger = Logger(subsystem: "com.nabettu.watchhook", category: "keychain")

/// 送り先の設定 (Authorization などの秘密を含む) を丸ごと Keychain に置く。
/// Siri から裏で呼ばれても読めるように AfterFirstUnlock にする。端末の外 (iCloud キーチェーン) へは出さない。
struct KeychainStore: Sendable {
    let service: String
    let account: String

    struct ReadError: Error { let status: OSStatus }

    /// 項目が無ければ nil。読めなかった (ロック中など) ときは投げる。「無い」と「読めない」を区別するため。
    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            logger.error("load failed: \(status)")
            throw ReadError(status: status)
        }
        return item as? Data
    }

    @discardableResult
    func save(_ data: Data) -> Bool {
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add.merge(attrs) { $1 }
            let added = SecItemAdd(add as CFDictionary, nil)
            if added != errSecSuccess { logger.error("add failed: \(added)") }
            return added == errSecSuccess
        }
        if status != errSecSuccess { logger.error("update failed: \(status)") }
        return status == errSecSuccess
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
