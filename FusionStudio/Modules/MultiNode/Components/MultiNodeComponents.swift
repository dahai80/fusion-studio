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
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.studioTheme) var theme

    private var statusColor: Color {
        switch node.status {
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
                .accessibilityLabel("节点\(node.status.rawValue)")

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
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(isSelected ? theme.selBg : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

struct TaskRow: View {
    let task: ClusterTask
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.studioTheme) var theme

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
                        Text("降级: \(degraded)→\(task.modelName)")
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
