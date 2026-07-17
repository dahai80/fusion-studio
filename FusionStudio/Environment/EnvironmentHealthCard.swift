import SwiftUI

/// 环境健康检查卡片（控制台首页）
struct EnvironmentHealthCard: View {
    @EnvironmentObject var appState: AppState
    @State private var checkResults: [HealthCheckItem] = []
    @State private var isChecking = false

    let checks: [HealthCheckItem.Def] = [
        .init(id: "xcode", label: "Xcode CLI Tools", icon: "hammer"),
        .init(id: "homebrew", label: "Homebrew", icon: "mug"),
        .init(id: "python", label: "Python 3.11+", icon: "laptopcomputer"),
        .init(id: "mlx", label: "MLX 环境", icon: "cpu"),
        .init(id: "pybullet", label: "PyBullet", icon: "gearshape.2"),
        .init(id: "rust", label: "Rust 工具链", icon: "chevron.left.forwardslash.chevron.right"),
        .init(id: "fusion-mlx", label: "fusion-mlx 服务", icon: "bolt"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("环境健康检查", systemImage: "stethoscope")
                    .font(.headline)
                Spacer()
                Button(action: runHealthCheck) {
                    Label(isChecking ? "检测中..." : "重新检测",
                          systemImage: "arrow.clockwise")
                }
                .disabled(isChecking)
            }

            if checkResults.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("点击「重新检测」开始环境检查")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(checkResults) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                        Text(item.label)
                            .frame(width: 140, alignment: .leading)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.status.color)
                                .frame(width: 8, height: 8)
                            Text(item.status.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if item.status == .failed {
                            Button("修复") {
                                repairItem(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.orange)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.status == .failed ? Color.red.opacity(0.05) : Color.clear)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func runHealthCheck() {
        isChecking = true
        checkResults = []
        appState.healthStatus = .checking

        Task {
            var results: [HealthCheckItem] = []
            for check in checks {
                let result = await performCheck(check)
                results.append(result)
            }
            await MainActor.run {
                checkResults = results
                isChecking = false
                let hasIssues = results.contains { $0.status == .failed }
                appState.healthStatus = hasIssues ? .issuesFound : .healthy
            }
        }
    }

    private func performCheck(_ def: HealthCheckItem.Def) async -> HealthCheckItem {
        // 模拟检查（后续替换为真实 IPC 调用）
        try? await Task.sleep(nanoseconds: 500_000_000)
        return HealthCheckItem(
            id: def.id,
            label: def.label,
            icon: def.icon,
            status: .passed,
            detail: "v3.0"
        )
    }

    private func repairItem(_ item: HealthCheckItem) {
        appState.healthStatus = .repairing
        Task {
            // 调用修复引擎
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                appState.healthStatus = .healthy
                runHealthCheck()
            }
        }
    }
}

struct HealthCheckItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    var status: CheckStatus
    var detail: String?

    struct Def {
        let id: String
        let label: String
        let icon: String
    }

    enum CheckStatus {
        case passed
        case failed
        case checking

        var color: Color {
            switch self {
            case .passed:  return .green
            case .failed:  return .red
            case .checking: return .orange
            }
        }

        var text: String {
            switch self {
            case .passed:  return "✅ 正常"
            case .failed:  return "❌ 异常"
            case .checking: return "⏳ 检测中"
            }
        }
    }
}