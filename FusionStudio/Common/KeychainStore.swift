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
            // 审计0907 P3-5: account 名 (identityJwt/fusionCodeApiKey 等) 标记存何 secret 类型,
            //   public 日志泄元数据。改通用消息不含 account 名 (运维调试仍可凭 status 定位)。
            keychainLog.error("Keychain get failed: SecItemCopyMatching status=\(status)")
            return nil
        }
        guard let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
            keychainLog.error("Keychain get failed: data decode failed")
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
            keychainLog.error("Keychain set failed: SecItemAdd status=\(addStatus)")
            return false
        }
        keychainLog.error("Keychain set failed: SecItemUpdate status=\(updateStatus)")
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
        keychainLog.error("Keychain delete failed: status=\(status)")
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
        // 审计0907 P2-9: 旧 write(atomically:) 后 setAttributes 0600 有 TOCTOU 窗 — atomic temp 默认 umask (0644)
        //   可世界可读, setAttributes 前他用户可读。改 createFile 显式 0600 于创建时 (无窗口), 再 rename 原子替换。
        let tmpPath = path + ".tmp"
        FileManager.default.createFile(
            atPath: tmpPath,
            contents: Data(token.utf8),
            attributes: [.posixPermissions: 0o600]
        )
        do {
            _ = try FileManager.default.replaceItemAt(
                URL(fileURLWithPath: path),
                withItemAt: URL(fileURLWithPath: tmpPath)
            )
            keychainLog.info("fusionCodeToken: wrote shared token file \(path, privacy: .public) (0600, atomic)")
        } catch {
            keychainLog.error("fusionCodeToken: replaceItemAt failed: \(error.localizedDescription)")
            try? FileManager.default.removeItem(atPath: tmpPath)
        }
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
        // 审计0907 P3-5: 不 log account 名 (元数据泄漏)。
        keychainLog.info("clearIdentity: cleared jwt+refresh accounts")
    }
}
