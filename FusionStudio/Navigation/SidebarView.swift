import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(Module.allCases, selection: $appState.selectedModule) { module in
            Label(module.rawValue, systemImage: module.icon)
                .tag(module)
                .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("Fusion Studio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // 环境状态指示器
                    HealthStatusBadge(status: appState.healthStatus)

                    // 设置按钮
                    Button(action: { appState.showSettings = true }) {
                        Image(systemName: "gearshape")
                    }

                    // MLX 运行状态
                    Button(action: {}) {
                        Image(systemName: appState.isMLXRunning
                            ? "bolt.fill"
                            : "bolt.slash")
                        .foregroundColor(appState.isMLXRunning ? .green : .red)
                    }
                }
            }
        }
    }
}

struct HealthStatusBadge: View {
    let status: AppState.HealthStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    private var color: Color {
        switch status {
        case .checking:    return .gray
        case .healthy:     return .green
        case .issuesFound: return .red
        case .repairing:   return .orange
        }
    }

    private var text: String {
        switch status {
        case .checking:    return "检测中..."
        case .healthy:     return "环境正常"
        case .issuesFound: return "环境异常"
        case .repairing:   return "修复中..."
        }
    }
}