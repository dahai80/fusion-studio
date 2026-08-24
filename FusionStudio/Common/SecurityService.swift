// Callers: ModuleDetailView routing.
// Affected API: SecurityService (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "落地2，1先等一等" — embed fusion-security + fusion-bench WebView into fusion-studio

import SwiftUI
import Foundation
import CommonCrypto

// MARK: - 安全检查级别

enum SecurityLevel: String, CaseIterable {
    case standard
    case high
    case maximum

    var description: String {
        switch self {
        case .standard: return I18nManager.shared.t(.secv_lvl_standard)
        case .high:     return I18nManager.shared.t(.secv_lvl_high)
        case .maximum:  return I18nManager.shared.t(.secv_lvl_maximum)
        }
    }
    var localizedName: String {
        switch self {
        case .standard: return I18nManager.shared.t(.secv_lvl_standard)
        case .high:     return I18nManager.shared.t(.secv_lvl_high)
        case .maximum:  return I18nManager.shared.t(.secv_lvl_maximum)
        }
    }
}

// MARK: - 安全事件

struct SecurityEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: EventType
    let message: String
    let severity: Severity
    let source: String

    enum EventType: String { case access, network, file, process, integrity }
    enum Severity: String { case info, warning, critical }
}

// MARK: - 安全管理器

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()

    @Published var securityLevel: SecurityLevel = .standard
    @Published var events: [SecurityEvent] = []
    @Published var fileAccessControl = true
    @Published var networkAccessControl = true
    @Published var integrityCheck = true

    // MARK: - 安全事件

    func logEvent(type: SecurityEvent.EventType, message: String, severity: SecurityEvent.Severity, source: String) {
        let event = SecurityEvent(timestamp: Date(), type: type, message: message, severity: severity, source: source)
        DispatchQueue.main.async {
            self.events.append(event)
            if self.events.count > 100 { self.events.removeFirst(self.events.count - 100) }
            self.objectWillChange.send()
        }
    }

    func clearEvents() { events.removeAll(); objectWillChange.send() }

    // MARK: - 安全检查函数

    func validateFilePath(_ path: String) -> Bool {
        let allowedPrefixes = [
            NSHomeDirectory() + "/.fusion-studio",
            NSHomeDirectory() + "/FusionStudio",
            NSHomeDirectory() + "/Downloads",
            NSHomeDirectory() + "/Documents",
            NSHomeDirectory() + "/Desktop",
            "/tmp",
        ]

        let resolved = (path as NSString).standardizingPath
        guard !resolved.contains("..") else { return false }

        for prefix in allowedPrefixes {
            if resolved.hasPrefix(prefix) { return true }
        }
        return false
    }

    func sanitizeInput(_ input: String) -> String {
        let dangerous = [";", "|", "&", "$", "`", "\\", ">", "<", "!", "\n", "\r"]
        var sanitized = input
        for char in dangerous { sanitized = sanitized.replacingOccurrences(of: char, with: "") }
        return sanitized
    }

    func verifyFileIntegrity(at path: String) -> (isValid: Bool, hash: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return (false, "") }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        let hexHash = hash.map { String(format: "%02x", $0) }.joined()
        return (true, hexHash)
    }
}

// MARK: - 安全面板

struct SecurityView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var bridge = SecurityBridge.shared
    @StateObject private var security = SecurityManager.shared
    @State private var selectedTab: SecurityTab = .dashboard

    enum SecurityTab: String, CaseIterable {
        case dashboard
        case projects
        case vulns
        case patch
        case gate
        case runtime

        var localizedName: String {
            switch self {
            case .dashboard: return I18nManager.shared.t(.secv_tab_dashboard)
            case .projects:  return I18nManager.shared.t(.secv_tab_projects)
            case .vulns:     return I18nManager.shared.t(.secv_tab_vulns)
            case .patch:     return I18nManager.shared.t(.secv_tab_patch)
            case .gate:      return I18nManager.shared.t(.secv_tab_gate)
            case .runtime:   return I18nManager.shared.t(.secv_tab_runtime)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                Text(I18nManager.shared.t(.secv_center))
                    .font(.headline)
                Spacer()
                if bridge.isConnected {
                    Label(I18nManager.shared.t(.secv_connected), systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundColor(.green)
                } else {
                    Label(I18nManager.shared.t(.secv_offline), systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(SecurityTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            UpstreamServiceStatusBanner(serviceId: "fusion-security")

            switch selectedTab {
            case .dashboard: SecOverviewTab()
            case .projects:  SecProjectsTab()
            case .vulns:     SecVulnsTab()
            case .patch:     SecPatchTab()
            case .gate:      SecGateTab()
            case .runtime:   SecRuntimeTab()
            }
        }
        .onAppear {
            bridge.checkHealth { ok in
                if ok {
                    bridge.fetchSystemInfo()
                    bridge.fetchDashboard()
                    bridge.fetchProjects()
                    bridge.fetchScans()
                    bridge.fetchVulnerabilities()
                    bridge.fetchVulnStats()
                    bridge.fetchPatches()
                    bridge.fetchRules()
                    bridge.fetchCustomRules()
                }
            }
        }
    }

    private func tabIcon(_ tab: SecurityTab) -> String {
        switch tab {
        case .dashboard: return "shield"
        case .projects:  return "folder.badge.gearshape"
        case .vulns:     return "exclamationmark.shield"
        case .patch:     return "wrench.and.screwdriver"
        case .gate:      return "checkmark.seal"
        case .runtime:   return "lock.shield"
        }
    }
}

// MARK: - 1. 安全概览

struct SecOverviewTab: View {
    @StateObject private var bridge = SecurityBridge.shared
    @Environment(\.studioTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let info = bridge.systemInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(I18nManager.shared.t(.secv_engine_info)).font(.caption).foregroundColor(.secondary)
                        Text("\(info.name ?? "Fusion-Security")  v\(info.version ?? "?")")
                            .font(.subheadline)
                        Text(I18nManager.shared.tf(.secv_platform_fmt, info.platform ?? "?", info.pythonVersion ?? "?"))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_total_scans), value: bridge.dashboard?.totalScans ?? 0, icon: "magnifyingglass", color: .blue)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_total_vulns), value: bridge.dashboard?.totalVulnerabilities ?? 0, icon: "exclamationmark.shield", color: .orange)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_projects), value: bridge.dashboard?.projectsCount ?? bridge.projects.count, icon: "folder", color: .green)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_critical), value: bridge.dashboard?.severityCounts?.critical ?? 0, icon: "flame.fill", color: .red)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_high), value: bridge.dashboard?.severityCounts?.high ?? 0, icon: "exclamationmark.triangle.fill", color: .orange)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_medium), value: bridge.dashboard?.severityCounts?.medium ?? 0, icon: "exclamationmark.circle.fill", color: .yellow)
                    SecStatCard(title: I18nManager.shared.t(.secv_stat_low), value: bridge.dashboard?.severityCounts?.low ?? 0, icon: "info.circle.fill", color: .gray)
                }

                if let rules = bridge.dashboard?.topRules, !rules.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(I18nManager.shared.t(.secv_top_rules)).font(.caption).foregroundColor(.secondary)
                        ForEach(Array(rules.prefix(5).enumerated()), id: \.offset) { _, rule in
                            HStack {
                                Text(rule.ruleId ?? "?").font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text("\(rule.count ?? 0)").font(.caption).foregroundColor(.orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                }

                if let err = bridge.lastError {
                    Text(err).font(.caption).foregroundColor(.red).padding(8)
                }
            }
            .padding()
        }
    }
}

struct SecStatCard: View {
    @Environment(\.studioTheme) private var theme
    let title: String; let value: Int; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text("\(value)").font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 2. 项目与扫描

struct SecProjectsTab: View {
    @StateObject private var bridge = SecurityBridge.shared
    @Environment(\.studioTheme) private var theme
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newPath = ""
    @State private var newStack = "python"
    @State private var scanProjectId: String?
    @State private var scanPath = ""
    @State private var useAi = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(I18nManager.shared.tf(.secv_projects_fmt, bridge.projects.count)).font(.headline)
                Spacer()
                Button { showCreate.toggle() } label: {
                    Label(I18nManager.shared.t(.secv_new_project), systemImage: "plus.circle")
                }.buttonStyle(.bordered).controlSize(.small)
            }.padding(8)

            if showCreate {
                VStack(spacing: 6) {
                    TextField(I18nManager.shared.t(.secv_project_name), text: $newName).textFieldStyle(.roundedBorder)
                    TextField(I18nManager.shared.t(.secv_local_path), text: $newPath).textFieldStyle(.roundedBorder)
                    HStack {
                        Picker(I18nManager.shared.t(.secv_tech_stack), selection: $newStack) {
                            ForEach(["python", "javascript", "typescript", "go", "rust", "java"], id: \.self) { Text($0) }
                        }.pickerStyle(.menu)
                        Spacer()
                        Button(I18nManager.shared.t(.secv_create)) {
                            bridge.createProject(name: newName, localPath: newPath, techStack: newStack) { _ in
                                bridge.fetchProjects()
                                newName = ""; newPath = ""; showCreate = false
                            }
                        }.buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(newName.isEmpty || newPath.isEmpty)
                    }
                }.padding(8).background(theme.surfaceSecondary).cornerRadius(8).padding(.horizontal, 8)
            }

            Divider()

            List {
                Section(I18nManager.shared.t(.secv_project_list)) {
                    ForEach(bridge.projects) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(p.name).font(.subheadline).fontWeight(.medium)
                                if let stack = p.techStack {
                                    Text(stack).font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                }
                                Spacer()
                                Button { scanProjectId = p.id; scanPath = p.localPath ?? "" } label: {
                                    Label(I18nManager.shared.t(.secv_scan), systemImage: "magnifyingglass")
                                }.buttonStyle(.bordered).controlSize(.mini)
                            }
                            if let path = p.localPath {
                                Text(path).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                }

                if let sid = scanProjectId {
                    Section(I18nManager.shared.tf(.secv_start_scan_fmt, bridge.projects.first(where: { $0.id == sid })?.name ?? sid)) {
                        TextField(I18nManager.shared.t(.secv_scan_path), text: $scanPath).textFieldStyle(.roundedBorder)
                        Toggle(I18nManager.shared.t(.secv_use_ai), isOn: $useAi)
                        HStack {
                            Button(I18nManager.shared.t(.secv_start_scan)) {
                                bridge.createScan(projectId: sid, path: scanPath, useAi: useAi) { _ in
                                    scanProjectId = nil
                                }
                            }.buttonStyle(.borderedProminent).controlSize(.small)
                            .disabled(bridge.isScanning || scanPath.isEmpty)
                            Button(I18nManager.shared.t(.secv_cancel)) { scanProjectId = nil }.buttonStyle(.bordered).controlSize(.small)
                            if bridge.isScanning { ProgressView().controlSize(.small) }
                        }
                    }
                }

                Section(I18nManager.shared.tf(.secv_scan_history_fmt, bridge.scans.count)) {
                    ForEach(bridge.scans) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(s.scanType ?? "scan").font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                Text(s.status).font(.caption).foregroundColor(secStatusColor(s.status))
                                Spacer()
                                if let total = s.totalVulnerabilities {
                                    Text(I18nManager.shared.tf(.secv_vulns_count_fmt, total)).font(.caption2).foregroundColor(.orange)
                                }
                            }
                            if let summary = s.summary {
                                Text(summary).font(.caption2).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func secStatusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "completed", "done", "success": return .green
        case "running", "pending", "queued": return .blue
        case "failed", "error": return .red
        default: return .secondary
        }
    }
}

// MARK: - 3. 漏洞清单

struct SecVulnsTab: View {
    @StateObject private var bridge = SecurityBridge.shared
    @State private var filterSeverity = "all"
    @State private var expandedVuln: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker(I18nManager.shared.t(.secv_severity), selection: $filterSeverity) {
                    ForEach(["all", "critical", "high", "medium", "low"], id: \.self) { Text($0 == "all" ? I18nManager.shared.t(.secv_all) : $0.capitalized) }
                }.pickerStyle(.segmented).controlSize(.small)
                Spacer()
                Button { bridge.fetchVulnerabilities(); bridge.fetchVulnStats() } label: {
                    Label(I18nManager.shared.t(.secv_refresh), systemImage: "arrow.clockwise")
                }.buttonStyle(.bordered).controlSize(.small)
            }.padding(8)

            List(filteredVulns) { v in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedVuln == v.id },
                    set: { expandedVuln = $0 ? v.id : nil }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let desc = v.description { Text(desc).font(.caption).foregroundColor(.secondary) }
                        if let path = v.filePath {
                            Text("\(path):\(v.lineNumber ?? 0)")
                                .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                        }
                        if let code = v.codeSnippet {
                            Text(code).font(.system(.caption2, design: .monospaced))
                                .padding(6).background(Color.black.opacity(0.3)).cornerRadius(4)
                        }
                        if let fix = v.fixSuggestion {
                            Text(I18nManager.shared.tf(.secv_fix_suggestion_fmt, fix)).font(.caption2).foregroundColor(.green)
                        }
                        HStack {
                            Button(I18nManager.shared.t(.secv_fix)) { bridge.generatePatch(vulnId: v.id) { _ in bridge.fetchPatches() } }
                                .buttonStyle(.borderedProminent).controlSize(.mini)
                            Button(I18nManager.shared.t(.secv_false_positive)) { bridge.markFalsePositive(id: v.id, reason: I18nManager.shared.t(.secv_false_positive_reason)) { _ in bridge.fetchVulnerabilities() } }
                                .buttonStyle(.bordered).controlSize(.mini)
                            if v.verified == true {
                                Label(I18nManager.shared.t(.secv_verified), systemImage: "checkmark.seal.fill").font(.caption2).foregroundColor(.green)
                            }
                        }.padding(.top, 4)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sevIcon(v.severity)).foregroundColor(sevColor(v.severity))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(v.title).font(.subheadline)
                            HStack {
                                Text(v.severity).font(.caption2).padding(.horizontal, 4).background(sevColor(v.severity).opacity(0.15)).cornerRadius(3)
                                if let cwe = v.cweId { Text(cwe).font(.caption2).foregroundColor(.secondary) }
                                if let conf = v.confidence { Text(I18nManager.shared.tf(.secv_confidence_fmt, Int(conf * 100))).font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredVulns: [SecVulnDTO] {
        if filterSeverity == "all" { return bridge.vulnerabilities }
        return bridge.vulnerabilities.filter { $0.severity.lowercased() == filterSeverity }
    }

    private func sevIcon(_ s: String) -> String {
        switch s.lowercased() { case "critical": return "flame.fill"; case "high": return "exclamationmark.triangle.fill"; case "medium": return "exclamationmark.circle.fill"; default: return "info.circle.fill" }
    }
    private func sevColor(_ s: String) -> Color {
        switch s.lowercased() { case "critical": return .red; case "high": return .orange; case "medium": return .yellow; default: return .gray }
    }
}

// MARK: - 4. AI 修复

struct SecPatchTab: View {
    @StateObject private var bridge = SecurityBridge.shared
    @Environment(\.studioTheme) private var theme
    @State private var expandedPatch: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(I18nManager.shared.tf(.secv_ai_patches_fmt, bridge.patches.count)).font(.headline)
                Spacer()
                Button { bridge.fetchPatches() } label: { Label(I18nManager.shared.t(.secv_refresh), systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered).controlSize(.small)
            }.padding(8)

            if bridge.isLoading {
                ProgressView(I18nManager.shared.t(.secv_ai_generating)).padding()
            }

            if bridge.patches.isEmpty && !bridge.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 36)).foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.secv_patch_empty_desc)).foregroundColor(.secondary).font(.caption)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bridge.patches) { p in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedPatch == p.id },
                        set: { expandedPatch = $0 ? p.id : nil }
                    )) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let strat = p.strategy { Text(I18nManager.shared.tf(.secv_strategy_fmt, strat)).font(.caption2).foregroundColor(.secondary) }
                            if let desc = p.description { Text(desc).font(.caption).foregroundColor(.secondary) }
                            if let orig = p.originalCode {
                                Text(I18nManager.shared.t(.secv_original_code)).font(.caption2).foregroundColor(.red)
                                Text(orig).font(.system(.caption2, design: .monospaced)).padding(6).background(Color.black.opacity(0.3)).cornerRadius(4)
                            }
                            if let patched = p.patchedCode {
                                Text(I18nManager.shared.t(.secv_patched_code)).font(.caption2).foregroundColor(.green)
                                Text(patched).font(.system(.caption2, design: .monospaced)).padding(6).background(Color.black.opacity(0.3)).cornerRadius(4)
                            }
                            HStack {
                                if p.status == "generated" || p.status == "pending" {
                                    Button(I18nManager.shared.t(.secv_apply_patch)) { bridge.applyPatch(id: p.id) { _ in bridge.fetchPatches() } }
                                        .buttonStyle(.borderedProminent).controlSize(.mini)
                                }
                                if p.status == "applied" {
                                    Button(I18nManager.shared.t(.secv_verify_patch)) { bridge.verifyPatch(id: p.id) { _ in bridge.fetchPatches() } }
                                        .buttonStyle(.borderedProminent).controlSize(.mini)
                                }
                                if p.verified == true {
                                    Label(I18nManager.shared.t(.secv_verified), systemImage: "checkmark.seal.fill").font(.caption2).foregroundColor(.green)
                                }
                            }.padding(.top, 4)
                        }
                    } label: {
                        HStack {
                            Image(systemName: patchStatusIcon(p.status ?? "")).foregroundColor(patchStatusColor(p.status ?? ""))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(I18nManager.shared.tf(.secv_patch_fmt, String(p.id.prefix(8)))).font(.subheadline)
                                Text(I18nManager.shared.tf(.secv_vuln_fmt, String(p.vulnId?.prefix(8) ?? "?"))).font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(p.status ?? "?").font(.caption2).foregroundColor(patchStatusColor(p.status ?? ""))
                        }
                    }
                }
            }
        }
    }

    private func patchStatusIcon(_ s: String) -> String {
        switch s.lowercased() { case "applied": return "checkmark.circle.fill"; case "verified": return "checkmark.seal.fill"; case "failed": return "xmark.circle.fill"; default: return "wrench.and.screwdriver" }
    }
    private func patchStatusColor(_ s: String) -> Color {
        switch s.lowercased() { case "verified": return .green; case "applied": return .blue; case "failed": return .red; default: return .orange }
    }
}

// MARK: - 5. 质量门禁

struct SecGateTab: View {
    @StateObject private var bridge = SecurityBridge.shared
    @Environment(\.studioTheme) private var theme
    @State private var policy = "default"
    @State private var maxCritical = 0
    @State private var maxHigh = 5
    @State private var gateResult: SecGateResultDTO?
    @State private var newRuleId = ""
    @State private var newRuleName = ""
    @State private var newRulePattern = ""
    @State private var newRuleSeverity = "high"

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(I18nManager.shared.t(.secv_gate_policy)).font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(I18nManager.shared.t(.secv_policy_name)).font(.caption)
                            TextField("default", text: $policy).textFieldStyle(.roundedBorder).frame(width: 120)
                        }
                        HStack {
                            Stepper(I18nManager.shared.tf(.secv_max_critical, maxCritical), value: $maxCritical, in: 0...50)
                            Stepper(I18nManager.shared.tf(.secv_max_high, maxHigh), value: $maxHigh, in: 0...50)
                        }
                        Button(I18nManager.shared.t(.secv_evaluate_gate)) {
                            let vulnArr: [[String: Any]] = bridge.vulnerabilities.map { v in
                                ["severity": v.severity, "status": v.status ?? "open", "id": v.id]
                            }
                            bridge.evaluateGate(vulnerabilities: vulnArr) { result in
                                if case .success(let r) = result { gateResult = r }
                            }
                        }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                    .padding(10).background(theme.surfaceSecondary).cornerRadius(8)

                    if let r = gateResult {
                        HStack {
                            Image(systemName: r.passed ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .foregroundColor(r.passed ? .green : .red).font(.title2)
                            Text(r.passed ? I18nManager.shared.t(.secv_gate_passed) : I18nManager.shared.t(.secv_gate_failed)).font(.headline)
                            Spacer()
                        }.padding(10).background((r.passed ? Color.green : Color.red).opacity(0.1)).cornerRadius(8)
                        if let blocked = r.blockedBy, !blocked.isEmpty {
                            Text(I18nManager.shared.tf(.secv_blocked_by_fmt, blocked.joined(separator: ", "))).font(.caption).foregroundColor(.red)
                        }
                    }

                    Text(I18nManager.shared.tf(.secv_builtin_rules_fmt, bridge.rules.count)).font(.headline).padding(.top, 8)
                    ForEach(bridge.rules.prefix(10)) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rule.id).font(.system(.caption, design: .monospaced))
                                if let desc = rule.description { Text(desc).font(.caption2).foregroundColor(.secondary).lineLimit(1) }
                            }
                            Spacer()
                            Text(rule.severity ?? "?").font(.caption2)
                                .padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                        }
                    }

                    Text(I18nManager.shared.tf(.secv_custom_rules_fmt, bridge.customRules.count)).font(.headline).padding(.top, 8)
                    VStack(spacing: 4) {
                        TextField(I18nManager.shared.t(.secv_rule_id), text: $newRuleId).textFieldStyle(.roundedBorder)
                        TextField(I18nManager.shared.t(.secv_name), text: $newRuleName).textFieldStyle(.roundedBorder)
                        TextField(I18nManager.shared.t(.secv_regex_pattern), text: $newRulePattern).textFieldStyle(.roundedBorder)
                        HStack {
                            Picker(I18nManager.shared.t(.secv_severity), selection: $newRuleSeverity) {
                                ForEach(["critical", "high", "medium", "low"], id: \.self) { Text($0) }
                            }.pickerStyle(.menu).controlSize(.small)
                            Spacer()
                            Button(I18nManager.shared.t(.secv_add)) {
                                bridge.createCustomRule(id: newRuleId, name: newRuleName, pattern: newRulePattern, severity: newRuleSeverity) { _ in
                                    bridge.fetchCustomRules()
                                    newRuleId = ""; newRuleName = ""; newRulePattern = ""
                                }
                            }.buttonStyle(.borderedProminent).controlSize(.small)
                            .disabled(newRuleId.isEmpty || newRulePattern.isEmpty)
                        }
                    }.padding(8).background(theme.surfaceSecondary).cornerRadius(8)

                    ForEach(bridge.customRules) { cr in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cr.name ?? cr.id).font(.caption)
                                Text(cr.pattern ?? "").font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(cr.severity ?? "?").font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                            Button { bridge.deleteCustomRule(id: cr.id) { _ in bridge.fetchCustomRules() } } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.borderless).controlSize(.mini)
                        }
                    }
                }.padding()
            }
        }
    }
}

// MARK: - 6. 运行时防护

struct SecRuntimeTab: View {
    @StateObject private var security = SecurityManager.shared
    @AppStorage("securityLevel") private var securityLevelRaw = "standard"
    @AppStorage("offlineMode") private var offlineMode = true
    @AppStorage("fileAccessControl") private var fileAccessControl = true
    @AppStorage("networkAccessControl") private var networkAccessControl = true
    @AppStorage("integrityCheck") private var integrityCheck = true
    @AppStorage("secretRedaction") private var secretRedaction = true
    @AppStorage("promptInjectionGuard") private var promptInjectionGuard = true

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.secv_security_level)) {
                Picker(I18nManager.shared.t(.secv_security_level), selection: $securityLevelRaw) {
                    ForEach(SecurityLevel.allCases, id: \.rawValue) { level in
                        Text(level.localizedName).tag(level.rawValue)
                    }
                }.pickerStyle(.segmented)
                if let level = SecurityLevel(rawValue: securityLevelRaw) {
                    Text(level.description).font(.caption).foregroundColor(.secondary)
                }
            }

            Section(I18nManager.shared.t(.secv_local_protection)) {
                Toggle(I18nManager.shared.t(.secv_offline_mode), isOn: $offlineMode).help(I18nManager.shared.t(.secv_offline_mode_help))
                Toggle(I18nManager.shared.t(.secv_file_access), isOn: $fileAccessControl).help(I18nManager.shared.t(.secv_file_access_help))
                Toggle(I18nManager.shared.t(.secv_network_access), isOn: $networkAccessControl).help(I18nManager.shared.t(.secv_network_access_help))
                Toggle(I18nManager.shared.t(.secv_integrity_check), isOn: $integrityCheck).help(I18nManager.shared.t(.secv_integrity_help))
            }
            .onChange(of: fileAccessControl) { _, v in security.fileAccessControl = v }
            .onChange(of: networkAccessControl) { _, v in security.networkAccessControl = v }
            .onChange(of: integrityCheck) { _, v in security.integrityCheck = v }

            Section(I18nManager.shared.t(.secv_ai_runtime_enhance)) {
                Toggle(I18nManager.shared.t(.secv_secret_redaction), isOn: $secretRedaction)
                    .help(I18nManager.shared.t(.secv_secret_redaction_help))
                Toggle(I18nManager.shared.t(.secv_prompt_injection), isOn: $promptInjectionGuard)
                    .help(I18nManager.shared.t(.secv_prompt_injection_help))
            }

            Section(I18nManager.shared.t(.secv_input_filter)) {
                Text(I18nManager.shared.t(.secv_input_filter_desc))
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(I18nManager.shared.t(.secv_path_validation)) {
                Text(I18nManager.shared.tf(.secv_allowed_dirs_fmt, NSHomeDirectory(), NSHomeDirectory()))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct SecurityLevelBadge: View {
    let level: SecurityLevel
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(level.localizedName).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1)).cornerRadius(6)
    }
    private var color: Color {
        switch level { case .standard: return .blue; case .high: return .orange; case .maximum: return .red }
    }
}

// MARK: - 输入验证工具

struct InputValidator {
    static func validateCommand(_ input: String) -> Bool {
        let dangerous = [";", "|", "&", "$", "`", "\\", ">", "<", "!", "\n", "\r"]
        for char in dangerous { if input.contains(char) { return false } }
        return true
    }

    static func validatePath(_ path: String) -> Bool {
        return SecurityManager.shared.validateFilePath(path)
    }

    static func sanitize(_ input: String) -> String {
        return SecurityManager.shared.sanitizeInput(input)
    }
}
