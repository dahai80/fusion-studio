import SwiftUI

/// 环境健康检查卡片（控制台首页）
struct EnvironmentHealthCard: View {
    @EnvironmentObject var healthState: HealthState
    @EnvironmentObject var bridge: AgentBridge
    @State private var checkResults: [HealthCheckItem] = []
    @State private var isChecking = false
    @Environment(\.studioTheme) private var theme

    let checks: [HealthCheckItem.Def] = [
        .init(id: "python", label: "Python 3.11+", icon: "laptopcomputer"),
        .init(id: "mlx_server", label: "MLX 服务进程", icon: "cpu"),
        .init(id: "mlx_api", label: "MLX API (port \(FusionConfig.shared.mlxPort))", icon: "bolt"),
        .init(id: "daemon_socket", label: "Daemon UDS Socket", icon: "externaldrive"),
        .init(id: "httpx", label: "HTTP Client (httpx)", icon: "network"),
        .init(id: "model_cache", label: "Model Cache", icon: "internaldrive"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("环境健康检查", systemImage: "stethoscope")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: runHealthCheck) {
                    Label(isChecking ? "检测中..." : "重新检测", systemImage: "arrow.clockwise")
                        .font(.system(size: theme.smallTextSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .disabled(isChecking)
            }

            if checkResults.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.textTertiary)
                        Text("点击「重新检测」开始环境检查")
                            .font(.system(size: theme.smallTextSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(checkResults) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 18)
                        Text(item.label)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                            .frame(width: 140, alignment: .leading)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.status.color)
                                .frame(width: 6, height: 6)
                            Text(item.status.text)
                                .font(.system(size: theme.smallTextSize))
                                .foregroundStyle(theme.textSecondary)
                        }
                        if let detail = item.detail {
                            Text(detail)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                        if item.status == .failed {
                            Button("修复") { repairItem(item) }
                                .buttonStyle(.plain)
                                .font(.system(size: theme.smallTextSize, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.amberDot)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(item.status == .failed ? theme.warningBg.opacity(0.3) : Color.clear)
                    .cornerRadius(theme.rowRadius)
// #46 Adding ModelLoadMonitorView below health checks
// Affected API: ModelLoadMonitorView (model load status dashboard)
                }
            }
            ModelLoadMonitorView()
        }
    }

    private func runHealthCheck() {
        isChecking = true
        checkResults = []
        healthState.healthStatus = .checking

        Task {
            var results: [HealthCheckItem] = []
            do {
                let result = try await bridge.fullHealthCheck()
                let checkDicts = result["checks"] as? [String: [String: Any]] ?? [:]

                for def in checks {
                    let checkInfo = checkDicts[def.id]
                    let ok = checkInfo?["ok"] as? Bool ?? false
                    var detail = ""
                    if let v = checkInfo?["version"] as? String { detail = "v\(v)" }
                    if let p = checkInfo?["port"] as? Int { detail = "port \(p)" }
                    if let path = checkInfo?["path"] as? String { detail = path }
                    if let msg = checkInfo?["message"] as? String { detail = msg }

                    results.append(HealthCheckItem(
                        id: def.id,
                        label: def.label,
                        icon: def.icon,
                        status: ok ? .passed : .failed,
                        detail: detail.isEmpty ? nil : detail
                    ))
                }

                let mlxOk = checkDicts["mlx_api"]?["ok"] as? Bool ?? false
                await MainActor.run {
                    healthState.isMLXRunning = mlxOk
                }
            } catch {
                for def in checks {
                    results.append(HealthCheckItem(
                        id: def.id,
                        label: def.label,
                        icon: def.icon,
                        status: .failed,
                        detail: "Daemon not connected"
                    ))
                }
            }

            await MainActor.run {
                checkResults = results
                isChecking = false
                let hasIssues = results.contains { $0.status == .failed }
                healthState.healthStatus = hasIssues ? .issuesFound : .healthy
                healthState.isHealthCheckPassed = !hasIssues
            }
        }
    }

    private func performCheck(_ def: HealthCheckItem.Def) async -> HealthCheckItem {
        return HealthCheckItem(id: def.id, label: def.label, icon: def.icon, status: .checking, detail: nil)
    }

    private func repairItem(_ item: HealthCheckItem) {
        healthState.healthStatus = .repairing
        Task {
            do {
                _ = try await bridge.repair(itemId: item.id)
            } catch {}
            await MainActor.run {
                healthState.healthStatus = .healthy
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