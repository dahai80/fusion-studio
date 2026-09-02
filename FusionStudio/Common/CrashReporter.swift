// Callers: FusionStudioApp.init (opt-in gate via FusionConfig.enableCrashTelemetry).
// Affected API: CrashReporter.shared.start() — installs uncaught-exception handler + POSIX signal handlers.
// Data schemas: crash-<timestamp>.log under ~/.fusion-studio/logs/ (0700 dir, 0600 file).
// F-ops-8: zero-dependency local crash telemetry.
//   Opt-in only (Settings toggle, default OFF). No network upload — local file only.
//   捕获路径: NSSetUncaughtExceptionHandler (NSException/Swift fatalError bridge) +
//   POSIX signal() (SIGABRT/SIGILL/SIGSEGV/SIGBUS/SIGFPE/SIGPIPE/SIGTRAP)。
//   注: 不用 MetricKit — MXMetricPayload 在 macOS 标 unavailable (iOS-only), CI macOS-14 拒编。

import Foundation
import os.log

private let crashLog = Logger(subsystem: "com.fusion.studio", category: "CrashReporter")

// MARK: - CrashReporter

final class CrashReporter: NSObject {
    static let shared = CrashReporter()

    private let logDir: String
    private var started = false

    private override init() {
        let home = NSHomeDirectory()
        self.logDir = home + "/.fusion-studio/logs"
        super.init()
    }

    // 启动崩溃捕获。仅在 FusionConfig.enableCrashTelemetry == true 时调用 (opt-in)。
    func start() {
        guard !started else { return }
        started = true
        ensureLogDir()
        installUncaughtExceptionHandler()
        installSignalHandlers()
        crashLog.info("F-ops-8: crash reporter started, logDir=\(self.logDir, privacy: .public)")
    }

    // MARK: - Log directory

    private func ensureLogDir() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            do {
                try fm.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            } catch {
                crashLog.error("F-ops-8: create logDir failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Uncaught exception (NSException / Swift fatalError bridged)

    private func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.writeCrash(
                kind: "UncaughtNSException",
                name: exception.name.rawValue,
                reason: exception.reason ?? "(no reason)",
                stack: exception.callStackSymbols
            )
        }
    }

    // MARK: - POSIX signal handlers (致命信号 → 落盘后重抛默认处理让进程崩)

    private func installSignalHandlers() {
        let fatalSignals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGBUS, SIGFPE, SIGPIPE, SIGTRAP]
        for sig in fatalSignals {
            signal(sig) { rawSig in
                let name: String
                switch rawSig {
                case SIGABRT: name = "SIGABRT"
                case SIGILL: name = "SIGILL"
                case SIGSEGV: name = "SIGSEGV"
                case SIGBUS: name = "SIGBUS"
                case SIGFPE: name = "SIGFPE"
                case SIGPIPE: name = "SIGPIPE"
                case SIGTRAP: name = "SIGTRAP"
                default: name = "SIG\(rawSig)"
                }
                // signal handler 上下文禁用大多数 API; 仅调 async-signal-safe 写盘。
                CrashReporter.shared.writeCrashFromSignal(
                    signalName: name,
                    stack: Thread.callStackSymbols
                )
                // 恢复默认处置并重发, 让进程按原行为终止 (不吞崩溃)。
                signal(rawSig, SIG_DFL)
                raise(rawSig)
            }
        }
    }

    // MARK: - Write

    func writeCrash(kind: String, name: String, reason: String, stack: [String]) {
        let fm = FileManager.default
        let ts = Int(Date().timeIntervalSince1970)
        let path = logDir + "/crash-\(ts).log"
        var lines: [String] = []
        lines.append("=== Fusion Studio crash report ===")
        lines.append("kind: \(kind)")
        lines.append("name: \(name)")
        lines.append("reason: \(reason)")
        lines.append("timestamp: \(ts)")
        lines.append("--- stack ---")
        lines.append(contentsOf: stack)
        lines.append("=== end ===\n")
        let content = lines.joined(separator: "\n")
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            crashLog.error("F-ops-8: crash report written to \(path, privacy: .public)")
        } catch {
            crashLog.error("F-ops-8: write crash report failed: \(error.localizedDescription)")
        }
    }

    // signal handler 专用落盘: 最小依赖, 不记 os_log (非 async-signal-safe)。
    func writeCrashFromSignal(signalName: String, stack: [String]) {
        let ts = Int(Date().timeIntervalSince1970)
        let path = logDir + "/crash-\(ts).log"
        var lines: [String] = []
        lines.append("=== Fusion Studio crash report ===")
        lines.append("kind: FatalSignal")
        lines.append("signal: \(signalName)")
        lines.append("timestamp: \(ts)")
        lines.append("--- stack ---")
        lines.append(contentsOf: stack)
        lines.append("=== end ===\n")
        let content = lines.joined(separator: "\n")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }
}
