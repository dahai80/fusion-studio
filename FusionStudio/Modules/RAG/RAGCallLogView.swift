import SwiftUI
import os

private let logLog = Logger(subsystem: "com.fusion.studio", category: "RAGCallLog")

struct RAGCallEntry: Identifiable {
    let id: String
    let timestamp: Double
    let kbId: String
    let kbName: String
    let operation: String
    let query: String
    let resultsCount: Int
    let latencyMs: Double
    let caller: String
    let success: Bool
}

struct RAGCallLogView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var client: RAGAPIClient
    @StateObject private var i18n = I18nManager.shared
    @State private var entries: [RAGCallEntry] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var filterOp = "all"
    @State private var showExportSheet = false
    @Binding var selectedKbId: String

    let operations = ["all", "search", "ask", "ingest", "delete", "watch", "sync"]

    private func opLabel(_ op: String) -> String {
        switch op {
        case "all": return i18n.t(.rag_op_all)
        case "search": return i18n.t(.rag_op_search)
        case "ask": return i18n.t(.rag_op_ask)
        case "ingest": return i18n.t(.rag_op_ingest)
        case "delete": return i18n.t(.rag_op_delete)
        case "watch": return i18n.t(.rag_op_watch)
        case "sync": return i18n.t(.rag_op_sync)
        default: return op
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.rag_log_title))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                statsBar
                toolbar
                logTable
            }
            .padding(theme.spacingL)
        }
        .task { await loadLogs() }
        .sheet(isPresented: $showExportSheet) { exportSheet }
    }

    private var statsBar: some View {
        HStack(spacing: theme.spacingM) {
            let total = entries.count
            let successRate = total > 0 ? Double(entries.filter(\.success).count) / Double(total) * 100 : 0
            let avgLatency = total > 0 ? entries.map(\.latencyMs).reduce(0, +) / Double(total) : 0
            let searchCount = entries.filter { $0.operation == "search" }.count
            let askCount = entries.filter { $0.operation == "ask" }.count
            miniStat(i18n.t(.rag_log_total), value: "\(total)", icon: "number", color: .blue)
            miniStat(i18n.t(.rag_log_successRate), value: String(format: "%.1f%%", successRate), icon: "checkmark.circle", color: .green)
            miniStat(i18n.t(.rag_log_avgLatency), value: String(format: "%.0fms", avgLatency), icon: "clock", color: .orange)
            miniStat(i18n.t(.rag_log_search), value: "\(searchCount)", icon: "magnifyingglass", color: .purple)
            miniStat(i18n.t(.rag_log_ask), value: "\(askCount)", icon: "bubble.left.and.bubble.right", color: .cyan)
        }
    }

    private func miniStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: theme.iconS)).foregroundStyle(color)
            Text(value).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            Text(label).font(.system(size: 8)).foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(color.opacity(0.06)))
    }

    private var toolbar: some View {
        HStack(spacing: theme.spacingS) {
            TextField(i18n.t(.rag_log_searchPh), text: $searchText).textFieldStyle(.roundedBorder).frame(maxWidth: 200)
            Picker(i18n.t(.rag_log_opPicker), selection: $filterOp) {
                ForEach(operations, id: \.self) { op in Text(opLabel(op)).tag(op) }
            }
            .frame(width: 100).labelsHidden()
            Spacer()
            Button(action: { Task { await loadLogs() } }) {
                Image(systemName: "arrow.clockwise").font(.system(size: theme.iconS)).foregroundStyle(theme.textTertiary)
            }.buttonStyle(.plain)
            Button(action: { showExportSheet = true }) {
                Label(i18n.t(.rag_log_export), systemImage: "square.and.arrow.down").font(.system(size: theme.textSize))
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private var filteredEntries: [RAGCallEntry] {
        var result = entries
        if filterOp != "all" { result = result.filter { $0.operation == filterOp } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.query.localizedCaseInsensitiveContains(searchText) ||
                $0.kbName.localizedCaseInsensitiveContains(searchText) ||
                $0.caller.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var logTable: some View {
        VStack(spacing: 0) {
            logTableHeader
            Divider()
            if filteredEntries.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 32)).foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.rag_log_empty)).foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, theme.spacing2XL)
            } else {
                ForEach(filteredEntries) { entry in
                    logRow(entry)
                    if entry.id != filteredEntries.last?.id { Divider().padding(.leading, 44) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1))
    }

    private var logTableHeader: some View {
        HStack(spacing: theme.spacingS) {
            Text(i18n.t(.rag_log_h_time)).frame(width: 140)
            Text(i18n.t(.rag_log_h_kb)).frame(width: 100)
            Text(i18n.t(.rag_log_h_op)).frame(width: 60)
            Text(i18n.t(.rag_log_h_query)).frame(maxWidth: .infinity, alignment: .leading)
            Text(i18n.t(.rag_log_h_result)).frame(width: 50)
            Text(i18n.t(.rag_log_h_latency)).frame(width: 60)
            Text(i18n.t(.rag_log_h_status)).frame(width: 50)
        }
        .font(.system(size: theme.captionSize, weight: .semibold)).foregroundStyle(theme.textTertiary)
        .padding(.horizontal, theme.spacingM).padding(.vertical, theme.spacingS)
    }

    private func logRow(_ entry: RAGCallEntry) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(formatTimestamp(entry.timestamp))
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.textSecondary).frame(width: 140)
            Text(entry.kbName).font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text).lineLimit(1).frame(width: 100)
            opBadge(entry.operation).frame(width: 60)
            Text(entry.query.prefix(40)).font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(entry.resultsCount)").font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text).frame(width: 50)
            Text(String(format: "%.0fms", entry.latencyMs)).font(.system(size: theme.captionSize))
                .foregroundStyle(entry.latencyMs > 1000 ? .orange : theme.textSecondary).frame(width: 60)
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .font(.system(size: theme.captionSize)).frame(width: 50)
        }
        .padding(.horizontal, theme.spacingM).padding(.vertical, 6)
    }

    private func opBadge(_ op: String) -> some View {
        let color: Color = {
            switch op {
            case "search": return .blue; case "ask": return .purple
            case "ingest": return .green; case "delete": return .red
            case "watch": return .orange; case "sync": return .cyan; default: return .gray
            }
        }()
        return Text(opLabel(op))
            .font(.system(size: 8, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private var exportSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.rag_log_exportTitle)).font(.headline)
            Text(String(format: i18n.t(.rag_log_exportDescFmt), filteredEntries.count)).foregroundStyle(.secondary)
            HStack {
                Button(i18n.t(.cancel)) { showExportSheet = false }
                Spacer()
                Button(i18n.t(.rag_log_exportBtn)) { exportCSV(); showExportSheet = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 350)
    }

    private func formatTimestamp(_ ts: Double) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MM-dd HH:mm:ss"
        return fmt.string(from: Date(timeIntervalSince1970: ts))
    }

    private func loadLogs() async {
        guard !selectedKbId.isEmpty else {
            logLog.warning("No KB selected for audit logs")
            return
        }
        isLoading = true
        let rawLogs = await client.listAuditLogs(kbId: selectedKbId, limit: 100)
        entries = rawLogs.compactMap { l -> RAGCallEntry? in
            guard let id = l["id"] as? String ?? l["log_id"] as? String else { return nil }
            return RAGCallEntry(
                id: id,
                timestamp: l["timestamp"] as? Double ?? Date().timeIntervalSince1970,
                kbId: l["kb_id"] as? String ?? selectedKbId,
                kbName: l["kb_name"] as? String ?? "",
                operation: l["operation"] as? String ?? l["action"] as? String ?? "",
                query: l["query"] as? String ?? "",
                resultsCount: l["results_count"] as? Int ?? 0,
                latencyMs: l["latency_ms"] as? Double ?? 0,
                caller: l["caller"] as? String ?? l["user_id"] as? String ?? "",
                success: l["success"] as? Bool ?? true
            )
        }
        isLoading = false
        logLog.info("Call log loaded: \(entries.count) entries from audit API")
    }

    private func exportCSV() {
        guard !selectedKbId.isEmpty else { return }
        Task {
            if let exported = await client.exportAuditLogs(kbId: selectedKbId, format: "csv") {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = "rag-audit-\(selectedKbId).csv"
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        try? exported.write(to: url, atomically: true, encoding: .utf8)
                        logLog.info("Audit CSV exported to \(url.path)")
                    }
                }
                return
            }
        }
        let header = "timestamp,kb_name,operation,query,results_count,latency_ms,success\n"
        let rows = filteredEntries.map { e in
            let q = e.query.replacingOccurrences(of: "\"", with: "\"\"")
            return "\(formatTimestamp(e.timestamp)),\(e.kbName),\(e.operation),\"\(q)\",\(e.resultsCount),\(Int(e.latencyMs)),\(e.success)"
        }.joined(separator: "\n")
        let csv = header + rows
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "rag-call-log.csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
                logLog.info("CSV exported to \(url.path)")
            }
        }
    }
}
