// Callers: ModuleDetailView routing.
// Affected API: OperationsView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let opsLog = Logger(subsystem: "com.fusion.studio", category: "Operations")

// MARK: - 运维状态

struct OpsStatus {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var diskUsage: Double = 0
    var uptime: TimeInterval = 0
    var serviceCount: Int = 0
    var activeConnections: Int = 0
    var lastBackup: Date?
    var lastAlert: Date?
    var alertsToday: Int = 0
}

// MARK: - 告警规则

struct AlertRule: Identifiable, Hashable {
    let id: String
    var name: String
    var metric: String
    var condition: String
    var threshold: Double
    var enabled: Bool
    var severity: AlertSeverity
    var lastTriggered: Date?

    enum AlertSeverity: String, CaseIterable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"

        var localizedName: String {
            switch self {
            case .info: return I18nManager.shared.t(.ops_sev_info)
            case .warning: return I18nManager.shared.t(.ops_sev_warning)
            case .critical: return I18nManager.shared.t(.ops_sev_critical)
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlertRule, rhs: AlertRule) -> Bool { lhs.id == rhs.id }
}

// MARK: - 运维日志

struct OpsLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let source: String
    let message: String
    let duration: String?
}

// MARK: - 运维管理器

class OperationsManager: ObservableObject {
    static let shared = OperationsManager()

    @Published var status = OpsStatus()
    @Published var alertRules: [AlertRule] = []
    @Published var logs: [OpsLogEntry] = []
    @Published var isMonitoring = false
    private var monitorTimer: Timer?

    init() {
        loadSampleData()
    }

    private func loadSampleData() {
        status = OpsStatus(cpuUsage: 35.2, memoryUsage: 12.8, diskUsage: 45.6, uptime: 86400 * 7, serviceCount: 4, activeConnections: 2, lastBackup: Date().addingTimeInterval(-3600), lastAlert: Date().addingTimeInterval(-1800), alertsToday: 3)

        alertRules = [
            AlertRule(id: "rule-1", name: "ops_rule_cpu_overload", metric: "ops_metric_cpu_usage", condition: ">", threshold: 90, enabled: true, severity: .critical),
            AlertRule(id: "rule-2", name: "ops_rule_mem_low", metric: "ops_metric_mem_usage", condition: ">", threshold: 28, enabled: true, severity: .warning),
            AlertRule(id: "rule-3", name: "ops_rule_disk_low", metric: "ops_metric_disk_usage", condition: ">", threshold: 90, enabled: true, severity: .warning),
            AlertRule(id: "rule-4", name: "ops_rule_service_down", metric: "ops_metric_service_status", condition: "=", threshold: 0, enabled: true, severity: .critical),
            AlertRule(id: "rule-5", name: "ops_rule_inference_latency_high", metric: "ops_metric_mlx_latency", condition: ">", threshold: 5000, enabled: false, severity: .info),
        ]

        logs = [
            OpsLogEntry(timestamp: Date().addingTimeInterval(-60), level: "INFO", source: "fusion-mlx", message: "ops_log_health_check_ok", duration: nil),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-300), level: "WARN", source: "fusion-mlx", message: "ops_log_inference_latency_rise", duration: "2.3s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-600), level: "INFO", source: "system", message: "ops_log_auto_backup_done", duration: "45s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-1800), level: "ERROR", source: "fusion-mlx", message: "ops_log_inference_timeout", duration: "30s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-3600), level: "INFO", source: "system", message: "ops_log_service_restart_done", duration: "12s"),
        ]
    }

    func startMonitoring() {
        isMonitoring = true
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshMetrics()
        }
        opsLog.info("startMonitoring: timer armed interval=5s")
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
        opsLog.info("stopMonitoring: timer invalidated")
    }

    private func refreshMetrics() {
        status.cpuUsage = Double.random(in: 20...70)
        status.memoryUsage = Double.random(in: 8...20)
        status.activeConnections = Int.random(in: 0...5)
    }

    func runHealthCheck() -> (passed: Int, total: Int) {
        let checks = [true, true, true, true, Bool.random()]
        return (checks.filter { $0 }.count, checks.count)
    }

    func restartService(_ name: String) {
        logs.insert(OpsLogEntry(timestamp: Date(), level: "INFO", source: "system", message: I18nManager.shared.tf(.ops_log_restarting_fmt, name), duration: nil), at: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.logs.insert(OpsLogEntry(timestamp: Date(), level: "INFO", source: "system", message: I18nManager.shared.tf(.ops_log_restart_done_fmt, name), duration: "2.0s"), at: 0)
        }
    }
}

// MARK: - 运维面板

struct OperationsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var ops = OperationsManager.shared
    @State private var selectedTab: OpsTab = .dashboard

    enum OpsTab: String, CaseIterable {
        case dashboard
        case services
        case alerts
        case logs

        var localizedName: String {
            switch self {
            case .dashboard: return I18nManager.shared.t(.ops_tab_dashboard)
            case .services:  return I18nManager.shared.t(.ops_tab_services)
            case .alerts:    return I18nManager.shared.t(.ops_tab_alerts)
            case .logs:      return I18nManager.shared.t(.ops_tab_logs)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.ops_title), systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                Spacer()
                Toggle(I18nManager.shared.t(.ops_toggle_realtime), isOn: Binding(
                    get: { ops.isMonitoring },
                    set: { $0 ? ops.startMonitoring() : ops.stopMonitoring() }
                )).toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(OpsTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            switch selectedTab {
            case .dashboard: OpsDashboard()
            case .services:  OpsServicesView()
            case .alerts:    OpsAlertsView()
            case .logs:      OpsLogsView()
            }
        }
        // F-perf-4: 5s monitorTimer 旧无 onDisappear 绑定, 离开 Ops 模块仍空转。
        // 离开视图即停监控, 回来由用户 Toggle 重新开 (Toggle 状态 isMonitoring 由 ops 持久, 视觉一致)。
        .onDisappear {
            if ops.isMonitoring {
                ops.stopMonitoring()
            }
        }
    }

    private func tabIcon(_ tab: OpsTab) -> String {
        switch tab { case .dashboard: return "gauge.medium"; case .services: return "gearshape.2"; case .alerts: return "bell"; case .logs: return "doc.text" }
    }
}

// MARK: - 运维概览

struct OpsDashboard: View {
    @StateObject private var ops = OperationsManager.shared
    let health = OperationsManager.shared.runHealthCheck()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                OpsCard(title: "CPU", value: "\(Int(ops.status.cpuUsage))%", icon: "cpu", color: .blue, progress: ops.status.cpuUsage / 100)
                OpsCard(title: I18nManager.shared.t(.ops_card_memory), value: "\(Int(ops.status.memoryUsage)) GB", icon: "memorychip", color: .green, progress: ops.status.memoryUsage / 32)
                OpsCard(title: I18nManager.shared.t(.ops_card_disk), value: "\(Int(ops.status.diskUsage))%", icon: "externaldrive", color: .orange, progress: ops.status.diskUsage / 100)
                OpsCard(title: I18nManager.shared.t(.ops_card_uptime), value: "\(Int(ops.status.uptime / 86400))d", icon: "clock", color: .purple, progress: 0.7)
                OpsCard(title: I18nManager.shared.t(.ops_card_services), value: "\(ops.status.serviceCount)", icon: "gearshape.2", color: .indigo, progress: 1.0)
                OpsCard(title: I18nManager.shared.t(.ops_card_connections), value: "\(ops.status.activeConnections)", icon: "antenna.radiowaves.left.and.right", color: .cyan, progress: Double(ops.status.activeConnections) / 10)
                OpsCard(title: I18nManager.shared.t(.ops_card_alerts_today), value: "\(ops.status.alertsToday)", icon: "bell", color: ops.status.alertsToday > 0 ? .orange : .green, progress: 0.5)
                OpsCard(title: I18nManager.shared.t(.ops_card_health_check), value: "\(health.passed)/\(health.total)", icon: "stethoscope", color: health.passed == health.total ? .green : .red, progress: Double(health.passed) / Double(health.total))
            }
            .padding()
        }
    }
}

struct OpsCard: View {
    @Environment(\.studioTheme) private var theme
    let title: String; let value: String; let icon: String; let color: Color; let progress: Double
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
            ProgressView(value: min(max(progress, 0), 1)).tint(color)
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 服务管理

struct OpsServicesView: View {
    @StateObject private var ops = OperationsManager.shared

    let services: [(name: String, status: String, port: Int, pid: Int, cpu: String, mem: String)] = [
        ("fusion-mlx", "ops_status_running", 8000, 12347, "45.2%", "5.2 GB"),
    ]

    var body: some View {
        List {
            ForEach(services, id: \.name) { svc in
                HStack(spacing: 10) {
                    Circle().fill(svc.status == "ops_status_running" ? Color.green : Color.red).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(svc.name).font(.headline)
                        Text(I18nManager.shared.t(svc.status)).font(.caption).foregroundColor(svc.status == "ops_status_running" ? .green : .red)
                    }
                    Spacer()
                    if svc.pid > 0 {
                        Text("PID: \(svc.pid)").font(.caption2).foregroundColor(.secondary)
                        Text("CPU: \(svc.cpu)").font(.caption2).foregroundColor(.secondary)
                        Text("MEM: \(svc.mem)").font(.caption2).foregroundColor(.secondary)
                    }
                    if svc.port > 0 { Text(":\(svc.port)").font(.caption2).foregroundColor(.secondary) }
                    Button(svc.status == "ops_status_running" ? I18nManager.shared.t(.ops_btn_restart) : I18nManager.shared.t(.ops_btn_start)) { ops.restartService(svc.name) }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(svc.status == "ops_status_running" ? .orange : .green)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - 告警规则

struct OpsAlertsView: View {
    @StateObject private var ops = OperationsManager.shared

    var body: some View {
        List {
            ForEach($ops.alertRules) { $rule in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("", isOn: $rule.enabled).toggleStyle(.switch).controlSize(.small)
                        Text(I18nManager.shared.t(rule.name)).font(.headline)
                        Spacer()
                        AlertSeverityBadge(severity: rule.severity)
                    }
                    HStack {
                        Text("\(I18nManager.shared.t(rule.metric)) \(rule.condition) \(Int(rule.threshold))").font(.caption).foregroundColor(.secondary)
                        if let last = rule.lastTriggered {
                            Text(I18nManager.shared.tf(.ops_last_triggered_fmt, last.formatted(date: .numeric, time: .shortened))).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct AlertSeverityBadge: View {
    let severity: AlertRule.AlertSeverity
    var body: some View {
        Text(severity.localizedName).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2)).foregroundColor(color).cornerRadius(4)
    }
    private var color: Color { switch severity { case .info: return .blue; case .warning: return .orange; case .critical: return .red } }
}

// MARK: - 运维日志

struct OpsLogsView: View {
    @StateObject private var ops = OperationsManager.shared

    var body: some View {
        List(ops.logs) { entry in
            HStack(spacing: 8) {
                Text(entry.timestamp, style: .time).font(.caption).foregroundColor(.secondary).frame(width: 60)
                Text(entry.level).font(.caption).fontWeight(.bold).foregroundColor(levelColor(entry.level)).frame(width: 40)
                Text(entry.source).font(.caption).foregroundColor(.secondary).frame(width: 80)
                Text(I18nManager.shared.t(entry.message)).font(.subheadline)
                Spacer()
                if let dur = entry.duration { Text(dur).font(.caption2).foregroundColor(.secondary) }
            }
            .padding(.vertical, 2)
        }
    }

    private func levelColor(_ level: String) -> Color {
        switch level { case "ERROR": return .red; case "WARN": return .orange; default: return .primary }
    }
}