import SwiftUI
import os

private let vecLog = Logger(subsystem: "com.fusion.studio", category: "RAGVectorOps")

struct RAGVectorOpsView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @StateObject private var i18n = I18nManager.shared
    @State private var stats: KBStats?
    @State private var serviceStatus: [String: Any]?
    @State private var snapshots: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showSyncConfirm = false
    @State private var operationMsg: String?
    @State private var snapshotDesc = ""
    @State private var showCreateSnapshot = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.rag_vec_title))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                serviceCard
                vectorStatsCard
                operationsCard
                snapshotsCard
            }
            .padding(theme.spacingL)
        }
        .task { await refresh() }
        .onChange(of: selectedKBId) { _ in Task { await refresh() } }
        .alert(i18n.t(.rag_vec_syncAlertTitle), isPresented: $showSyncConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.rag_vec_syncAlertBtn), role: .destructive) { Task { await incrementalSync() } }
        } message: {
            Text(i18n.t(.rag_vec_syncAlertMsg))
        }
        .sheet(isPresented: $showCreateSnapshot) {
            VStack(spacing: theme.spacingM) {
                Text(i18n.t(.rag_vec_createSnapTitle)).font(.headline)
                TextField(i18n.t(.rag_vec_snapDescPh), text: $snapshotDesc).textFieldStyle(.roundedBorder)
                HStack {
                    Button(i18n.t(.cancel)) { showCreateSnapshot = false; snapshotDesc = "" }
                    Spacer()
                    Button(i18n.t(.rag_vec_create)) {
                        Task { await createSnapshot() }
                        showCreateSnapshot = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20).frame(width: 350)
        }
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_vec_svcLabel), systemImage: "server.rack")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXL) {
                statusItem(i18n.t(.rag_vec_embEngine), value: serviceStatus?["embedding_available"] as? Bool == true ? i18n.t(.rag_vec_avail) : i18n.t(.rag_vec_unavail), icon: "cpu", color: serviceStatus?["embedding_available"] as? Bool == true ? .green : .red)
                statusItem(i18n.t(.rag_vec_kbCount), value: "\(serviceStatus?["knowledge_bases"] as? Int ?? 0)", icon: "archivebox", color: .blue)
                statusItem(i18n.t(.rag_vec_svcLabel), value: serviceStatus?["status"] as? String ?? "-", icon: "checkmark.circle", color: .green)
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func statusItem(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: icon).font(.system(size: theme.iconL)).foregroundStyle(color)
            Text(value).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var vectorStatsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_vec_vecStatsLabel), systemImage: "chart.bar.xaxis")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if let s = stats {
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible()),
                ], spacing: theme.spacingM) {
                    statCard(i18n.t(.rag_vec_docCount), value: "\(s.documents)", icon: "doc", color: .blue)
                    statCard(i18n.t(.rag_vec_chunkCount), value: "\(s.chunks)", icon: "square.grid.2x2", color: .green)
                    statCard(i18n.t(.rag_vec_vecCount), value: "\(s.vectors)", icon: "arrow.triangle.2.circlepath", color: .purple)
                    statCard(i18n.t(.rag_vec_fileCount), value: "\(s.fileCount ?? 0)", icon: "folder", color: .orange)
                }
            } else if selectedKBId.isEmpty {
                Text(i18n.t(.rag_vec_selectKbHint)).foregroundStyle(theme.textTertiary)
            } else {
                ProgressView()
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func statCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: icon).font(.system(size: theme.iconM)).foregroundStyle(color)
            Text(value).font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(color.opacity(0.06)))
    }

    private var operationsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_vec_opsLabel), systemImage: "wrench.and.screwdriver")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if let msg = operationMsg {
                Text(msg)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(msg.hasPrefix("✓") ? .green : msg.hasPrefix("✗") ? .red : .orange)
            }
            VStack(spacing: theme.spacingS) {
                opRow(i18n.t(.rag_vec_opSync), desc: i18n.t(.rag_vec_opSyncDesc), icon: "arrow.triangle.2.circlepath", color: .orange, destructive: true) {
                    showSyncConfirm = true
                }
                opRow(i18n.t(.rag_vec_opSnap), desc: i18n.t(.rag_vec_opSnapDesc), icon: "camera", color: .blue, destructive: false) {
                    showCreateSnapshot = true
                }
                opRow(i18n.t(.rag_vec_opHealth), desc: i18n.t(.rag_vec_opHealthDesc), icon: "heart.text.square", color: .green, destructive: false) {
                    Task { await healthCheck() }
                }
                opRow(i18n.t(.rag_vec_opRefresh), desc: i18n.t(.rag_vec_opRefreshDesc), icon: "arrow.clockwise", color: .purple, destructive: false) {
                    Task { await refresh() }
                }
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func opRow(_ title: String, desc: String, icon: String, color: Color, destructive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: icon).font(.system(size: theme.iconS)).foregroundStyle(color).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(destructive ? .red : theme.text)
                    Text(desc).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(color.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }

    private var snapshotsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Label(i18n.t(.rag_vec_snapLabel), systemImage: "clock.arrow.circlepath")
                    .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                if !snapshots.isEmpty {
                    Text(String(format: i18n.t(.rag_vec_snapCountFmt), snapshots.count))
                        .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                }
            }
            if snapshots.isEmpty {
                Text(i18n.t(.rag_vec_snapEmpty))
                    .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(snapshots.indices, id: \.self) { i in
                    snapshotRow(snapshots[i])
                }
            }
            Text(i18n.t(.rag_vec_snapNote))
                .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func snapshotRow(_ snap: [String: Any]) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(snap["description"] as? String ?? snap["version_id"] as? String ?? i18n.t(.rag_vec_snapFallback))
                    .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.text)
                if let ts = snap["created_at"] as? Double {
                    Text(formatTimestamp(ts))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { Task { await rollbackSnapshot(snap["version_id"] as? String ?? "") } }) {
                Text(i18n.t(.rag_vec_rollback)).font(.system(size: theme.captionSize))
            }
            .buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary)
    }
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1)
    }

    private func formatTimestamp(_ ts: Double) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: Date(timeIntervalSince1970: ts))
    }

    private func refresh() async {
        guard !selectedKBId.isEmpty else { stats = nil; return }
        isLoading = true
        async let s = client.getStats(kbId: selectedKBId)
        async let st = client.serviceStatus()
        async let sn = client.listSnapshots(kbId: selectedKBId)
        stats = await s
        serviceStatus = await st
        snapshots = await sn
        isLoading = false
        vecLog.info("Vector ops refreshed for kb=\(selectedKBId), snapshots=\(snapshots.count)")
    }

    private func incrementalSync() async {
        guard !selectedKBId.isEmpty else { return }
        operationMsg = i18n.t(.rag_vec_syncing)
        if let result = await client.incrementalSync(kbId: selectedKBId, directory: "/Users/dahai/fusion") {
            let indexed = result["files_indexed"] as? Int ?? 0
            operationMsg = String(format: i18n.t(.rag_vec_syncDoneFmt), indexed)
            await refresh()
        } else {
            operationMsg = i18n.t(.rag_vec_syncFail)
        }
    }

    private func createSnapshot() async {
        guard !selectedKBId.isEmpty else { return }
        operationMsg = i18n.t(.rag_vec_creatingSnap)
        if let result = await client.createSnapshot(kbId: selectedKBId, description: snapshotDesc) {
            let vid = result["version_id"] as? String ?? ""
            operationMsg = String(format: i18n.t(.rag_vec_snapDoneFmt), vid)
            snapshotDesc = ""
            await refresh()
        } else {
            operationMsg = i18n.t(.rag_vec_snapFail)
        }
    }

    private func rollbackSnapshot(_ versionId: String) async {
        guard !selectedKBId.isEmpty, !versionId.isEmpty else { return }
        operationMsg = i18n.t(.rag_vec_rollingBack)
        if await client.rollbackSnapshot(kbId: selectedKBId, versionId: versionId) {
            operationMsg = String(format: i18n.t(.rag_vec_rollbackDoneFmt), versionId)
            await refresh()
        } else {
            operationMsg = i18n.t(.rag_vec_rollbackFail)
        }
    }

    private func healthCheck() async {
        let healthy = await client.healthCheck()
        operationMsg = healthy ? i18n.t(.rag_vec_svcHealthy) : i18n.t(.rag_vec_svcUnhealthy)
        serviceStatus = await client.serviceStatus()
    }
}
