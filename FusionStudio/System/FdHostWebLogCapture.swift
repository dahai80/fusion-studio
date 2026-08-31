// Callers: DesignCanvasView (log_capture_dump event persist), FusionStudioApp (foreground trigger),
//   DesignBridge.dumpWasmLog (manual/crash trigger).
// Affected API: FdHostWebLogCapture.shared.persist(entries:timestamp:), triggerForegroundDump().
// Data schemas: fd-host-web-log envelope {schema, schema_version, captured_at_ms, entry_count, entries[]},
//   entry = LogEntry {level:"error"|"warn", ts_ms:f64, msg:String} (fusion-design lib.rs:103).
// User instruction: #372 OPS-13 — consume fd-host-web log.capture.dump, persist WASM runtime log ring.

import Foundation
import os.log

// #372 OPS-13: 消费 fd-host-web log.capture.dump 桥, 将 WASM 运行时日志环形缓冲
// 持久化到 ~/Library/Logs/fusion-studio/fd-host-web-<ts>.json, 供企业运维诊断。
// WASM 沙箱无文件系统, 环形缓冲 (容量 200, error/warn) 是唯一外排路径, 无 Swift 消费者则死端。
// 触发: 手动按钮 (DesignLintPanel) / WebView 进程崩溃恢复 / App 进入前台 (5min 节流)。
final class FdHostWebLogCapture {
    static let shared = FdHostWebLogCapture()

    private let logger = Logger(subsystem: "com.fusion.studio", category: "FdHostWebLogCapture")

    // 日志目录 ~/Library/Logs/fusion-studio/, 对齐 fusion-design 文件日志目录约定。
    private let logDir: String = {
        let home = NSHomeDirectory()
        return home + "/Library/Logs/fusion-studio"
    }()

    // 单条 msg 截断上限, 防巨型日志撑爆磁盘 + 序列化 OOM。
    private let maxMsgChars = 8192

    // 前台自动 dump 节流: 5 分钟内不重复, 避免写放大。
    private let foregroundThrottleSecs: TimeInterval = 300
    private var lastForegroundDump: Date = .distantPast

    // 测试注入钩子 (internal 供 @testable)。
    internal func resetThrottleForTest() { lastForegroundDump = .distantPast }
    internal func markForegroundDumped() { lastForegroundDump = Date() }

    private init() {}

    // 持久化 entries 到磁盘, 返回文件路径 (失败/空 nil)。
    // timestamp 由调用方传入 (测试可注入; 生产用 Int64(Date().timeIntervalSince1970*1000))。
    func persist(entries: [[String: Any]], timestamp: Int64) -> String? {
        guard !entries.isEmpty else {
            logger.info("FdHostWebLogCapture: persist skipped, 0 entries")
            return nil
        }
        ensureLogDir()
        // 截断超长 msg, 保留诊断价值同时防磁盘膨胀。
        let capped: [[String: Any]] = entries.map { e in
            var m = e
            if let msg = m["msg"] as? String, msg.count > maxMsgChars {
                m["msg"] = String(msg.prefix(maxMsgChars)) + "...[truncated]"
            }
            return m
        }
        let envelope: [String: Any] = [
            "schema": "fd-host-web-log",
            "schema_version": 1,
            "captured_at_ms": timestamp,
            "entry_count": capped.count,
            "entries": capped
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]) else {
            logger.error("FdHostWebLogCapture: serialize failed for \(capped.count) entries")
            return nil
        }
        let path = logDir + "/fd-host-web-\(timestamp).json"
        guard FileManager.default.createFile(atPath: path, contents: data) else {
            logger.error("FdHostWebLogCapture: create file failed path=\(path, privacy: .public)")
            return nil
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        logger.info("FdHostWebLogCapture: persisted \(capped.count) entries to \(path, privacy: .public)")
        return path
    }

    // 前台触发节流检查。
    func canForegroundDump() -> Bool {
        Date().timeIntervalSince(lastForegroundDump) >= foregroundThrottleSecs
    }

    // 前台触发 dump: 节流通过则标记 + 返回 true (调用方据此发 dump 请求)。
    @discardableResult
    func triggerForegroundDump() -> Bool {
        guard canForegroundDump() else {
            logger.info("FdHostWebLogCapture: foreground dump throttled")
            return false
        }
        markForegroundDumped()
        return true
    }

    private func ensureLogDir() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: logDir) else { return }
        try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        logger.info("FdHostWebLogCapture: ensured log dir \(self.logDir, privacy: .public)")
    }
}
