// Callers: FusionStudioApp for sandbox lifecycle, SecurityService for policy enforcement, SettingsView for config UI.
// Affected API: SandboxManager ObservableObject (published sandbox state + policy methods).
// Data schemas: SandboxPolicy, NetworkRule, ResourceQuota, SandboxViolation.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import Foundation
import Combine
import os.log

struct NetworkRule: Codable, Identifiable {
    var id: UUID = UUID()
    let host: String
    let port: Int
    let direction: Direction

    enum Direction: String, Codable, CaseIterable { case outbound, inbound }
}

struct ResourceQuota: Codable {
    var maxMemoryMB: Int = 512
    var maxCpuPercent: Int = 50
    var maxDiskMB: Int = 256
    var maxProcesses: Int = 8
    var timeoutSeconds: Int = 300
}

struct SandboxPolicy: Codable {
    var allowNetwork: Bool = false
    var allowedHosts: [NetworkRule] = []
    var allowFileSystem: Bool = true
    var allowedPaths: [String] = []
    var deniedPaths: [String] = ["/System", "/private/var"]
    var quota: ResourceQuota = ResourceQuota()
    var allowAppleEvents: Bool = false
    var allowPrinting: Bool = false
}

@MainActor
class SandboxManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var policy: SandboxPolicy = SandboxPolicy()
    @Published var violations: [SandboxViolation] = []
    @Published var networkWhitelist: [NetworkRule] = []

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SandboxManager")
    private var sandboxProcess: Process?
    private let maxViolations = 200

    struct SandboxViolation: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: ViolationType
        let detail: String

        enum ViolationType: String {
            case networkBlocked, fileDenied, quotaExceeded, processLimit, timeout
        }
    }

    func activateSandbox() {
        guard !isActive else { return }
        logger.info("Activating sandbox with policy")
        isActive = true
        logger.info("Sandbox activated — network=\(self.policy.allowNetwork), fs=\(self.policy.allowFileSystem)")
    }

    func deactivateSandbox() {
        guard isActive else { return }
        sandboxProcess?.terminate()
        sandboxProcess = nil
        isActive = false
        logger.info("Sandbox deactivated")
    }

    func updatePolicy(_ newPolicy: SandboxPolicy) {
        policy = newPolicy
        networkWhitelist = newPolicy.allowedHosts
        logger.info("Sandbox policy updated — network=\(newPolicy.allowNetwork), allowedHosts=\(newPolicy.allowedHosts.count)")
    }

    func addNetworkRule(_ rule: NetworkRule) {
        if policy.allowedHosts.contains(where: { $0.host == rule.host && $0.port == rule.port }) { return }
        policy.allowedHosts.append(rule)
        networkWhitelist = policy.allowedHosts
        logger.info("Added network rule: \(rule.host):\(rule.port) \(rule.direction.rawValue)")
    }

    func removeNetworkRule(id: UUID) {
        policy.allowedHosts.removeAll { $0.id == id }
        networkWhitelist = policy.allowedHosts
        logger.info("Removed network rule \(id)")
    }

    func isNetworkAllowed(host: String, port: Int) -> Bool {
        if !policy.allowNetwork { return false }
        if policy.allowedHosts.isEmpty { return true }
        let match = policy.allowedHosts.contains { $0.host == host && ($0.port == 0 || $0.port == port) }
        if !match {
            recordViolation(.networkBlocked, detail: "Blocked \(host):\(port)")
        }
        return match
    }

    func isPathAllowed(_ path: String) -> Bool {
        if !policy.allowFileSystem { return false }
        for denied in policy.deniedPaths {
            if path.hasPrefix(denied) {
                recordViolation(.fileDenied, detail: "Denied access to \(path)")
                return false
            }
        }
        if policy.allowedPaths.isEmpty { return true }
        return policy.allowedPaths.contains { path.hasPrefix($0) }
    }

    func checkQuota(memoryMB: Int? = nil, cpuPercent: Int? = nil, processCount: Int? = nil) -> Bool {
        var ok = true
        if let mem = memoryMB, mem > policy.quota.maxMemoryMB {
            recordViolation(.quotaExceeded, detail: "Memory \(mem)MB > \(policy.quota.maxMemoryMB)MB")
            ok = false
        }
        if let cpu = cpuPercent, cpu > policy.quota.maxCpuPercent {
            recordViolation(.quotaExceeded, detail: "CPU \(cpu)% > \(policy.quota.maxCpuPercent)%")
            ok = false
        }
        if let procs = processCount, procs > policy.quota.maxProcesses {
            recordViolation(.processLimit, detail: "Processes \(procs) > \(policy.quota.maxProcesses)")
            ok = false
        }
        return ok
    }

    func buildSandboxProfile() -> String {
        var lines: [String] = []
        lines.append("(version 1)")
        lines.append("(deny default)")

        if policy.allowFileSystem {
            for path in policy.allowedPaths {
                lines.append("(allow file-read* (subpath \"\(path)\"))")
                lines.append("(allow file-write* (subpath \"\(path)\"))")
            }
            lines.append("(allow file-read* (subpath \"/usr\"))")
            lines.append("(allow file-read* (subpath \"/System/Library/Frameworks\"))")
            lines.append("(allow file-read* (subpath \"/Library\"))")
        }

        if policy.allowNetwork {
            if policy.allowedHosts.isEmpty {
                lines.append("(allow network*)")
            } else {
                for rule in policy.allowedHosts where rule.direction == .outbound {
                    lines.append("(allow network-outbound (host \"\(rule.host)\") (port \"\(rule.port)\"))")
                }
                for rule in policy.allowedHosts where rule.direction == .inbound {
                    lines.append("(allow network-inbound (host \"\(rule.host)\") (port \"\(rule.port)\"))")
                }
            }
        }

        if policy.allowAppleEvents {
            lines.append("(allow appleevent-send)")
        }
        if policy.allowPrinting {
            lines.append("(allow printing)")
        }

        lines.append("(deny signal)")
        lines.append("(deny process-exec (literal \"/usr/bin/killall\"))")
        return lines.joined(separator: "\n")
    }

    func launchInSandbox(executable: String, arguments: [String] = []) throws -> Process {
        let profilePath = NSTemporaryDirectory() + "fusion-sandbox-\(UUID().uuidString).sb"
        let profile = buildSandboxProfile()
        try profile.write(toFile: profilePath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        process.arguments = ["-p", profilePath, executable] + arguments
        self.sandboxProcess = process
        logger.info("Launched sandboxed process: \(executable) with profile at \(profilePath)")
        return process
    }

    private func recordViolation(_ type: SandboxViolation.ViolationType, detail: String) {
        let violation = SandboxViolation(timestamp: Date(), type: type, detail: detail)
        violations.append(violation)
        if violations.count > maxViolations { violations.removeFirst() }
        logger.warning("Sandbox violation: \(type.rawValue) — \(detail)")
    }
}
