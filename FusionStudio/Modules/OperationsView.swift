import SwiftUI

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

    enum AlertSeverity: String, CaseIterable { case info = "信息", warning = "警告", critical = "严重" }

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

    init() {
        loadSampleData()
    }

    private func loadSampleData() {
        status = OpsStatus(cpuUsage: 35.2, memoryUsage: 12.8, diskUsage: 45.6, uptime: 86400 * 7, serviceCount: 4, activeConnections: 2, lastBackup: Date().addingTimeInterval(-3600), lastAlert: Date().addingTimeInterval(-1800), alertsToday: 3)

        alertRules = [
            AlertRule(id: "rule-1", name: "CPU 过载", metric: "CPU 使用率", condition: ">", threshold: 90, enabled: true, severity: .critical),
            AlertRule(id: "rule-2", name: "内存不足", metric: "内存使用", condition: ">", threshold: 28, enabled: true, severity: .warning),
            AlertRule(id: "rule-3", name: "磁盘空间不足", metric: "磁盘使用", condition: ">", threshold: 90, enabled: true, severity: .warning),
            AlertRule(id: "rule-4", name: "服务宕机", metric: "服务状态", condition: "=", threshold: 0, enabled: true, severity: .critical),
            AlertRule(id: "rule-5", name: "推理延迟过高", metric: "MLX 延迟", condition: ">", threshold: 5000, enabled: false, severity: .info),
        ]

        logs = [
            OpsLogEntry(timestamp: Date().addingTimeInterval(-60), level: "INFO", source: "env-daemon", message: "环境健康检查通过", duration: nil),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-300), level: "WARN", source: "mlx-daemon", message: "推理延迟升高 (124ms)", duration: "2.3s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-600), level: "INFO", source: "system", message: "自动备份完成", duration: "45s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-1800), level: "ERROR", source: "mlx-daemon", message: "推理请求超时", duration: "30s"),
            OpsLogEntry(timestamp: Date().addingTimeInterval(-3600), level: "INFO", source: "system", message: "服务重启完成", duration: "12s"),
        ]
    }

    func startMonitoring() {
        isMonitoring = true
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshMetrics()
        }
    }

    func stopMonitoring() { isMonitoring = false }

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
        logs.insert(OpsLogEntry(timestamp: Date(), level: "INFO", source: "system", message: "正在重启 \(name)...", duration: nil), at: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.logs.insert(OpsLogEntry(timestamp: Date(), level: "INFO", source: "system", message: "\(name) 重启完成", duration: "2.0s"), at: 0)
        }
    }
}

// MARK: - 运维面板

struct OperationsView: View {
    @StateObject private var ops = OperationsManager.shared
    @State private var selectedTab: OpsTab = .dashboard

    enum OpsTab: String, CaseIterable {
        case dashboard = "运维概览"
        case services  = "服务管理"
        case alerts    = "告警规则"
        case logs      = "运维日志"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("运维中心", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                Spacer()
                Toggle("实时监控", isOn: Binding(
                    get: { ops.isMonitoring },
                    set: { $0 ? ops.startMonitoring() : ops.stopMonitoring() }
                )).toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(OpsTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
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
                OpsCard(title: "内存", value: "\(Int(ops.status.memoryUsage)) GB", icon: "memorychip", color: .green, progress: ops.status.memoryUsage / 32)
                OpsCard(title: "磁盘", value: "\(Int(ops.status.diskUsage))%", icon: "externaldrive", color: .orange, progress: ops.status.diskUsage / 100)
                OpsCard(title: "运行时间", value: "\(Int(ops.status.uptime / 86400))d", icon: "clock", color: .purple, progress: 0.7)
                OpsCard(title: "服务数", value: "\(ops.status.serviceCount)", icon: "gearshape.2", color: .indigo, progress: 1.0)
                OpsCard(title: "活跃连接", value: "\(ops.status.activeConnections)", icon: "antenna.radiowaves.left.and.right", color: .cyan, progress: Double(ops.status.activeConnections) / 10)
                OpsCard(title: "今日告警", value: "\(ops.status.alertsToday)", icon: "bell", color: ops.status.alertsToday > 0 ? .orange : .green, progress: 0.5)
                OpsCard(title: "健康检查", value: "\(health.passed)/\(health.total)", icon: "stethoscope", color: health.passed == health.total ? .green : .red, progress: Double(health.passed) / Double(health.total))
            }
            .padding()
        }
    }
}

struct OpsCard: View {
    let title: String; let value: String; let icon: String; let color: Color; let progress: Double
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
            ProgressView(value: min(max(progress, 0), 1)).tint(color)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 服务管理

struct OpsServicesView: View {
    @StateObject private var ops = OperationsManager.shared

    let services: [(name: String, status: String, port: Int, pid: Int, cpu: String, mem: String)] = [
        ("env-daemon", "运行中", 0, 12345, "0.2%", "4 MB"),
        ("mlx-daemon", "运行中", 8001, 12346, "1.5%", "28 MB"),
        ("fusion-mlx", "运行中", 8000, 12347, "45.2%", "5.2 GB"),
        ("file-daemon", "已停止", 8002, 0, "-", "-"),
    ]

    var body: some View {
        List {
            ForEach(services, id: \.name) { svc in
                HStack(spacing: 10) {
                    Circle().fill(svc.status == "运行中" ? Color.green : Color.red).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(svc.name).font(.headline)
                        Text(svc.status).font(.caption).foregroundColor(svc.status == "运行中" ? .green : .red)
                    }
                    Spacer()
                    if svc.pid > 0 {
                        Text("PID: \(svc.pid)").font(.caption2).foregroundColor(.secondary)
                        Text("CPU: \(svc.cpu)").font(.caption2).foregroundColor(.secondary)
                        Text("MEM: \(svc.mem)").font(.caption2).foregroundColor(.secondary)
                    }
                    if svc.port > 0 { Text(":\(svc.port)").font(.caption2).foregroundColor(.secondary) }
                    Button(svc.status == "运行中" ? "重启" : "启动") { ops.restartService(svc.name) }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(svc.status == "运行中" ? .orange : .green)
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
                        Text(rule.name).font(.headline)
                        Spacer()
                        AlertSeverityBadge(severity: rule.severity)
                    }
                    HStack {
                        Text("\(rule.metric) \(rule.condition) \(Int(rule.threshold))").font(.caption).foregroundColor(.secondary)
                        if let last = rule.lastTriggered {
                            Text("上次触发: \(last.formatted(date: .numeric, time: .shortened))").font(.caption2).foregroundColor(.secondary)
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
        Text(severity.rawValue).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
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
                Text(entry.message).font(.subheadline)
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