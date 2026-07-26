// Callers: ModuleDetailView routing.
// Affected API: HardwareMonitorView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

/// 硬件监控仪表盘
struct HardwareMonitorView: View {
    @Environment(\.studioTheme) private var theme
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var gpuUsage: Double = 0
    @State private var mlxActive: Bool = false

    /// 使用 Timer.publish 自动管理生命周期，View 销毁时自动取消
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("硬件监控", systemImage: "chart.bar.xaxis")
                .font(.headline)

            HStack(spacing: 16) {
                MetricCard(
                    title: "统一内存",
                    value: String(format: "%.1f", memoryUsage),
                    unit: "GB",
                    progress: memoryUsage / 32.0,
                    color: .blue
                )
                MetricCard(
                    title: "GPU 占用",
                    value: String(format: "%.0f", gpuUsage),
                    unit: "%",
                    progress: gpuUsage / 100.0,
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
            refreshMetrics()
        }
    }

    private func refreshMetrics() {
        // 模拟刷新（后续替换为真实 IPC 调用）
        cpuUsage = Double.random(in: 10...60)
        memoryUsage = Double.random(in: 4...16)
        gpuUsage = Double.random(in: 5...40)
        mlxActive = Bool.random()
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