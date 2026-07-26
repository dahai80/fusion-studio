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

@MainActor
class FileWatcher: ObservableObject {
    @Published var fileChanges: [FileChangeEvent] = []
    @Published var isWatching: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "FileWatcher")
    private var stream: FSEventStreamRef?
    private var lastEvents: [String: Date] = [:]
    private var debounceTimers: [String: Task<Void, Never>] = [:]
    private var notificationObserver: NSObjectProtocol?

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
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
            self.appendEvent(event)
        }
    }

    func stopWatching() {
        guard let stream = stream else {
            logger.warning("FileWatcher not active, ignoring stopWatching call")
            return
        }

        logger.info("FileWatcher stopping")

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isWatching = false

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }

        for (_, timer) in debounceTimers {
            timer.cancel()
        }
        debounceTimers.removeAll()

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
        return true
    }

    nonisolated private func appendEvent(_ event: FileChangeEvent) {
        MainActor.assumeIsolated {
            self.fileChanges.append(event)
            if self.fileChanges.count > 500 {
                self.fileChanges.removeFirst(self.fileChanges.count - 500)
            }
        }
    }
}
