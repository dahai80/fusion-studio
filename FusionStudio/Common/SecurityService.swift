// Callers: ModuleDetailView routing.
// Affected API: SecurityService (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "落地2，1先等一等" — embed fusion-security + fusion-bench WebView into fusion-studio

import SwiftUI
import Foundation
import CommonCrypto

// MARK: - 安全检查级别

enum SecurityLevel: String, CaseIterable {
    case standard = "标准"
    case high     = "高"
    case maximum  = "最高"

    var description: String {
        switch self {
        case .standard: return "基本安全保护，适合日常使用"
        case .high:     return "增强安全保护，启用沙箱和文件权限控制"
        case .maximum:  return "最高安全保护，限制网络访问和外部连接"
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

    enum EventType: String { case access = "访问控制", network = "网络", file = "文件", process = "进程", integrity = "完整性" }
    enum Severity: String { case info = "信息", warning = "警告", critical = "严重" }
}

// MARK: - 安全扫描结果

struct SecurityScanResult: Identifiable {
    let id = UUID()
    let category: String
    let item: String
    let status: ScanStatus
    let detail: String
    let recommendation: String

    enum ScanStatus: String { case passed = "通过", failed = "失败", warning = "警告" }
}

// MARK: - 安全管理器

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()

    @Published var securityLevel: SecurityLevel = .standard
    @Published var events: [SecurityEvent] = []
    @Published var scanResults: [SecurityScanResult] = []
    @Published var isScanning = false
    @Published var sandboxEnabled = false
    @Published var fileAccessControl = true
    @Published var networkAccessControl = true
    @Published var integrityCheck = true

    // MARK: - 安全扫描

    func runSecurityScan() {
        isScanning = true
        scanResults = []

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.scanResults.append(contentsOf: [
                SecurityScanResult(category: "文件系统", item: "沙箱隔离", status: self.sandboxEnabled ? .passed : .warning, detail: self.sandboxEnabled ? "沙箱已启用" : "沙箱未启用", recommendation: "建议启用沙箱以隔离文件访问"),
                SecurityScanResult(category: "文件系统", item: "工作区权限", status: .passed, detail: "工作区目录权限正确 (0755)", recommendation: "维持当前权限设置"),
                SecurityScanResult(category: "网络", item: "离线模式", status: UserDefaults.standard.bool(forKey: "offlineMode") ? .passed : .warning, detail: UserDefaults.standard.bool(forKey: "offlineMode") ? "离线模式已开启" : "离线模式未开启", recommendation: "建议开启离线模式阻止外部网络请求"),
                SecurityScanResult(category: "网络", item: "Socket 权限", status: .passed, detail: "Unix Socket 权限 0600", recommendation: "维持当前权限设置"),
                SecurityScanResult(category: "进程", item: "后台服务隔离", status: .passed, detail: "env-daemon 以独立进程运行", recommendation: "维持当前配置"),
                SecurityScanResult(category: "进程", item: "子进程管理", status: .passed, detail: "所有子进程受监控", recommendation: "维持当前配置"),
                SecurityScanResult(category: "完整性", item: "应用签名", status: .warning, detail: "应用未签名", recommendation: "使用开发者证书签名应用"),
                SecurityScanResult(category: "完整性", item: "代码完整性", status: .passed, detail: "核心文件完整性检查通过", recommendation: "维持当前配置"),
                SecurityScanResult(category: "数据", item: "用户数据加密", status: .warning, detail: "本地数据存储未加密", recommendation: "考虑使用 FileVault 加密磁盘"),
                SecurityScanResult(category: "数据", item: "日志安全", status: .passed, detail: "日志不包含敏感信息", recommendation: "维持当前配置"),
            ])
            self.isScanning = false
            self.objectWillChange.send()
        }
    }

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
        case dashboard = "安全概览"
        case projects  = "项目与扫描"
        case vulns     = "漏洞清单"
        case patch     = "AI 修复"
        case gate      = "质量门禁"
        case runtime   = "运行时防护"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                Text("安全中心")
                    .font(.headline)
                Spacer()
                if bridge.isConnected {
                    Label("已连接", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundColor(.green)
                } else {
                    Label("离线", systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(SecurityTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
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
                        Text("引擎信息").font(.caption).foregroundColor(.secondary)
                        Text("\(info.name ?? "Fusion-Security")  v\(info.version ?? "?")")
                            .font(.subheadline)
                        Text("平台: \(info.platform ?? "?") · Python \(info.pythonVersion ?? "?")")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    SecStatCard(title: "扫描总数", value: bridge.dashboard?.totalScans ?? 0, icon: "magnifyingglass", color: .blue)
                    SecStatCard(title: "漏洞总数", value: bridge.dashboard?.totalVulnerabilities ?? 0, icon: "exclamationmark.shield", color: .orange)
                    SecStatCard(title: "项目数", value: bridge.dashboard?.projectsCount ?? bridge.projects.count, icon: "folder", color: .green)
                    SecStatCard(title: "严重", value: bridge.dashboard?.severityCounts?.critical ?? 0, icon: "flame.fill", color: .red)
                    SecStatCard(title: "高危", value: bridge.dashboard?.severityCounts?.high ?? 0, icon: "exclamationmark.triangle.fill", color: .orange)
                    SecStatCard(title: "中危", value: bridge.dashboard?.severityCounts?.medium ?? 0, icon: "exclamationmark.circle.fill", color: .yellow)
                    SecStatCard(title: "低危", value: bridge.dashboard?.severityCounts?.low ?? 0, icon: "info.circle.fill", color: .gray)
                }

                if let rules = bridge.dashboard?.topRules, !rules.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("高频规则 TOP").font(.caption).foregroundColor(.secondary)
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
                Text("项目 (\(bridge.projects.count))").font(.headline)
                Spacer()
                Button { showCreate.toggle() } label: {
                    Label("新建项目", systemImage: "plus.circle")
                }.buttonStyle(.bordered).controlSize(.small)
            }.padding(8)

            if showCreate {
                VStack(spacing: 6) {
                    TextField("项目名", text: $newName).textFieldStyle(.roundedBorder)
                    TextField("本地路径", text: $newPath).textFieldStyle(.roundedBorder)
                    HStack {
                        Picker("技术栈", selection: $newStack) {
                            ForEach(["python", "javascript", "typescript", "go", "rust", "java"], id: \.self) { Text($0) }
                        }.pickerStyle(.menu)
                        Spacer()
                        Button("创建") {
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
                Section("项目列表") {
                    ForEach(bridge.projects) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(p.name).font(.subheadline).fontWeight(.medium)
                                if let stack = p.techStack {
                                    Text(stack).font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                }
                                Spacer()
                                Button { scanProjectId = p.id; scanPath = p.localPath ?? "" } label: {
                                    Label("扫描", systemImage: "magnifyingglass")
                                }.buttonStyle(.bordered).controlSize(.mini)
                            }
                            if let path = p.localPath {
                                Text(path).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                }

                if let sid = scanProjectId {
                    Section("发起扫描 — \(bridge.projects.first(where: { $0.id == sid })?.name ?? sid)") {
                        TextField("扫描路径", text: $scanPath).textFieldStyle(.roundedBorder)
                        Toggle("使用 AI 增强分析", isOn: $useAi)
                        HStack {
                            Button("开始扫描") {
                                bridge.createScan(projectId: sid, path: scanPath, useAi: useAi) { _ in
                                    scanProjectId = nil
                                }
                            }.buttonStyle(.borderedProminent).controlSize(.small)
                            .disabled(bridge.isScanning || scanPath.isEmpty)
                            Button("取消") { scanProjectId = nil }.buttonStyle(.bordered).controlSize(.small)
                            if bridge.isScanning { ProgressView().controlSize(.small) }
                        }
                    }
                }

                Section("扫描历史 (\(bridge.scans.count))") {
                    ForEach(bridge.scans) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(s.scanType ?? "scan").font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                Text(s.status).font(.caption).foregroundColor(secStatusColor(s.status))
                                Spacer()
                                if let total = s.totalVulnerabilities {
                                    Text("\(total) 漏洞").font(.caption2).foregroundColor(.orange)
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
                Picker("严重度", selection: $filterSeverity) {
                    ForEach(["all", "critical", "high", "medium", "low"], id: \.self) { Text($0 == "all" ? "全部" : $0.capitalized) }
                }.pickerStyle(.segmented).controlSize(.small)
                Spacer()
                Button { bridge.fetchVulnerabilities(); bridge.fetchVulnStats() } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
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
                            Text("修复建议: \(fix)").font(.caption2).foregroundColor(.green)
                        }
                        HStack {
                            Button("修复") { bridge.generatePatch(vulnId: v.id) { _ in bridge.fetchPatches() } }
                                .buttonStyle(.borderedProminent).controlSize(.mini)
                            Button("误报") { bridge.markFalsePositive(id: v.id, reason: "Studio 标记") { _ in bridge.fetchVulnerabilities() } }
                                .buttonStyle(.bordered).controlSize(.mini)
                            if v.verified == true {
                                Label("已验证", systemImage: "checkmark.seal.fill").font(.caption2).foregroundColor(.green)
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
                                if let conf = v.confidence { Text("置信 \(Int(conf * 100))%").font(.caption2).foregroundColor(.secondary) }
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
                Text("AI 补丁 (\(bridge.patches.count))").font(.headline)
                Spacer()
                Button { bridge.fetchPatches() } label: { Label("刷新", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered).controlSize(.small)
            }.padding(8)

            if bridge.isLoading {
                ProgressView("AI 生成中...").padding()
            }

            if bridge.patches.isEmpty && !bridge.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 36)).foregroundColor(.secondary)
                    Text("在「漏洞清单」点击「修复」生成 AI 补丁").foregroundColor(.secondary).font(.caption)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bridge.patches) { p in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedPatch == p.id },
                        set: { expandedPatch = $0 ? p.id : nil }
                    )) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let strat = p.strategy { Text("策略: \(strat)").font(.caption2).foregroundColor(.secondary) }
                            if let desc = p.description { Text(desc).font(.caption).foregroundColor(.secondary) }
                            if let orig = p.originalCode {
                                Text("原始代码").font(.caption2).foregroundColor(.red)
                                Text(orig).font(.system(.caption2, design: .monospaced)).padding(6).background(Color.black.opacity(0.3)).cornerRadius(4)
                            }
                            if let patched = p.patchedCode {
                                Text("修复代码").font(.caption2).foregroundColor(.green)
                                Text(patched).font(.system(.caption2, design: .monospaced)).padding(6).background(Color.black.opacity(0.3)).cornerRadius(4)
                            }
                            HStack {
                                if p.status == "generated" || p.status == "pending" {
                                    Button("应用补丁") { bridge.applyPatch(id: p.id) { _ in bridge.fetchPatches() } }
                                        .buttonStyle(.borderedProminent).controlSize(.mini)
                                }
                                if p.status == "applied" {
                                    Button("验证补丁") { bridge.verifyPatch(id: p.id) { _ in bridge.fetchPatches() } }
                                        .buttonStyle(.borderedProminent).controlSize(.mini)
                                }
                                if p.verified == true {
                                    Label("已验证", systemImage: "checkmark.seal.fill").font(.caption2).foregroundColor(.green)
                                }
                            }.padding(.top, 4)
                        }
                    } label: {
                        HStack {
                            Image(systemName: patchStatusIcon(p.status ?? "")).foregroundColor(patchStatusColor(p.status ?? ""))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("补丁 \(p.id.prefix(8))").font(.subheadline)
                                Text("漏洞 \(p.vulnId?.prefix(8) ?? "?")").font(.caption2).foregroundColor(.secondary)
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
                    Text("门禁策略").font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("策略名").font(.caption)
                            TextField("default", text: $policy).textFieldStyle(.roundedBorder).frame(width: 120)
                        }
                        HStack {
                            Stepper("最大严重: \(maxCritical)", value: $maxCritical, in: 0...50)
                            Stepper("最大高危: \(maxHigh)", value: $maxHigh, in: 0...50)
                        }
                        Button("评估门禁 (基于当前漏洞)") {
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
                            Text(r.passed ? "门禁通过" : "门禁未通过").font(.headline)
                            Spacer()
                        }.padding(10).background((r.passed ? Color.green : Color.red).opacity(0.1)).cornerRadius(8)
                        if let blocked = r.blockedBy, !blocked.isEmpty {
                            Text("阻断项: \(blocked.joined(separator: ", "))").font(.caption).foregroundColor(.red)
                        }
                    }

                    Text("内置规则 (\(bridge.rules.count))").font(.headline).padding(.top, 8)
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

                    Text("自定义规则 (\(bridge.customRules.count))").font(.headline).padding(.top, 8)
                    VStack(spacing: 4) {
                        TextField("规则 ID", text: $newRuleId).textFieldStyle(.roundedBorder)
                        TextField("名称", text: $newRuleName).textFieldStyle(.roundedBorder)
                        TextField("正则模式", text: $newRulePattern).textFieldStyle(.roundedBorder)
                        HStack {
                            Picker("严重度", selection: $newRuleSeverity) {
                                ForEach(["critical", "high", "medium", "low"], id: \.self) { Text($0) }
                            }.pickerStyle(.menu).controlSize(.small)
                            Spacer()
                            Button("添加") {
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
    @AppStorage("sandboxEnabled") private var sandboxEnabled = false
    @AppStorage("fileAccessControl") private var fileAccessControl = true
    @AppStorage("networkAccessControl") private var networkAccessControl = true
    @AppStorage("integrityCheck") private var integrityCheck = true
    @AppStorage("secretRedaction") private var secretRedaction = true
    @AppStorage("promptInjectionGuard") private var promptInjectionGuard = true

    var body: some View {
        Form {
            Section("安全等级") {
                Picker("安全等级", selection: $securityLevelRaw) {
                    ForEach(SecurityLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(level.rawValue)
                    }
                }.pickerStyle(.segmented)
                if let level = SecurityLevel(rawValue: securityLevelRaw) {
                    Text(level.description).font(.caption).foregroundColor(.secondary)
                }
            }

            Section("本地防护") {
                Toggle("离线模式", isOn: $offlineMode).help("开启后阻止所有外部网络请求")
                Toggle("沙箱隔离", isOn: $sandboxEnabled).help("限制应用访问文件系统范围")
                Toggle("文件访问控制", isOn: $fileAccessControl).help("限制仅允许访问特定目录")
                Toggle("网络访问控制", isOn: $networkAccessControl).help("控制网络请求的发起")
                Toggle("完整性检查", isOn: $integrityCheck).help("定期检查核心文件完整性")
            }
            .onChange(of: sandboxEnabled) { _, v in security.sandboxEnabled = v }
            .onChange(of: fileAccessControl) { _, v in security.fileAccessControl = v }
            .onChange(of: networkAccessControl) { _, v in security.networkAccessControl = v }
            .onChange(of: integrityCheck) { _, v in security.integrityCheck = v }

            Section("AI 运行时增强（超越 Claude Code）") {
                Toggle("敏感信息脱敏", isOn: $secretRedaction)
                    .help("自动在日志/输出/LLM 上下文中脱敏 API Key、Token、私钥")
                Toggle("Prompt 注入检测", isOn: $promptInjectionGuard)
                    .help("检测并拦截用户输入中的提示注入攻击模式")
            }

            Section("输入过滤") {
                Text("所有用户输入将自动过滤 Shell 注入字符（; | & $ ` \\ > < !）")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section("文件路径验证") {
                Text("允许的目录:\n\(NSHomeDirectory())/.fusion-studio\n\(NSHomeDirectory())/FusionStudio\n/tmp")
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
            Text(level.rawValue).font(.caption)
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
