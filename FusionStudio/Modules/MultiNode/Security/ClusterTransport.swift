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
        transportLog.info("ClusterTransport init (TLS delegate attached)")
    }
}
