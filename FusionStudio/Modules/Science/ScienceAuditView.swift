import SwiftUI
import os.log

private let auditLog = Logger(subsystem: "com.fusion.studio", category: "ScienceAuditView")

struct ScienceAuditView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge

    var body: some View {
        ScrollView {
            if scienceBridge.auditEntries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(scienceBridge.auditEntries) { entry in
                        auditRow(entry)
                    }
                }
            }
        }
        .background(theme.surfaceElevated)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.shield")
                .font(.system(size: 32))
                .foregroundStyle(theme.textQuaternary)
            Text("No audit entries")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("Audit trail appears after actions")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func auditRow(_ entry: ScienceAuditEntry) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: statusIcon(entry.status))
                .font(.system(size: 12))
                .foregroundStyle(statusColor(entry.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.step)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(Date(timeIntervalSince1970: entry.timestamp), style: .time)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "complete": return "checkmark.circle.fill"
        case "running": return "arrow.trianglehead.2.clockwise"
        case "failed": return "xmark.circle.fill"
        case "pending": return "circle"
        default: return "circle.dashed"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "complete": return theme.greenDot
        case "running": return theme.blueDot
        case "failed": return theme.redDot
        case "pending": return theme.textTertiary
        default: return theme.textQuaternary
        }
    }
}
