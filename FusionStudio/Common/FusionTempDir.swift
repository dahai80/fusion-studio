// F-I6: 统一临时目录管理。审计: 各 Bridge (Design/Coder) 临时文件散落系统 NSTemporaryDirectory
// (/tmp), 无统一目录, 无启动清理, 无大小上限。崩溃 (F-R7 永挂强杀 / F-R13 OOM) 时 defer 清理跑不到,
// 残留累积占盘 + 文件名含项目路径可能泄露。本 helper 收口: 统一 ~/.fusion-studio/tmp/ (0700) +
// 文件 0600 + UUID 命名 + 启动清理陈旧 + LRU 总大小上限。
// Callers: DesignBridge/DesignWorkflowOrchestrator/EcosystemSyncPanel 临时文件 + FusionStudioApp 启动清理。
import Foundation
import os.log

// F-I6: 临时文件目录统一收口。原各 Bridge 直接 NSTemporaryDirectory() 散落系统 /tmp, 改走本类。
final class FusionTempDir {
    static let shared = FusionTempDir()

    private let logger = Logger(subsystem: "com.fusion.studio", category: "TempDir")
    // 统一目录 ~/.fusion-studio/tmp/, 与 chats/projects/skills 等应用数据同根 (NSHomeDirectory 模式)。
    private let rootDir = NSHomeDirectory() + "/.fusion-studio/tmp"
    // LRU 总大小上限 200MB。超限按最旧 mtime 清理至阈值以下, 防 /tmp 堆数 GB 残留。
    private let maxTotalBytes: Int = 200 * 1024 * 1024
    // 启动清理: 清 mtime > 3 天陈旧文件 (对齐 macOS /tmp 默认 3 天清理周期, 但本目录不被系统清, 需自管)。
    private let staleDays: Double = 3

    private init() {}

    // 返回统一临时目录路径, 懒建 (0700 受限权限, 防 /tmp 公共区窥探)。
    var path: String {
        ensureDir()
        return rootDir
    }

    // 在统一目录下生成 UUID 命名临时文件路径 (不创建文件, 仅返路径, 0600 由写入方设)。
    // prefix 标识来源 (fd_lint/fd_diff/fd_export/fd_screenshot/fd_eco_export 等), 便于日志追溯。
    func tmpFilePath(prefix: String, ext: String = "json") -> String {
        ensureDir()
        let name = "\(prefix)_\(UUID().uuidString).\(ext)"
        return rootDir + "/" + name
    }

    // 写入字节数据到统一目录临时文件, 自动 0600 权限 + 返回路径。调用方用完调 removeItem。
    func writeTmpFile(prefix: String, ext: String = "json", contents: Data) -> String? {
        let p = tmpFilePath(prefix: prefix, ext: ext)
        guard FileManager.default.createFile(atPath: p, contents: contents) else {
            logger.error("F-I6 writeTmpFile create failed prefix=\(prefix, privacy: .public) path=\(p, privacy: .public)")
            return nil
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: p)
        return p
    }

    // 启动清理: 清陈旧 (> staleDays) 文件 + LRU 总大小超限清理。FusionStudioApp.onAppear 调一次。
    func cleanupStale() {
        ensureDir()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: rootDir) else { return }
        let now = Date()
        var files: [(path: String, attrs: [FileAttributeKey: Any])] = []
        var totalBytes = 0
        for name in entries {
            let full = rootDir + "/" + name
            guard let attrs = try? fm.attributesOfItem(atPath: full) else { continue }
            files.append((full, attrs))
            if let size = attrs[.size] as? Int { totalBytes += size }
        }
        // 阶段1: 清陈旧 (> staleDays 天)。
        var removedStale = 0
        var kept: [(path: String, attrs: [FileAttributeKey: Any])] = []
        for f in files {
            let mtime = f.attrs[.modificationDate] as? Date ?? now
            if now.timeIntervalSince(mtime) > staleDays * 86400 {
                try? fm.removeItem(atPath: f.path)
                removedStale += 1
                if let s = f.attrs[.size] as? Int { totalBytes -= s }
            } else {
                kept.append(f)
            }
        }
        if removedStale > 0 {
            logger.info("F-I6 cleanupStale: removed \(removedStale) stale files (>\(Int(self.staleDays))d)")
        }
        // 阶段2: LRU 总大小超限 → 按 mtime 最旧先清至阈值下。
        if totalBytes > maxTotalBytes {
            kept.sort { ($0.attrs[.modificationDate] as? Date ?? now) < ($1.attrs[.modificationDate] as? Date ?? now) }
            var removedLRU = 0
            for f in kept {
                if totalBytes <= maxTotalBytes { break }
                try? fm.removeItem(atPath: f.path)
                if let s = f.attrs[.size] as? Int { totalBytes -= s }
                removedLRU += 1
            }
            if removedLRU > 0 {
                logger.warning("F-I6 cleanupStale: LRU evicted \(removedLRU) files, total now \(totalBytes / 1024)KB (cap \(self.maxTotalBytes / 1024)KB)")
            }
        }
    }

    private func ensureDir() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: rootDir) else { return }
        try? fm.createDirectory(atPath: rootDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        logger.info("F-I6 ensured tmp dir: \(self.rootDir, privacy: .public)")
    }
}
