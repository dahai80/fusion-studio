import Foundation
import Security
import os.log

private let tlsDelLog = Logger(subsystem: "com.fusion.studio", category: "ClusterTLS")

final class ClusterTLSDelegate: NSObject, URLSessionDelegate {

    var clientIdentity: SecIdentity? = nil

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let pinned = TlsTrustStore.shared.pinnedAnchors()
        if !pinned.isEmpty {
            let extraCerts = pinned as CFArray
            SecTrustSetAnchorCertificates(serverTrust, extraCerts)
            // SEC-2 (审计product-0905 P2): 独占 pinning — 仅接受 pinned anchors, 拒绝系统根。
            //   非 .true 时系统根 CA 误发证/被攻陷也能通过, pinning 形同虚设。企业部署须独占。
            SecTrustSetAnchorCertificatesOnly(serverTrust, true)
            tlsDelLog.info("TLS eval exclusive with \(pinned.count, privacy: .public) pinned anchors (system roots rejected)")
        } else {
            tlsDelLog.info("TLS eval system-only (no pinned anchors)")
        }
        var error: CFError?
        if SecTrustEvaluateWithError(serverTrust, &error) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            let msg = error.map { ($0 as Error).localizedDescription } ?? "unknown"
            tlsDelLog.error("TLS trust eval failed: \(msg, privacy: .public)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
