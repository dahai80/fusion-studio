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
            SecTrustSetAnchorCertificatesOnly(serverTrust, false)
            tlsDelLog.info("TLS eval with \(pinned.count, privacy: .public) pinned anchors + system roots")
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
