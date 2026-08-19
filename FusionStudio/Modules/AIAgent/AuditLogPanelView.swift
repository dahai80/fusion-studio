// Callers: AIAgentObserverView audit tab embeds this view.
// Affected API: IPCClient.auditList(tool, targetType, since, limit).
// Data schemas: audit-YYYY-MM-DD.jsonl entries {tool, operation, target, status, timestamp}.
// User instruction: #51 审计日志面板 — Audit log list, filtering by tool/type/time, frequency chart

import SwiftUI
import os.log

private let auditLog = Logger(subsystem: "com.fusion.studio", category: "AuditLogPanel")

struct AuditLogPanelView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var entries: [[String: Any]] = []
    @State private var isLoading = false
    @State private var filterTool = ""
    @State private var filterType = ""
    @State private var filterSince = ""
    @State private var showFilters = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            headerBar
            filterBar
            if isLoading {
                ProgressView().padding()
            } else if entries.isEmpty {
                emptyView
            } else {
                frequencyChart
                entryList
            }
        }
        .padding(theme.spacingL)
        .onAppear { loadAudit() }
    }

    private var headerBar: some View {
        HStack {
            Label(i18n.t(.ai_audit_title), systemImage: "list.bullet.clipboard")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { showFilters.toggle() }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(showFilters ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.filter))
            Button(action: loadAudit) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var filterBar: some View {
        Group {
            if showFilters {
                HStack(spacing: theme.spacingS) {
                    TextField(i18n.t(.ai_audit_toolPh), text: $filterTool)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.smallTextSize))
                        .frame(width: 120)
                    TextField(i18n.t(.ai_audit_typePh), text: $filterType)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.smallTextSize))
                        .frame(width: 120)
                    TextField(i18n.t(.ai_audit_sincePh), text: $filterSince)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.smallTextSize))
                        .frame(width: 140)
                        .help(i18n.t(.ai_audit_sinceHint))
                    Button(i18n.t(.ai_audit_apply)) { loadAudit() }
                        .buttonStyle(.plain)
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.accent)
                    Button(i18n.t(.clear)) {
                        filterTool = ""; filterType = ""; filterSince = ""
                        loadAudit()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingS)
                .background(theme.surfaceElevated)
                .cornerRadius(theme.cornerRadiusSmall)
            }
        }
    }

    private var frequencyChart: some View {
        let toolCounts = Dictionary(grouping: entries, by: { $0["tool"] as? String ?? "unknown" })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(8)
        let maxCount = toolCounts.first?.value ?? 1
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.ai_audit_freq))
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            ForEach(Array(toolCounts.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: theme.spacingS) {
                    Text(item.key)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .frame(width: 80, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accent.opacity(0.6))
                            .frame(width: max(4, geo.size.width * CGFloat(item.value) / CGFloat(maxCount)), height: 14)
                    }
                    .frame(height: 14)
                    Text("\(item.value)")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                    auditRow(entry)
                }
            }
        }
    }

    private func auditRow(_ entry: [String: Any]) -> some View {
        let tool = entry["tool"] as? String ?? ""
        let operation = entry["operation"] as? String ?? ""
        let target = entry["target"] as? String ?? ""
        let status = entry["status"] as? String ?? ""
        let timestamp = entry["timestamp"] as? String ?? ""
        let statusColor: Color = {
            switch status {
            case "success", "ok": return theme.greenDot
            case "denied", "blocked": return theme.redDot
            case "pending", "running": return theme.amberDot
            default: return theme.textTertiary
            }
        }()
        return HStack(spacing: theme.spacingS) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(tool)
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            Text(operation)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            Text(target)
                .font(.system(size: theme.smallTextSize, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            Spacer()
            Text(timestamp)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.ai_audit_empty))
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func loadAudit() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.auditList(
                    tool: filterTool,
                    targetType: filterType,
                    since: filterSince,
                    limit: 200
                )
                await MainActor.run {
                    entries = result["entries"] as? [[String: Any]] ?? []
                    isLoading = false
                    auditLog.info("Audit loaded: \(self.entries.count) entries")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    auditLog.error("Audit load failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
