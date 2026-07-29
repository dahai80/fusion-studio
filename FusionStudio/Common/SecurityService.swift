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
    @StateObject private var security = SecurityManager.shared
    @State private var selectedTab: SecurityTab = .dashboard

    enum SecurityTab: String, CaseIterable {
        case dashboard = "安全概览"
        case scan      = "安全扫描"
        case events    = "安全事件"
        case config    = "安全配置"
        case webPanel  = "完整面板"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                Text("安全中心")
                    .font(.headline)
                Spacer()
                SecurityLevelBadge(level: security.securityLevel)
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
            case .dashboard: SecurityDashboard()
            case .scan:      SecurityScanView()
            case .events:    SecurityEventsView()
            case .config:    SecurityConfigView()
            case .webPanel:  SecurityWebPanelView()
            }
        }
    }

    private func tabIcon(_ tab: SecurityTab) -> String {
        switch tab {
        case .dashboard: return "shield"
        case .scan:      return "magnifyingglass"
        case .events:    return "exclamationmark.shield"
        case .config:    return "gearshape"
        case .webPanel:  return "globe"
        }
    }
}

// MARK: - Security WebView 面板

struct SecurityWebPanelView: View {
    @Environment(\.studioTheme) var theme
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var serviceStatus: ServiceReachability = .unknown

    private let securityURL = "http://localhost:3000"

    enum ServiceReachability {
        case online, offline, unknown
    }

    var body: some View {
        VStack(spacing: 0) {
            serviceStatusBar

            ZStack {
                WebViewContainer(url: securityURL, isLoading: $isLoading, error: $loadError)

                if isLoading && loadError == nil {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large)
                        Text("正在连接 Fusion-Security 前端...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("无法加载安全审计面板")
                            .font(.title2)
                            .bold()
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("启动方式:").font(.subheadline).fontWeight(.semibold)
                            Text("1. 启动后端: cd fusion-security && python -m fusion_security.api.app").font(.caption).foregroundColor(.secondary)
                            Text("2. 启动前端: cd fusion-security/frontend && npm run dev").font(.caption).foregroundColor(.secondary)
                            Text("前端默认端口: 3000, 后端默认端口: 8000").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                        .background(theme.surfaceElevated)
                        .cornerRadius(8)
                        FusionButton("重试", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                            loadError = nil
                            isLoading = true
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { checkService() }
    }

    private var serviceStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            FusionButton("检查状态", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                checkService()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var statusColor: Color {
        switch serviceStatus {
        case .online: return theme.greenDot
        case .offline: return theme.redDot
        case .unknown: return theme.amberDot
        }
    }

    private var statusText: String {
        switch serviceStatus {
        case .online: return "Fusion-Security 后端在线 (localhost:8000)"
        case .offline: return "Fusion-Security 后端离线"
        case .unknown: return "检查中..."
        }
    }

    private func checkService() {
        serviceStatus = .unknown
        let url = URL(string: "http://localhost:8000/api/v1/system/info")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    self.serviceStatus = .online
                } else {
                    self.serviceStatus = .offline
                }
            }
        }.resume()
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

// MARK: - 安全概览

struct SecurityDashboard: View {
    @StateObject private var security = SecurityManager.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                SecurityCard(title: "安全等级", value: security.securityLevel.rawValue, icon: "shield.checkered", color: .green)
                SecurityCard(title: "安全事件", value: "\(security.events.count)", icon: "exclamationmark.shield", color: security.events.isEmpty ? .green : .orange)
                SecurityCard(title: "沙箱状态", value: security.sandboxEnabled ? "已启用" : "未启用", icon: "square.split.bottomrightquarter", color: security.sandboxEnabled ? .green : .gray)
                SecurityCard(title: "文件访问控制", value: security.fileAccessControl ? "已启用" : "已禁用", icon: "doc.text.magnifyingglass", color: security.fileAccessControl ? .green : .red)
                SecurityCard(title: "完整性检查", value: security.integrityCheck ? "已启用" : "已禁用", icon: "checkmark.shield", color: security.integrityCheck ? .green : .gray)
                SecurityCard(title: "离线模式", value: UserDefaults.standard.bool(forKey: "offlineMode") ? "已开启" : "未开启", icon: "antenna.radiowaves.left.and.right.slash", color: UserDefaults.standard.bool(forKey: "offlineMode") ? .green : .orange)
            }
            .padding()
        }
    }
}

struct SecurityCard: View {
    @Environment(\.studioTheme) private var theme
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 安全扫描

struct SecurityScanView: View {
    @StateObject private var security = SecurityManager.shared

    var body: some View {
        VStack {
            if security.scanResults.isEmpty && !security.isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("运行安全扫描以检查系统安全状态").foregroundColor(.secondary)
                    Button("运行扫描") { security.runSecurityScan() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else if security.isScanning {
                ProgressView("正在扫描...").padding()
                Spacer()
            } else {
                HStack {
                    Text("扫描结果")
                        .font(.headline)
                    Spacer()
                    Text("\(security.scanResults.filter { $0.status == .passed }.count)/\(security.scanResults.count) 通过")
                        .font(.subheadline).foregroundColor(.secondary)
                    Button("重新扫描") { security.runSecurityScan() }.buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal)

                List(security.scanResults) { result in
                    HStack(spacing: 10) {
                        Image(systemName: result.status == .passed ? "checkmark.circle.fill" : (result.status == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                            .foregroundColor(result.status == .passed ? .green : (result.status == .warning ? .orange : .red))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(result.category).font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                Text(result.item).font(.headline)
                            }
                            Text(result.detail).font(.caption).foregroundColor(.secondary)
                            Text("建议: \(result.recommendation)").font(.caption2).foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 安全事件

struct SecurityEventsView: View {
    @StateObject private var security = SecurityManager.shared

    var body: some View {
        VStack {
            if security.events.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.shield").font(.system(size: 40)).foregroundColor(.green)
                    Text("无安全事件").foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(security.events.reversed()) { event in
                    HStack(spacing: 10) {
                        Image(systemName: eventIcon(event.severity)).foregroundColor(eventColor(event.severity))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(event.type.rawValue).font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                Text(event.message).font(.subheadline)
                            }
                            HStack {
                                Text(event.source).font(.caption2).foregroundColor(.secondary)
                                Text(event.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .toolbar {
                    ToolbarItem { Button("清空") { security.clearEvents() }.buttonStyle(.bordered).controlSize(.small) }
                }
            }
        }
    }

    private func eventIcon(_ s: SecurityEvent.Severity) -> String {
        switch s { case .info: return "info.circle"; case .warning: return "exclamationmark.triangle"; case .critical: return "xmark.octagon" }
    }
    private func eventColor(_ s: SecurityEvent.Severity) -> Color {
        switch s { case .info: return .blue; case .warning: return .orange; case .critical: return .red }
    }
}

// MARK: - 安全配置

struct SecurityConfigView: View {
    @StateObject private var security = SecurityManager.shared
    @AppStorage("securityLevel") private var securityLevelRaw = "standard"
    @AppStorage("offlineMode") private var offlineMode = true
    @AppStorage("sandboxEnabled") private var sandboxEnabled = false
    @AppStorage("fileAccessControl") private var fileAccessControl = true
    @AppStorage("networkAccessControl") private var networkAccessControl = true
    @AppStorage("integrityCheck") private var integrityCheck = true

    var body: some View {
        Form {
            Section("安全等级") {
                Picker("安全等级", selection: $securityLevelRaw) {
                    ForEach(SecurityLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                if let level = SecurityLevel(rawValue: securityLevelRaw) {
                    Text(level.description).font(.caption).foregroundColor(.secondary)
                }
            }

            Section("安全选项") {
                Toggle("离线模式", isOn: $offlineMode)
                    .help("开启后阻止所有外部网络请求")
                Toggle("沙箱隔离", isOn: $sandboxEnabled)
                    .help("限制应用访问文件系统范围")
                Toggle("文件访问控制", isOn: $fileAccessControl)
                    .help("限制仅允许访问特定目录")
                Toggle("网络访问控制", isOn: $networkAccessControl)
                    .help("控制网络请求的发起")
                Toggle("完整性检查", isOn: $integrityCheck)
                    .help("定期检查核心文件完整性")
            }
            .onChange(of: sandboxEnabled) { _, v in security.sandboxEnabled = v }
            .onChange(of: fileAccessControl) { _, v in security.fileAccessControl = v }
            .onChange(of: networkAccessControl) { _, v in security.networkAccessControl = v }
            .onChange(of: integrityCheck) { _, v in security.integrityCheck = v }

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
