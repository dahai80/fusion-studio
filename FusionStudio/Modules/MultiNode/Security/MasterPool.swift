import Foundation
import os.log

private let poolLog = Logger(subsystem: "com.fusion.studio", category: "MasterPool")

final class MasterPool {
    static let shared = MasterPool()

    private var endpoints: [ClusterEndpoint] = []
    private var activeIndex: Int = 0
    private let lock = NSLock()
    // B3: failover cycle cap. advance() cycles masters on failure; once it has cycled
    // through every endpoint without recovery, stop churning (return nil). Reset on
    // successful health probe via markRecovered().
    private var advanceCount: Int = 0
    private var allMastersDown: Bool = false
    var poolExhausted: Bool { allMastersDown }

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
        if allMastersDown {
            poolLog.error("pool exhausted: cycled all \(self.endpoints.count) masters with no recovery")
            return nil
        }
        advanceCount += 1
        if advanceCount >= endpoints.count {
            allMastersDown = true
            poolLog.error("failover exhausted: cycled \(self.advanceCount) times across \(self.endpoints.count) masters, all unreachable")
            return nil
        }
        activeIndex = (activeIndex + 1) % endpoints.count
        poolLog.info("failover advance -> \(self.endpoints[self.activeIndex].host, privacy: .public) (count=\(self.advanceCount))")
        return endpoints[activeIndex]
    }

    // B3: clear cycle cap on successful health probe so failover can resume after recovery.
    func markRecovered() {
        lock.lock(); defer { lock.unlock() }
        advanceCount = 0
        allMastersDown = false
        poolLog.info("pool recovered: cycle cap cleared")
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        activeIndex = 0
        poolLog.info("pool reset to index 0")
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        // 审计0907 P2-8: master list 旧明文存 UserDefaults.standard, 改 0600 文件。
        let csv = KeychainStore.readMasterList()
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
