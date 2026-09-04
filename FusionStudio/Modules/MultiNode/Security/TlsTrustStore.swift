import Foundation
import Security
import os.log

private let tlsStoreLog = Logger(subsystem: "com.fusion.studio", category: "TlsTrustStore")

struct CertSummary {
    let fingerprint: String
    let subject: String
    // 审计v0.1.58 P1-cert: 暴露证书有效期, UI 可提前告警临期 (≤30天) 轮换.
    let notAfter: Date?
    var daysUntilExpiry: Int? {
        guard let notAfter = notAfter else { return nil }
        return Int(notAfter.timeIntervalSinceNow / 86400)
    }
    var isNearExpiry: Bool {
        (daysUntilExpiry ?? Int.max) <= 30
    }
}

final class TlsTrustStore {
    static let shared = TlsTrustStore()

    private let accountPrefix = "cluster-tls-cert-"

    private init() {}

    func importCert(at url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            tlsStoreLog.error("importCert: not a valid certificate DER/PEM: \(url.path, privacy: .public)")
            throw NSError(domain: "TlsTrustStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid certificate file"])
        }
        let fp = fingerprint(of: cert)
        let account = accountPrefix + fp
        let derBase64 = data.base64EncodedString()
        if !KeychainStore.set(account, derBase64) {
            tlsStoreLog.error("importCert: Keychain write failed for fp=\(fp, privacy: .public)")
            throw NSError(domain: "TlsTrustStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Keychain write failed"])
        }
        // update index
        let existingIndex = KeychainStore.get("cluster-tls-cert-index") ?? ""
        let fps = existingIndex.split(separator: ",").map { String($0) }
        if !fps.contains(fp) {
            let newIndex = (fps + [fp]).joined(separator: ",")
            _ = KeychainStore.set("cluster-tls-cert-index", newIndex)
        }
        tlsStoreLog.info("imported cert fp=\(fp, privacy: .public)")
    }

    func pinnedAnchors() -> [SecCertificate] {
        var anchors: [SecCertificate] = []
        for summary in listCerts() {
            if let derB64 = KeychainStore.get(accountPrefix + summary.fingerprint),
               let der = Data(base64Encoded: derB64),
               let cert = SecCertificateCreateWithData(nil, der as CFData) {
                anchors.append(cert)
            }
        }
        return anchors
    }

    func listCerts() -> [CertSummary] {
        // KeychainStore has no enumerate-all API; read from a known index key listing fingerprints.
        guard let indexStr = KeychainStore.get("cluster-tls-cert-index"), !indexStr.isEmpty else {
            return []
        }
        let fps = indexStr.split(separator: ",").map { String($0) }
        var summaries: [CertSummary] = []
        for fp in fps {
            if let derB64 = KeychainStore.get(accountPrefix + fp),
               let der = Data(base64Encoded: derB64),
               let cert = SecCertificateCreateWithData(nil, der as CFData) {
                let subject = SecCertificateCopySubjectSummary(cert) as String? ?? "(unknown)"
                let notAfter = TlsTrustStore.notAfter(of: cert)
                let summary = CertSummary(fingerprint: fp, subject: subject, notAfter: notAfter)
                if summary.isNearExpiry {
                    tlsStoreLog.error("pinned cert fp=\(fp, privacy: .public) near expiry: \(summary.daysUntilExpiry ?? -1) days — rotate now")
                }
                summaries.append(summary)
            }
        }
        return summaries
    }

    func removeCert(fingerprint: String) throws {
        _ = KeychainStore.delete(accountPrefix + fingerprint)
        // update index
        guard let indexStr = KeychainStore.get("cluster-tls-cert-index") else { return }
        let remaining = indexStr.split(separator: ",").map { String($0) }.filter { $0 != fingerprint }
        let newIndex = remaining.joined(separator: ",")
        if newIndex.isEmpty {
            _ = KeychainStore.delete("cluster-tls-cert-index")
        } else {
            _ = KeychainStore.set("cluster-tls-cert-index", newIndex)
        }
        tlsStoreLog.info("removed cert fp=\(fingerprint, privacy: .public)")
    }

    private func fingerprint(of cert: SecCertificate) -> String {
        var error: Unmanaged<CFError>?
        guard let oidData = SecCertificateCopyValues(cert, [kSecOIDX509V1SerialNumber] as CFArray, &error) as? [String: Any],
              let serial = oidData[kSecOIDX509V1SerialNumber as String] as? Data else {
            return UUID().uuidString
        }
        return serial.map { String(format: "%02x", $0) }.joined()
    }

    // 审计v0.1.58 P1-cert: 提取证书 notAfter (有效期终点), 供临期告警.
    static func notAfter(of cert: SecCertificate) -> Date? {
        var error: Unmanaged<CFError>?
        guard let oidData = SecCertificateCopyValues(cert, [kSecOIDX509V1ValidityNotAfter] as CFArray, &error) as? [String: Any],
              let ts = oidData[kSecOIDX509V1ValidityNotAfter as String] as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: ts)
    }
}
