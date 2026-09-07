import Foundation
import os.log

private let transportLog = Logger(subsystem: "com.fusion.studio", category: "ClusterTransport")

final class ClusterTransport {
    static let shared = ClusterTransport()

    let session: URLSession
    private let delegate: ClusterTLSDelegate

    private init() {
        self.delegate = ClusterTLSDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        delegate.clientIdentity = ClusterMTLSStore.shared.loadClientIdentity()
        let hasIdentity = delegate.clientIdentity != nil
        transportLog.info("ClusterTransport init (TLS delegate attached, mTLS identity=\(hasIdentity, privacy: .public))")
    }

    // mTLS 客户端证书导入/删除后重新加载 SecIdentity 到 delegate.
    func reloadClientIdentity() {
        delegate.clientIdentity = ClusterMTLSStore.shared.loadClientIdentity()
        let hasIdentity = delegate.clientIdentity != nil
        transportLog.info("ClusterTransport mTLS identity reloaded (has identity=\(hasIdentity, privacy: .public))")
    }
}
