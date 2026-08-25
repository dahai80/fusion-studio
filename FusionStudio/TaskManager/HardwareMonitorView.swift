// Callers: ModuleDetailView routing.
// Affected API: HardwareMonitorView — refreshMetrics() 改走真实 IPC `hardware.metrics`（中央路由 daemon_server.py psutil/powermetrics）。
// Data schemas: IPC 返回 {memory:{used_gb,total_gb,percent}, cpu:{percent,count}, gpu:{raw|error}, mlx:{info|error}}。
// User instruction: "27、对fusion-studio的核心特性进行验收…硬件监控：实时 CPU/GPU/内存/MLX 指标…达到生产发布标准"

import SwiftUI
import os.log

/// 硬件监控仪表盘
struct HardwareMonitorView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var ipc: IPCClient
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var memoryTotal: Double = 0
    @State private var gpuUsage: Double = -1
    @State private var mlxActive: Bool = false
    @State private var dataSource: String = "等待…"
    // F-R13: 本进程 RSS (phys_footprint), StudioMemoryMonitor 10s 采样。
    @ObservedObject private var memMonitor = StudioMemoryMonitor.shared

    private let logger = Logger(subsystem: "com.fusion.studio", category: "HardwareMonitor")
    /// 使用 Timer.publish 自动管理生命周期，View 销毁时自动取消
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("硬件监控", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text(dataSource)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                MetricCard(
                    title: "统一内存",
                    value: String(format: "%.1f", memoryUsage),
                    unit: "/ \(memoryTotal > 0 ? String(format: "%.0f", memoryTotal) : "--")GB",
                    progress: memoryTotal > 0 ? memoryUsage / memoryTotal : 0,
                    color: .blue
                )
                MetricCard(
                    title: "GPU 占用",
                    value: gpuUsage >= 0 ? String(format: "%.0f", gpuUsage) : "N/A",
                    unit: gpuUsage >= 0 ? "%" : "",
                    progress: gpuUsage >= 0 ? gpuUsage / 100.0 : 0,
                    color: .purple
                )
                MetricCard(
                    title: "CPU 负载",
                    value: String(format: "%.0f", cpuUsage),
                    unit: "%",
                    progress: cpuUsage / 100.0,
                    color: .green
                )
                MetricCard(
                    title: "MLX 推理",
                    value: mlxActive ? "活跃" : "空闲",
                    unit: "",
                    progress: mlxActive ? 1.0 : 0.0,
                    color: mlxActive ? .orange : .gray
                )
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
        .onReceive(timer) { _ in
            Task { await refreshMetrics() }
        }
        .task {
            await refreshMetrics()
        }
    }

    private func refreshMetrics() async {
        do {
            let metrics = try await ipc.hardwareMetrics()
            logger.debug("hardware.metrics 收到: \(String(describing: metrics), privacy: .public)")
            let mem = metrics["memory"] as? [String: Any] ?? [:]
            let cpu = metrics["cpu"] as? [String: Any] ?? [:]
            let gpu = metrics["gpu"] as? [String: Any] ?? [:]
            let mlx = metrics["mlx"] as? [String: Any] ?? [:]

            memoryTotal = (mem["total_gb"] as? Double) ?? (mem["total_gb"] as? NSNumber)?.doubleValue ?? 0
            memoryUsage = (mem["used_gb"] as? Double) ?? (mem["used_gb"] as? NSNumber)?.doubleValue ?? memoryUsage
            cpuUsage = (cpu["percent"] as? Double) ?? (cpu["percent"] as? NSNumber)?.doubleValue ?? cpuUsage

            // GPU 无干净占用率接口（Apple Silicon），backend 返回 {available:Bool}；无 percent 时标记 N/A
            if let pct = gpu["percent"] as? Double {
                gpuUsage = pct
            } else {
                gpuUsage = -1
            }

            mlxActive = (mlx["running"] as? Bool) ?? false
            dataSource = "实时"
        } catch {
            logger.error("hardware.metrics 拉取失败，保持上次值: \(String(describing: error), privacy: .public)")
            dataSource = "离线"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                + Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
            ProgressView(value: progress)
                .tint(color)
                .frame(width: 80)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(8)
    }
}