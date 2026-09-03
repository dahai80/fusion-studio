import Foundation
import os.log

private let auditLog = Logger(subsystem: "com.fusion.studio", category: "ClusterAudit")

final class ClusterAuditor {
    static let shared = ClusterAuditor()

    private var logDir: String
    private let writeLock = NSLock()

    init() {
        self.logDir = NSHomeDirectory() + "/.fusion-studio/logs"
        ensureDir()
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
