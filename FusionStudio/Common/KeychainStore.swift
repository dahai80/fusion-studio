import Foundation
import Security
import os.log

// Callers: FusionConfig (API key persistence)
// Affected API: KeychainStore.get/set/delete (kSecClassGenericPassword)
// Data schemas: secrets keyed by service+account in macOS Keychain (HIGH-2)
// Note: replaces plaintext @AppStorage API keys; non-secret flags stay in UserDefaults.

private let keychainLog = Logger(subsystem: "com.fusion.studio", category: "KeychainStore")

enum KeychainStore {

    static let service = "com.fusion.studio"

    static func get(_ account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        if status != errSecSuccess {
            keychainLog.error("get(\(account, privacy: .public)): SecItemCopyMatching status=\(status)")
            return nil
        }
        guard let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
            keychainLog.error("get(\(account, privacy: .public)): data decode failed")
            return nil
        }
        return str
    }

    @discardableResult
    static func set(_ account: String, _ value: String) -> Bool {
        let data = Data(value.utf8)
        // 审计v0.1.58 P1-keychain: token 不跨设备同步 (kSecAttrSynchronizable=false) +
        //   仅解锁时可访问 (kSecAttrAccessibleWhenUnlocked). 防 JWT/cluster token 经 iCloud 泄漏.
        let accessible: CFString = kSecAttrAccessibleWhenUnlocked
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
        // try update first (avoid duplicate-item error on re-save)
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessible
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return true
            }
            keychainLog.error("set(\(account, privacy: .public)): SecItemAdd status=\(addStatus)")
            return false
        }
        keychainLog.error("set(\(account, privacy: .public)): SecItemUpdate status=\(updateStatus)")
        return false
    }

    @discardableResult
    static func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        }
        keychainLog.error("delete(\(account, privacy: .public)): status=\(status)")
        return false
    }

    // MARK: - fusion-code per-instance token (HIGH-2)

    // 上游契约 (fusion-code issue #132): 服务端 authToken 空=鉴权 fail-open。
    // 本端生成 per-instance random token, 落 Keychain + 共享文件 (~/.fusion-studio/fusion-code.token, 0600),
    // 供 fusion-code 启动时读取作 ENVIRONMENT_MANAGER_AUTH_TOKEN。待上游 PR 落地后真正生效。
    static let fusionCodeTokenAccount = "fusionCodeApiKey"
    static let fusionCodeTokenFile = ".fusion-studio/fusion-code.token"

    static func fusionCodeToken() -> String {
        if let cached = get(fusionCodeTokenAccount), !cached.isEmpty {
            return cached
        }
        // 密码学安全随机: 32 字节 -> base64
        var bytes = [UInt8](repeating: 0, count: 32)
        let rc = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token: String
        if rc == errSecSuccess {
            token = Data(bytes).base64EncodedString()
        } else {
            keychainLog.error("fusionCodeToken: SecRandomCopyBytes rc=\(rc), fallback to UUID")
            token = UUID().uuidString
        }
        set(fusionCodeTokenAccount, token)
        writeFusionCodeTokenFile(token)
        return token
    }

    static func writeFusionCodeTokenFile(_ token: String) {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(fusionCodeTokenFile)
        let dir = (path as NSString).deletingLastPathComponent
        // 审计0830 P1-资源-2: token 目录未显式 0700, 依赖默认 umask (可能 0755) → 其他本地用户可读 token 文件目录。
        //   显式 0700: 仅属主可读写执行。createDirectory attributes 仅对新建生效, 已存在目录补 setAttributes 兜底。
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir)
        do {
            try token.write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: path
            )
            keychainLog.info("fusionCodeToken: wrote shared token file \(path, privacy: .public) (0600)")
        } catch {
            keychainLog.error("fusionCodeToken: write file failed: \(error.localizedDescription)")
        }
    }

    // MARK: - MultiNode cluster token (Track B: out of @AppStorage plaintext → Keychain)

    static let clusterTokenAccount = "multiNodeClusterToken"

    static func readClusterToken() -> String {
        if let cached = get(clusterTokenAccount), !cached.isEmpty {
            return cached
        }
        let stale = UserDefaults.standard.string(forKey: "multiNodeClusterToken") ?? ""
        if !stale.isEmpty {
            keychainLog.info("migrating cluster token from UserDefaults to Keychain (account \(clusterTokenAccount, privacy: .public))")
            _ = set(clusterTokenAccount, stale)
            UserDefaults.standard.removeObject(forKey: "multiNodeClusterToken")
            return stale
        }
        return ""
    }

    @discardableResult
    static func writeClusterToken(_ value: String) -> Bool {
        set(clusterTokenAccount, value)
    }

    @discardableResult
    static func deleteClusterToken() -> Bool {
        delete(clusterTokenAccount)
    }

    // MARK: - Identity (fusion-identity JWT + refresh token)

    static let identityJwtAccount = "identityJwt"
    static let identityRefreshAccount = "identityRefresh"

    static func readIdentityJWT() -> String {
        get(identityJwtAccount) ?? ""
    }

    @discardableResult
    static func writeIdentityJWT(_ value: String) -> Bool {
        set(identityJwtAccount, value)
    }

    static func readIdentityRefresh() -> String {
        get(identityRefreshAccount) ?? ""
    }

    @discardableResult
    static func writeIdentityRefresh(_ value: String) -> Bool {
        set(identityRefreshAccount, value)
    }

    static func clearIdentity() {
        delete(identityJwtAccount)
        delete(identityRefreshAccount)
        keychainLog.info("clearIdentity: cleared jwt+refresh (accounts \(identityJwtAccount, privacy: .public), \(identityRefreshAccount, privacy: .public))")
    }
}
