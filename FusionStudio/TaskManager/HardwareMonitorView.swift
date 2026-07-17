import SwiftUI

/// 硬件监控仪表盘
struct HardwareMonitorView: View {
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var gpuUsage: Double = 0
    @State private var mlxActive: Bool = false
    @State private var timer: Timer?

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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refreshMetrics()
            }
        }
        .onDisappear {
            timer?.invalidate()
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