import SwiftUI

/// 上游服务状态视图（控制台首页）
/// 展示每个上游服务的运行状态（运行中/未启动/服务不存在/启动失败），并提供启动/停止/重试按钮。
struct UpstreamServiceStatusView: View {
    @EnvironmentObject var manager: UpstreamServiceManager
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("上游服务", systemImage: "rectangle.connected.to.line.below")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { Task { await manager.refreshAll() } }) {
                    Label(manager.isRefreshing ? "检测中..." : "刷新", systemImage: "arrow.clockwise")
                        .font(.system(size: theme.smallTextSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .disabled(manager.isRefreshing)
            }

            // 关键服务启动失败/不存在告警
            if manager.startupCompleted && manager.hasCriticalFailure {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.errorText)
                    Text("部分关键服务启动失败或不存在，相关功能可能不可用")
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.errorText)
                    Spacer()
                }
                .padding(8)
                .background(theme.errorBg)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            ForEach(manager.services) { svc in
                row(for: svc)
            }

            if !manager.startupCompleted {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在检测上游服务...")
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func row(for svc: UpstreamService) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: svc.icon)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(svc.displayName)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if svc.isCritical {
                        Text("关键")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.accentText)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(svc.message.isEmpty ? svc.status.text : svc.message)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(statusColor(svc.status))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            actionButtons(for: svc)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButtons(for svc: UpstreamService) -> some View {
        if svc.status == .notApplicable {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(theme.textTertiary)
        } else if svc.status == .running {
            Button(action: { Task { await manager.stopService(id: svc.id) } }) {
                Text("停止").font(.system(size: theme.smallTextSize))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
        } else if svc.status == .starting {
            ProgressView().controlSize(.small)
        } else {
            Button(action: { Task { await manager.startService(id: svc.id) } }) {
                Label(svc.status == .failed ? "重试" : "启动", systemImage: "play.fill")
                    .font(.system(size: theme.smallTextSize))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
        }
    }

    private func statusColor(_ status: UpstreamServiceStatus) -> Color {
        switch status {
        case .running:       return theme.successText
        case .failed:        return theme.errorText
        case .notInstalled:  return theme.errorText
        case .stopped:       return theme.textSecondary
        case .starting:      return theme.accent
        case .notApplicable: return theme.textTertiary
        case .unknown:       return theme.textSecondary
        }
    }
}
