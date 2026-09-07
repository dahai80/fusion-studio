import Foundation
import os.log

private let auditLog = Logger(subsystem: "com.fusion.studio", category: "ClusterAudit")

final class ClusterAuditor {
    static let shared = ClusterAuditor()

    private var logDir: String
    private let writeLock = NSLock()
    // B4: per-day file size cap + age retention.
    private let maxFileSize: Int64 = 50 * 1024 * 1024
    private let retentionDays: Int = 30

    init() {
        self.logDir = NSHomeDirectory() + "/.fusion-studio/logs"
        ensureDir()
        pruneOldLogs()
    }

    func overrideLogDir(_ dir: String) {
        self.logDir = dir
        ensureDir()
    }

    private func ensureDir() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        }
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: logDir)
    }

    private func actorName() -> String {
        let label = UserDefaults.standard.string(forKey: "clusterAuditActorLabel") ?? ""
        if !label.isEmpty { return label }
        return Host.current().localizedName ?? "unknown"
    }

    private func dateStampedPath() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone.current
        return logDir + "/cluster-audit-" + fmt.string(from: Date()) + ".log"
    }

    // B4: move oversized current-day file to a .N suffix before the next append.
    private func rotateLog(path: String) {
        var suffix = 1
        var rotated = path + ".1"
        while FileManager.default.fileExists(atPath: rotated) {
            suffix += 1
            rotated = path + ".\(suffix)"
        }
        try? FileManager.default.moveItem(atPath: path, toPath: rotated)
        auditLog.info("audit log rotated: \(path) -> \(rotated, privacy: .public)")
    }

    // B4: delete audit logs (current + rotated) older than retentionDays.
    private func pruneOldLogs() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: logDir) else { return }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        var pruned = 0
        for name in entries {
            guard name.hasPrefix("cluster-audit-") else { continue }
            guard name.hasSuffix(".log") || name.hasSuffix(".1") || name.hasSuffix(".2") else { continue }
            let full = logDir + "/" + name
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let mtime = attrs[.modificationDate] as? Date, mtime < cutoff {
                try? fm.removeItem(atPath: full)
                pruned += 1
            }
        }
        if pruned > 0 {
            auditLog.info("audit prune: removed \(pruned, privacy: .public) logs older than \(retentionDays) days")
        }
    }

    func record(action: String, targetNode: String?, targetTask: String?,
                result: String, idempotencyKey: String?, masterHost: String?) {
        let rec = AuditRecord(ts: Int(Date().timeIntervalSince1970),
                              actor: actorName(), action: action,
                              targetNode: targetNode, targetTask: targetTask,
                              result: result, idempotencyKey: idempotencyKey,
                              masterHost: masterHost)
        guard let data = try? JSONEncoder().encode(rec),
              var line = String(data: data, encoding: .utf8) else {
            auditLog.error("record encode failed for action=\(action, privacy: .public)")
            return
        }
        line += "\n"
        writeLock.lock(); defer { writeLock.unlock() }
        let path = dateStampedPath()
        // B4: rotate current day's file if it exceeds maxFileSize before appending.
        if FileManager.default.fileExists(atPath: path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64, size >= maxFileSize {
            rotateLog(path: path)
        }
        if !FileManager.default.fileExists(atPath: path) {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                _ = try? handle.seekToEnd()
                if let d = line.data(using: .utf8) { handle.write(d) }
                try? handle.close()
            }
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        auditLog.info("audit action=\(action, privacy: .public) result=\(result, privacy: .public) target=\(targetNode ?? targetTask ?? "-", privacy: .public)")
    }

    func tail(limit: Int) -> [AuditRecord] {
        let path = dateStampedPath()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return Self.parseRecords(text: text, limit: limit)
    }

    // ARCH-7 (审计product-0906 P2): tail 同步 Data(contentsOf:) 读盘, AuditTabView.reload() 在 MainActor
    // 直接调会阻塞主线程 (大审计日志/慢盘卡顿)。提供 async 版读盘移至 Task.detached, 解析复用 parseRecords。
    func tailAsync(limit: Int) async -> [AuditRecord] {
        let path = dateStampedPath()
        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let text = String(data: data, encoding: .utf8) else { return [] }
            return Self.parseRecords(text: text, limit: limit)
        }.value
    }

    nonisolated private static func parseRecords(text: String, limit: Int) -> [AuditRecord] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let suffix = lines.suffix(limit)
        var records: [AuditRecord] = []
        for line in suffix {
            if let d = line.data(using: .utf8),
               let rec = try? JSONDecoder().decode(AuditRecord.self, from: d) {
                records.append(rec)
            }
        }
        return records
    }
}
