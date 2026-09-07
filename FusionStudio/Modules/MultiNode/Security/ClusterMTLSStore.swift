import Foundation
import Security
import os.log

private let mtlsStoreLog = Logger(subsystem: "com.fusion.studio", category: "ClusterMTLSStore")

// 审计product-0907 P2-3 / C2: mTLS client identity store.
//   零信任企业集群: 服务端可要求客户端证书双向认证. 本类管理 p12 导入 -> SecIdentity ->
//   Keychain 持久化, 运行时供 ClusterTLSDelegate 在 clientCertificate challenge 时出示.
//   向后兼容: 未导入客户端证书时 loadClientIdentity()=nil, delegate 走 .performDefaultHandling,
//   仅 Bearer token + 服务端 pinning (PR#396) 不变.
final class ClusterMTLSStore {
    static let shared = ClusterMTLSStore()

    private let p12Account = "cluster-mtls-client-p12"
    private let p12PasswordAccount = "cluster-mtls-client-p12-pass"

    private init() {}

    // 导入 .p12 (PKCS12) 客户端证书 + 私钥, 持久化 blob 到 Keychain.
    //   密码单独存 Keychain account (p12 解析需要). 不明文落盘.
    func importIdentity(at url: URL, password: String) throws {
        let data = try Data(contentsOf: url)
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var importedItems: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &importedItems)
        guard status == errSecSuccess, let items = importedItems as? [[String: Any]], !items.isEmpty else {
            mtlsStoreLog.error("mTLS import: SecPKCS12Import failed status=\(status, privacy: .public)")
            throw NSError(domain: "ClusterMTLSStore", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Invalid .p12 file or wrong password"])
        }
        guard let identityRef = items[0][kSecImportItemIdentity as String] else {
            mtlsStoreLog.error("mTLS import: no identity in p12")
            throw NSError(domain: "ClusterMTLSStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No identity found in .p12"])
        }
        let identity = identityRef as! SecIdentity
        let summary = clientCertSummary(of: identity)
        let p12Base64 = data.base64EncodedString()
        guard KeychainStore.set(p12Account, p12Base64) else {
            mtlsStoreLog.error("mTLS import: Keychain write p12 failed")
            throw NSError(domain: "ClusterMTLSStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Keychain write failed"])
        }
        _ = KeychainStore.set(p12PasswordAccount, password)
        mtlsStoreLog.info("mTLS client identity imported subject=\(summary.subject, privacy: .public) fp=\(summary.fingerprint, privacy: .public)")
    }

    // 从 Keychain 加载 p12 + 解析出 SecIdentity (cert + private key).
    //   nil = 未配置 (向后兼容, 走 Bearer-only).
    func loadClientIdentity() -> SecIdentity? {
        guard let p12Base64 = KeychainStore.get(p12Account),
              let p12Data = Data(base64Encoded: p12Base64),
              let password = KeychainStore.get(p12PasswordAccount) else {
            return nil
        }
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var importedItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &importedItems)
        guard status == errSecSuccess, let items = importedItems as? [[String: Any]], !items.isEmpty else {
            mtlsStoreLog.error("mTLS load: SecPKCS12Import failed status=\(status, privacy: .public) — p12 corrupt or password changed")
            return nil
        }
        guard let identityRef = items[0][kSecImportItemIdentity as String] else {
            mtlsStoreLog.error("mTLS load: no identity in stored p12")
            return nil
        }
        let identity = identityRef as! SecIdentity
        return identity
    }

    // 删除客户端证书 + 密码.
    func deleteClientIdentity() {
        _ = KeychainStore.delete(p12Account)
        _ = KeychainStore.delete(p12PasswordAccount)
        mtlsStoreLog.info("mTLS client identity deleted")
    }

    // 是否已配置客户端证书 (UI 状态用, 不触发完整解析).
    func hasClientIdentity() -> Bool {
        KeychainStore.get(p12Account) != nil
    }

    // 摘要: subject / fingerprint / notAfter (复用 CertSummary UI 结构).
    //   解析失败返回 nil (UI 显示未配置).
    func clientIdentitySummary() -> CertSummary? {
        guard let identity = loadClientIdentity() else { return nil }
        return clientCertSummary(of: identity)
    }

    private func clientCertSummary(of identity: SecIdentity) -> CertSummary {
        var cert: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let cert = cert else {
            return CertSummary(fingerprint: "(unknown)", subject: "(unknown)", notAfter: nil)
        }
        let subject = SecCertificateCopySubjectSummary(cert) as String? ?? "(unknown)"
        let notAfter = TlsTrustStore.notAfter(of: cert)
        let fp = certFingerprint(of: cert)
        return CertSummary(fingerprint: fp, subject: subject, notAfter: notAfter)
    }

    private func certFingerprint(of cert: SecCertificate) -> String {
        var error: Unmanaged<CFError>?
        guard let oidData = SecCertificateCopyValues(cert, [kSecOIDX509V1SerialNumber] as CFArray, &error) as? [String: Any],
              let serial = oidData[kSecOIDX509V1SerialNumber as String] as? Data else {
            return UUID().uuidString
        }
        return serial.map { String(format: "%02x", $0) }.joined()
    }
}
