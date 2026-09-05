import Foundation
import os.log

private let poolLog = Logger(subsystem: "com.fusion.studio", category: "MasterPool")

final class MasterPool {
    static let shared = MasterPool()

    private var endpoints: [ClusterEndpoint] = []
    private var activeIndex: Int = 0
    private let lock = NSLock()

    private init() {
        reload()
    }

    init(csv: String) {
        self.endpoints = ClusterEndpoint.parse(csv)
        self.activeIndex = 0
    }

    var active: ClusterEndpoint? {
        lock.lock(); defer { lock.unlock() }
        if !endpoints.isEmpty {
            return endpoints[activeIndex]
        }
        // legacy fallback: single endpoint from FusionConfig
        let cfg = FusionConfig.shared
        guard let url = URL(string: cfg.multiNodeBaseURL),
              let host = url.host, let port = url.port else { return nil }
        return ClusterEndpoint(host: host, port: port)
    }

    func advance() -> ClusterEndpoint? {
        lock.lock(); defer { lock.unlock() }
        guard !endpoints.isEmpty else {
            // NSLock non-reentrant: do NOT call self.active here (it re-locks → self-deadlock).
            // Mirror the legacy fallback inline under the held lock.
            let cfg = FusionConfig.shared
            guard let url = URL(string: cfg.multiNodeBaseURL),
                  let host = url.host, let port = url.port else { return nil }
            return ClusterEndpoint(host: host, port: port)
        }
        activeIndex = (activeIndex + 1) % endpoints.count
        poolLog.info("failover advance -> \(self.endpoints[self.activeIndex].host, privacy: .public)")
        return endpoints[activeIndex]
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        activeIndex = 0
        poolLog.info("pool reset to index 0")
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        let csv = UserDefaults.standard.string(forKey: "multiNodeMasterList") ?? ""
        let parsed = ClusterEndpoint.parse(csv)
        if parsed != endpoints {
            endpoints = parsed
            activeIndex = 0
            poolLog.info("pool reloaded: \(self.endpoints.count, privacy: .public) endpoints")
        }
    }

    var endpointCount: Int {
        lock.lock(); defer { lock.unlock() }
        return endpoints.count
    }
}
