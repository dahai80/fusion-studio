// Callers: ArtifactVersionDiffView export button, CodeEditorView Review card.
// Affected API: IPCClient.diffReviewExport().
// Data schemas: DiffEntry {file, hunks: [{old_start, new_start, lines: [{type, content}]}]}, sorted by severity.
// User instruction: #48 Diff 批注导出为 review.md — Review panel sorted by severity, export to markdown, inline diff annotations

import SwiftUI
import os.log

private let reviewLog = Logger(subsystem: "com.fusion.studio", category: "DiffReviewExport")

struct DiffReviewExportView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var diffEntries: [[String: Any]] = []
    @State private var isLoading = false
    @State private var exportText = ""
    @State private var showExportSheet = false
    @State private var selectedEntry: [String: Any]?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            headerBar
            if isLoading {
                ProgressView().padding()
            } else if diffEntries.isEmpty {
                emptyView
            } else {
                severitySummary
                entryList
            }
        }
        .padding(theme.spacingL)
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
    }

    private var headerBar: some View {
        HStack {
            Label(i18n.t(.ai_review_title), systemImage: "text.badge.checkmark")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            if !diffEntries.isEmpty {
                Button(action: exportToMarkdown) {
                    Label(i18n.t(.ai_review_export), systemImage: "square.and.arrow.down")
                        .font(.system(size: theme.smallTextSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
        }
    }

    private var severitySummary: some View {
        let critical = diffEntries.filter { ($0["severity"] as? String ?? "") == "critical" }.count
        let warning = diffEntries.filter { ($0["severity"] as? String ?? "") == "warning" }.count
        let info = diffEntries.filter { ($0["severity"] as? String ?? "") == "info" }.count
        return HStack(spacing: theme.spacingL) {
            severityBadge(count: critical, label: i18n.t(.ai_review_sevCritical), color: theme.redDot)
            severityBadge(count: warning, label: i18n.t(.ai_review_sevWarning), color: theme.amberDot)
            severityBadge(count: info, label: i18n.t(.ai_review_sevInfo), color: theme.accent)
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private func severityBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count)")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                ForEach(Array(diffEntries.enumerated()), id: \.offset) { idx, entry in
                    diffEntryRow(entry)
                }
            }
        }
    }

    private func diffEntryRow(_ entry: [String: Any]) -> some View {
        let file = entry["file"] as? String ?? "unknown"
        let severity = entry["severity"] as? String ?? "info"
        let hunks = entry["hunks"] as? [[String: Any]] ?? []
        let color = severityColor(severity)
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(file)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Spacer()
                Text(severityLabel(severity))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .cornerRadius(4)
            }
            if !hunks.isEmpty {
                ForEach(Array(hunks.enumerated()), id: \.offset) { hIdx, hunk in
                    hunkView(hunk)
                }
            }
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private func hunkView(_ hunk: [String: Any]) -> some View {
        let lines = hunk["lines"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { lIdx, line in
                let type = line["type"] as? String ?? "context"
                let content = line["content"] as? String ?? ""
                let bgColor: Color = {
                    switch type {
                    case "added": return theme.greenDot.opacity(0.08)
                    case "removed": return theme.redDot.opacity(0.08)
                    default: return Color.clear
                    }
                }()
                let prefix: String = {
                    switch type {
                    case "added": return "+ "
                    case "removed": return "- "
                    default: return "  "
                    }
                }()
                let fgColor: Color = {
                    switch type {
                    case "added": return theme.greenDot
                    case "removed": return theme.redDot
                    default: return theme.textSecondary
                    }
                }()
                HStack(spacing: 4) {
                    Text(prefix)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(fgColor)
                        .frame(width: 16, alignment: .leading)
                    Text(content)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(fgColor)
                        .lineLimit(3)
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
                .background(bgColor)
                .cornerRadius(2)
            }
        }
        .padding(.leading, theme.spacingM)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.ai_review_empty))
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var exportSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.ai_review_exportTitle))
                .font(.system(size: theme.headlineSize, weight: .semibold))
            TextEditor(text: .constant(exportText))
                .font(.system(size: theme.smallTextSize, design: .monospaced))
                .frame(minHeight: 300)
            HStack {
                Button(i18n.t(.ai_review_copy)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportText, forType: .string)
                    reviewLog.info("Review exported to clipboard")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.accent)
                .cornerRadius(8)
                Spacer()
                Button(i18n.t(.close)) { showExportSheet = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 600, height: 450)
    }

    private func severityColor(_ s: String) -> Color {
        switch s {
        case "critical": return theme.redDot
        case "warning": return theme.amberDot
        default: return theme.accent
        }
    }

    private func severityLabel(_ s: String) -> String {
        switch s {
        case "critical": return I18nManager.shared.t(.ai_review_sevCritical)
        case "warning": return I18nManager.shared.t(.ai_review_sevWarning)
        default: return I18nManager.shared.t(.ai_review_sevInfo)
        }
    }

    func loadReview(agentId: String) {
        isLoading = true
        Task {
            do {
                let result = try await ipc.diffReviewExport(agentId: agentId, format: "markdown")
                await MainActor.run {
                    diffEntries = result["entries"] as? [[String: Any]] ?? []
                    exportText = result["markdown"] as? String ?? generateMarkdown()
                    isLoading = false
                    reviewLog.info("Diff review loaded: \(self.diffEntries.count) entries")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    reviewLog.error("Diff review failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func exportToMarkdown() {
        exportText = generateMarkdown()
        showExportSheet = true
    }

    private func generateMarkdown() -> String {
        var md = "# Code Review\n\n"
        let sorted = diffEntries.sorted { severityOrder($0["severity"] as? String ?? "") < severityOrder($1["severity"] as? String ?? "") }
        for entry in sorted {
            let file = entry["file"] as? String ?? "unknown"
            let severity = entry["severity"] as? String ?? "info"
            md += "## [\(severityLabel(severity))] \(file)\n\n"
            if let hunks = entry["hunks"] as? [[String: Any]] {
                md += "```diff\n"
                for hunk in hunks {
                    if let lines = hunk["lines"] as? [[String: Any]] {
                        for line in lines {
                            let type = line["type"] as? String ?? "context"
                            let content = line["content"] as? String ?? ""
                            let prefix = type == "added" ? "+" : type == "removed" ? "-" : " "
                            md += "\(prefix) \(content)\n"
                        }
                    }
                }
                md += "```\n\n"
            }
        }
        return md
    }

    private func severityOrder(_ s: String) -> Int {
        switch s {
        case "critical": return 0
        case "warning": return 1
        default: return 2
        }
    }
}
