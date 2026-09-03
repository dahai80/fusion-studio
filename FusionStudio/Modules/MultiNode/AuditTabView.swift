import SwiftUI
import os.log

struct AuditTabView: View {
    @StateObject private var i18n = I18nManager.shared
    @State private var records: [AuditRecord] = []

    private let auditLog = Logger(subsystem: "com.fusion.studio", category: "AuditTabView")

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t(.mn_audit_title)).font(.headline)
                Spacer()
                Button(i18n.t(.mn_audit_refresh)) { reload() }
            }
            .padding(12)

            Divider()

            if records.isEmpty {
                Text(i18n.t(.mn_audit_empty))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(records.reversed().enumerated()), id: \.offset) { _, rec in
                            auditRow(rec)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onAppear { reload() }
    }

    private func auditRow(_ rec: AuditRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Date(timeIntervalSince1970: TimeInterval(rec.ts))
                    .formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            Text(rec.action).font(.system(size: 11, weight: .semibold))
                .frame(width: 70, alignment: .leading)
            Text(rec.targetNode ?? rec.targetTask ?? "-")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(rec.result)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(resultColor(rec.result))
        }
    }

    private func resultColor(_ r: String) -> Color {
        switch r {
        case "ok": return .green
        case "blocked": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    private func reload() {
        records = ClusterAuditor.shared.tail(limit: 200)
        auditLog.info("reload loaded=\(records.count, privacy: .public)")
    }
}
