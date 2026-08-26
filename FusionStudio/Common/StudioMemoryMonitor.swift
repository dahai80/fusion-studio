// F-R13: 进程内 RSS/phys_footprint 监控。旧实现零内存监控, @Published 无界 + 长会话 OOM 静默崩溃无告警。
// 本监控周期采样本进程 phys_footprint (Apple Silicon 统一内存真实占用), 超软阈值告警 + 日志, 不阻断运行。
// critical 阈值触发注册的 eviction 回调 (清 @Published 无界数组 LRU), 防 OOM。
// Callers: FusionStudioApp 启动 start(), HardwareMonitorView 读 currentRSSMB。
import Foundation
import os.log

@MainActor
final class StudioMemoryMonitor: ObservableObject {
    static let shared = StudioMemoryMonitor()

    @Published private(set) var currentRSSMB: Double = 0
    @Published private(set) var peakRSSMB: Double = 0
    @Published private(set) var warningLevel: WarningLevel = .normal
    @Published private(set) var lastEvictionTriggeredMB: Double = 0

    // Apple Silicon 统一内存, studio 单进程软阈值。审计: 2GB 警告, 3GB 自动清理。
    enum WarningLevel: String {
        case normal
        case high      // > 2 GB 警告
        case critical  // > 3 GB 自动清理
    }

    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryMonitor")
    private var sampleTask: Task<Void, Never>?
    private let softLimitMB: Double = 2000
    private let criticalLimitMB: Double = 3000
    private var lastWarnedLevel: WarningLevel = .normal

    // F-R13: eviction 回调注册表。各持有 @Published 无界数组的 owner 注册清 LRU 闭包,
    // critical 阈值触发全部调一遍。闭包返回释放条目数, 便于日志统计。
    private var evictionHandlers: [(String, () -> Int)] = []

    private init() {}

    /// 注册内存压力 eviction 回调。name 标识来源 (日志), handler 清无界 @Published 数组 LRU 返回释放条目数。
    func registerEviction(name: String, _ handler: @escaping () -> Int) {
        evictionHandlers.append((name, handler))
        logger.info("eviction handler registered: \(name, privacy: .public)")
    }

    func start(intervalSeconds: UInt64 = 10) {
        guard sampleTask == nil else { return }
        sampleTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            }
        }
        logger.info("StudioMemoryMonitor started interval=\(intervalSeconds)s")
    }

    func stop() {
        sampleTask?.cancel()
        sampleTask = nil
    }

    private func sample() {
        let rss = physFootprintBytes()
        let mb = rss / (1024 * 1024)
        currentRSSMB = mb
        if mb > peakRSSMB { peakRSSMB = mb }

        let level: WarningLevel
        if mb >= criticalLimitMB {
            level = .critical
        } else if mb >= softLimitMB {
            level = .high
        } else {
            level = .normal
        }
        warningLevel = level

        // 仅在跨级时告警, 避免每 10s 刷屏
        if level != lastWarnedLevel {
            switch level {
            case .critical:
                logger.error("RSS CRITICAL: \(Int(mb))MB >= \(Int(self.criticalLimitMB))MB, 触发 eviction 清无界 @Published 数组")
            case .high:
                logger.warning("RSS HIGH: \(Int(mb))MB >= \(Int(self.softLimitMB))MB, 关注内存增长")
            case .normal:
                logger.info("RSS 回落到正常: \(Int(mb))MB")
            }
            lastWarnedLevel = level
        }

        // F-R13: critical 阈值触发 eviction (每次 sample 达 critical 都清, 非仅跨级 — 压力持续就持续清)。
        if level == .critical {
            triggerEviction(atMB: mb)
        }
    }

    private func triggerEviction(atMB mb: Double) {
        guard !evictionHandlers.isEmpty else { return }
        lastEvictionTriggeredMB = mb
        var totalFreed = 0
        for (name, handler) in evictionHandlers {
            let freed = handler()
            totalFreed += freed
            if freed > 0 {
                logger.info("eviction \(name, privacy: .public): freed \(freed) entries")
            }
        }
        if totalFreed > 0 {
            logger.warning("RSS eviction triggered at \(Int(mb))MB, total freed \(totalFreed) entries across \(self.evictionHandlers.count) handlers")
        }
    }

    // mach_task_basic_info.resident_size = RSS (物理驻留页)。
    private nonisolated func physFootprintBytes() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size)
    }
}
