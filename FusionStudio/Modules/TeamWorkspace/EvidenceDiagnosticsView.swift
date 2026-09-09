import SwiftUI
import os.log

private let evidenceDiagLog = Logger(subsystem: "com.fusion.studio", category: "EvidenceDiagnosticsView")

// M2-5: EvidenceDiagnostics — evidence list from evidence.list/evidence.failure RPCs.
// Full mode (upstream #316 merged 625b66e): dedicated evidence listing by team.
// Toggle: all evidence vs failed-only (evidence.failure).
struct EvidenceDiagnosticsView: View {
    @EnvironmentObject var teamBridge: TeamBridge
    @State private var showFailedOnly: Bool = true

    private var evidence: [TeamEvidence] {
        showFailedOnly
            ? teamBridge.evidence.filter { $0.isFailed }
            : teamBridge.evidence
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if evidence.isEmpty {
                emptyState
            } else {
                evidenceList
            }
        }
        .onAppear {
            Task {
                if showFailedOnly {
                    await teamBridge.refreshFailedEvidence()
                } else {
                    await teamBridge.refreshEvidence()
                }
            }
            evidenceDiagLog.info("EvidenceDiagnosticsView appeared evidence=\(self.evidence.count)")
        }
    }

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: 16) {
            summaryItem(count: teamBridge.evidence.count, label: "Total", color: .accentColor)
            summaryItem(count: teamBridge.evidence.filter { $0.isFailed }.count, label: "Failed", color: .red)
            Spacer()
            Picker("", selection: $showFailedOnly) {
                Text("Failed Only").tag(true)
                Text("All Evidence").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: showFailedOnly) { failed in
                Task {
                    if failed {
                        await teamBridge.refreshFailedEvidence()
                    } else {
                        await teamBridge.refreshEvidence()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func summaryItem(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - List

    private var evidenceList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(evidence) { ev in
                    EvidenceCard(evidence: ev)
                }
            }
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("No evidence entries")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Evidence card

private struct EvidenceCard: View {
    let evidence: TeamEvidence
    @State private var showDetail: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: evidence.isFailed ? "xmark.octagon.fill" : "doc.text.fill")
                    .foregroundColor(evidence.isFailed ? .red : .accentColor)
                    .font(.system(size: 12))
                Text(evidence.taskId)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                statusBadge
            }
            DisclosureGroup(isExpanded: $showDetail) {
                detail
            } label: {
                Text(evidence.evidenceRef.isEmpty ? "no evidence path" : evidence.evidenceRef)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var statusBadge: some View {
        Text(evidence.status.isEmpty ? "unknown" : evidence.status)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(evidence.isFailed ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
            .cornerRadius(4)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !evidence.executionId.isEmpty {
                detailRow(label: "Execution", value: evidence.executionId)
            }
            if !evidence.evidenceRef.isEmpty {
                detailRow(label: "Path", value: evidence.evidenceRef)
            }
            if evidence.eventsCount > 0 {
                detailRow(label: "Events", value: "\(evidence.eventsCount)")
            }
            if evidence.createdAt > 0 {
                let date = Date(timeIntervalSince1970: evidence.createdAt)
                detailRow(label: "Created", value: DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium))
            }
        }
        .padding(.top, 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
