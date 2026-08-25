import SwiftUI

struct MetricStripCard: View {
    let icon: String
    let label: String
    let value: String
    let subtitle: String
    var dotColor: Color? = nil
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingS) {
                if let dot = dotColor {
                    Circle().fill(dot).frame(width: 8, height: 8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(label)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(value)
                .font(.system(size: theme.largeTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }
}

struct NodeRow: View {
    let node: ClusterNode
    let nodeLoad: NodeLoadReport?
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    private var statusColor: Color {
        switch node.effectiveStatus {
        case .online: theme.greenDot
        case .busy: theme.amberDot
        case .offline: theme.textTertiary
        case .fault: theme.redDot
        }
    }

    var body: some View {
        HStack(spacing: theme.spacingM) {
            Circle().fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel(String(format: i18n.t(.mn_node_statusA11yFmt), node.effectiveStatus.rawValue))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingS) {
                    Text(node.hostname)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    if node.isMaster {
                        Text("Master")
                            .font(.system(size: theme.captionSize, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(theme.accentSoft))
                    }
                    Spacer()
                    Text(String(format: "%.1f/%.0fGB", node.totalMemoryGB - node.availableMemoryGB, node.totalMemoryGB))
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                    ProgressView(value: node.memoryUsageRatio)
                        .progressViewStyle(.linear)
                        .frame(width: 48)
                }
                HStack(spacing: theme.spacingS) {
                    Text("\(node.ipAddress):\(node.port)")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                    Spacer()
                    Text("\(node.activeTasks)/\(node.maxTasks) tasks")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                if let load = nodeLoad {
                    HStack(spacing: theme.spacingM) {
                        loadBadge(icon: "gpu", label: "GPU", ratio: load.gpuUsageRatio, detail: String(format: "%.1f/%.1fGB", load.gpuMemoryUsedGb, load.gpuMemoryTotalGb))
                        loadBadge(icon: "memorychip", label: "RAM", ratio: load.ramUsageRatio, detail: String(format: "%.1f/%.1fGB", load.ramUsedGb, load.ramTotalGb))
                        loadBadge(icon: "cpu", label: "CPU", value: String(format: "%.0f%%", load.cpuPercent))
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(isSelected ? theme.selBg : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private func loadBadge(icon: String, label: String, ratio: Double, detail: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Text(detail)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
                .frame(width: 32)
        }
    }

    private func loadBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
    }
}

struct TaskRow: View {
    let task: ClusterTask
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    private var statusPillStatus: StatusPill.Status {
        switch task.status {
        case .pending: return .starting
        case .running: return .running
        case .completed: return .stopped
        case .failed: return .error
        case .cancelled: return .stopped
        case .degraded: return .custom(color: theme.amberDot, label: "Degraded")
        }
    }

    var body: some View {
        HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingS) {
                    Text(task.id)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(task.mode)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(task.modelName)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                    Spacer()
                    StatusPill(status: statusPillStatus, compact: true)
                }
                HStack(spacing: theme.spacingS) {
                    if !task.assignedNodes.isEmpty {
                        Text("Node: \(task.assignedNodes.joined(separator: ", "))")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                    if let degraded = task.degradedFromModel {
                        Text(String(format: i18n.t(.mn_task_degradedFmt), degraded, task.modelName))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.amberDot)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(isSelected ? theme.selBg : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
