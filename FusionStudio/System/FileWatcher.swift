// Callers: AgentStudioView for live reload, ProfilerView for file metrics, any view needing file change notifications.
// Affected API: FileWatcher ObservableObject (published fileChanges stream, start/stop methods).
// Data schemas: FileChangeEvent, DebounceTier enum.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import Foundation
import CoreServices
import Combine
import os.log

struct FileChangeEvent {
    let path: String
    let flags: FSEventStreamEventFlags
    let timestamp: Date
}

enum DebounceTier: String {
    case tier1_debounce
    case tier2_astDiff
    case tier3_llmGate

    var interval: TimeInterval {
        switch self {
        case .tier1_debounce:
            return 0.3
        case .tier2_astDiff:
            return 1.0
        case .tier3_llmGate:
            return 3.0
        }
    }
}

extension Notification.Name {
    static let fileWatcherDidChange = Notification.Name("fileWatcherDidChange")
}

private func fileWatcherCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: size_t,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] else {
        return
    }
    for i in 0..<numEvents {
        let path = paths[i]
        // F-R11: 路径过滤 — 排除 .git/.build/node_modules/.swp/.DS_Store 等噪音目录/临时文件。
        // 旧实现全量 post, 大仓库 git checkout 产生数千 .git/ 对象 FSEvents 打满主线程致 UI 冻结。
        if fileWatcherShouldPropagatePath(path) == false { continue }
        let flags = eventFlags[i]
        let userInfo: [String: Any] = [
            "path": path,
            "flags": NSNumber(value: flags),
            "timestamp": Date()
        ]
        NotificationCenter.default.post(
            name: .fileWatcherDidChange,
            object: nil,
            userInfo: userInfo
        )
    }
}

/// F-R11: 判断路径是否应向上传播。排除版本控制/构建产物/依赖/临时文件噪音。
private func fileWatcherShouldPropagatePath(_ path: String) -> Bool {
    let excludedComponents: Set<String> = [".git", ".build", "node_modules", "DerivedData", ".swiftpm"]
    let excludedSuffixes: [String] = [".swp", ".swo", ".DS_Store", ".tmp", ".log"]
    let comps = path.split(separator: "/")
    for comp in comps {
        let s = String(comp)
        if excludedComponents.contains(s) { return false }
    }
    for suf in excludedSuffixes where path.hasSuffix(suf) { return false }
    return true
}

@MainActor
class FileWatcher: ObservableObject {
    @Published var fileChanges: [FileChangeEvent] = []
    @Published var isWatching: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "FileWatcher")
    // 审计0902 E5 (P2): stream/notificationObserver/debounceTimers 在 deinit (nonisolated) 与
    //   stopWatching (main) 并发访问 → double-release/use-after-invalidate 崩溃。用 NSLock 串行化
    //   生命周期, deinit 与 stopWatching 共用 nonisolated teardownStream() 持锁释放。FSEventStream/
    //   removeObserver 本身线程安全, 但需防 deinit 与 stopWatching 各释放一次 (double-release)。
    private let lifecycleLock = NSLock()
    // nonisolated(unsafe): deinit/teardownStream nonisolated 持锁访问 (lifecycleLock 串行化), 跨 @MainActor 边界。
    nonisolated(unsafe) private var stream: FSEventStreamRef?
    private var lastEvents: [String: Date] = [:]
    nonisolated(unsafe) private var debounceTimers: [String: Task<Void, Never>] = [:]
    nonisolated(unsafe) private var notificationObserver: NSObjectProtocol?

    deinit {
        teardownStream()
    }

    // nonisolated: deinit 非 @MainActor 调用, 持锁释放 CF 资源 (线程安全) + 取消 observer/timers。
    private nonisolated func teardownStream() {
        lifecycleLock.lock()
        let streamToRelease = stream
        let observerToRemove = notificationObserver
        let timersToCancel = debounceTimers
        stream = nil
        notificationObserver = nil
        debounceTimers.removeAll()
        lifecycleLock.unlock()
        if let observer = observerToRemove {
            NotificationCenter.default.removeObserver(observer)
        }
        if let stream = streamToRelease {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        for (_, timer) in timersToCancel {
            timer.cancel()
        }
    }

    func startWatching(paths: [String], latency: TimeInterval = 0.3) {
        guard stream == nil else {
            logger.warning("FileWatcher already active, ignoring startWatching call")
            return
        }

        logger.info("FileWatcher starting on paths: \(paths), latency: \(latency)")

        var context = FSEventStreamContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fileWatcherCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            CUnsignedInt(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            logger.error("Failed to create FSEventStream")
            return
        }

        FSEventStreamScheduleWithRunLoop(newStream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let started = FSEventStreamStart(newStream)
        guard started else {
            logger.error("Failed to start FSEventStream")
            FSEventStreamInvalidate(newStream)
            FSEventStreamRelease(newStream)
            return
        }

        stream = newStream
        isWatching = true
        logger.info("FSEventStream started successfully")

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .fileWatcherDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let path = notification.userInfo?["path"] as? String,
                  let flagsNum = notification.userInfo?["flags"] as? NSNumber,
                  let timestamp = notification.userInfo?["timestamp"] as? Date else {
                return
            }
            let event = FileChangeEvent(
                path: path,
                flags: FSEventStreamEventFlags(flagsNum.uint32Value),
                timestamp: timestamp
            )
            // 审计0902 E5 (P2): block 已在 queue:.main, 但 @Sendable 闭包需显式 MainActor.run 跳 @MainActor appendEvent。
            Task { @MainActor [weak self] in
                self?.appendEvent(event)
            }
        }
    }

    func stopWatching() {
        guard stream != nil else {
            logger.warning("FileWatcher not active, ignoring stopWatching call")
            return
        }

        logger.info("FileWatcher stopping")
        // 审计0902 E5 (P2): 与 deinit 共用 teardownStream (持锁释放), 杜绝 stopWatching 与 deinit 各释放一次。
        teardownStream()
        isWatching = false
        logger.info("FSEventStream stopped and released")
    }

    func shouldPropagate(event: FileChangeEvent, tier: DebounceTier) -> Bool {
        let key = "\(event.path)-\(tier)"
        let now = Date()
        if let lastDate = lastEvents[key] {
            let elapsed = now.timeIntervalSince(lastDate)
            if elapsed < tier.interval {
                logger.debug("Debounced event for \(event.path) at tier \(tier.rawValue), elapsed: \(elapsed)s")
                return false
            }
        }
        lastEvents[key] = now
        // 审计0902 A5 (P2): lastEvents 按 path-tier key 无淘汰, watch 大仓库 100k 路径 → 100k 键无界增长。
        //   达 2000 阈值时清过期 (>2x 最长 tier interval 60s 的旧条目), 保近期去重有效同时回收陈旧键。
        if lastEvents.count > 2000 {
            let cutoff = now.addingTimeInterval(-120)
            lastEvents = lastEvents.filter { $0.value > cutoff }
        }
        return true
    }

    // 审计0902 E5 (P2): notificationObserver block 在 queue:.main 触发 → appendEvent 本在主线程。
    //   旧 nonisolated + MainActor.assumeIsolated 是脆弱契约 (FSEventStream 改调度即 trap)。
    //   改 @MainActor 显式隔离, 编译器静态保证主线程, 不依赖运行时 assume。
    @MainActor
    private func appendEvent(_ event: FileChangeEvent) {
        self.fileChanges.append(event)
        if self.fileChanges.count > 500 {
            self.fileChanges.removeFirst(self.fileChanges.count - 500)
        }
    }
}
