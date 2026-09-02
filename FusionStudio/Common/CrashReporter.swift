// Callers: FusionStudioApp.init (opt-in gate via FusionConfig.enableCrashTelemetry).
// Affected API: CrashReporter.shared.start() — installs uncaught-exception handler + MetricKit subscriber.
// Data schemas: crash-<timestamp>.log under ~/.fusion-studio/logs/ (0700 dir, 0600 file).
// F-ops-8: zero-dependency local crash telemetry (NSSetUncaughtExceptionHandler + MetricKit MXCrashDiagnostic).
//   Opt-in only (Settings toggle, default OFF). No network upload — local file only.

import Foundation
import MetricKit
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
        installMetricKitSubscriber()
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

    // MARK: - MetricKit (MXCrashDiagnostic — system crash reports next launch)

    private func installMetricKitSubscriber() {
        MXMetricManager.shared.add(self)
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
}

// MARK: - MXMetricManagerSubscriber

extension CrashReporter: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // 性能指标非崩溃, 此处不落盘 (F-ops-8 仅捕获崩溃)。
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashDiags = payload.crashDiagnostics ?? []
            for diag in crashDiags {
                // F-ops-8: MXCallStackTree 仅暴露 JSONRepresentation, 无法逐帧遍历。
                // 落盘整棵调用树 JSON, 供离线符号化 (binaryName/UUID/offset 全在内)。
                let stackJSON = String(data: diag.callStackTree.jsonRepresentation(), encoding: .utf8) ?? "(unavailable stack json)"
                CrashReporter.shared.writeCrash(
                    kind: "MXCrashDiagnostic",
                    name: diag.terminationReason ?? "(no termination reason)",
                    reason: "signal=\(diag.signal?.stringValue ?? "?") exceptionType=\(diag.exceptionType?.stringValue ?? "?")",
                    stack: ["<callStackTree JSON>", stackJSON]
                )
            }
        }
    }
}
