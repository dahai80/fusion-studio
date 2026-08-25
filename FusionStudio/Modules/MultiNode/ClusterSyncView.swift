import SwiftUI
import os.log

private let syncLog = Logger(subsystem: "com.fusion.studio", category: "ClusterSync")

struct ClusterSyncView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var modelNameInput = ""
    @State private var sourceHostInput = "127.0.0.1"
    @State private var sourcePortInput = "11452"
    @State private var isSyncing = false
    @State private var syncResult: String?
    @State private var manifestDisplay: ModelManifest?
    @State private var showManifest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_sync_title), subtitle: i18n.t(.mn_sync_subtitle))

                syncStatusSection
                incrementalSyncSection
                modelManifestSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
    }

    private var syncStatusSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_sync_partitionState))

            HStack(spacing: theme.spacingM) {
                partitionStateCard
                degradedCard
                syncAvailableCard
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingM)

            if let status = engine.clusterSyncStatus,
               let partition = status.partition,
               let nodes = partition.nodes, !nodes.isEmpty {
                StudioSectionHeader(title: i18n.t(.mn_sync_partitionNodes))
                ForEach(Array(nodes.keys).sorted(), id: \.self) { nodeId in
                    HStack(spacing: theme.spacingM) {
                        Circle()
                            .fill(nodeStatusColor(nodes[nodeId]?.status))
                            .frame(width: 8, height: 8)
                        Text(nodeId)
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        if let ago = nodes[nodeId]?.lastHeartbeatAgo {
                            Text(String(format: "%.1fs ago", ago))
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingXS)
                }
            }
        }
    }

    private var partitionStateCard: some View {
        let status = engine.clusterSyncStatus
        let state = status?.partitionState ?? "unknown"
        let color: Color = state == "connected" ? theme.greenDot : (state == "partitioned" ? theme.redDot : theme.amberDot)
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.mn_sync_partitionState))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(state)
                .font(.system(size: theme.textSize, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var degradedCard: some View {
        let isDegraded = engine.clusterSyncStatus?.isDegraded ?? false
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.mn_sync_isDegraded))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(isDegraded ? i18n.t(.mn_sync_degraded) : i18n.t(.mn_sync_normal))
                .font(.system(size: theme.textSize, weight: .bold, design: .rounded))
                .foregroundStyle(isDegraded ? theme.redDot : theme.greenDot)
        }
        .padding(theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var syncAvailableCard: some View {
        let available = engine.clusterSyncStatus?.syncAvailable ?? false
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.mn_sync_syncAvailable))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(available ? i18n.t(.mn_sync_available) : i18n.t(.mn_sync_unavailable))
                .font(.system(size: theme.textSize, weight: .bold, design: .rounded))
                .foregroundStyle(available ? theme.greenDot : theme.textTertiary)
        }
        .padding(theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var incrementalSyncSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_sync_incrementalTitle))

            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.mn_sync_modelName))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.mn_sync_modelPh), text: $modelNameInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize))
                        .padding(theme.spacingS)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                }

                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.mn_sync_sourceHost))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    TextField("127.0.0.1", text: $sourceHostInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize, design: .monospaced))
                        .padding(theme.spacingS)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                }

                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.mn_sync_sourcePort))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    TextField("11452", text: $sourcePortInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize, design: .monospaced))
                        .frame(width: 80)
                        .padding(theme.spacingS)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                }

                FusionButton(isSyncing ? i18n.t(.mn_sync_syncing) : i18n.t(.mn_sync_triggerBtn), style: .primary, size: .regular) {
                    triggerSync()
                }
                .disabled(isSyncing || modelNameInput.isEmpty)
            }
            .padding(.horizontal, theme.spacingL)

            if let result = syncResult {
                Text(result)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.top, theme.spacingXS)
            }
        }
    }

    private var modelManifestSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_sync_manifestTitle))

            HStack(spacing: theme.spacingM) {
                TextField(i18n.t(.mn_sync_manifestPh), text: $modelNameInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .padding(theme.spacingS)
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))

                FusionButton(i18n.t(.mn_sync_viewBtn), style: .secondary, size: .small) {
                    fetchManifest()
                }
                .disabled(modelNameInput.isEmpty)
            }
            .padding(.horizontal, theme.spacingL)

            if let manifest = manifestDisplay {
                manifestDetailView(manifest)
            }
        }
    }

    private func manifestDetailView(_ manifest: ModelManifest) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingM) {
                Text(manifest.modelName)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let mid = manifest.modelId {
                    Text(mid)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if let total = manifest.totalSize {
                    Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, theme.spacingL)

            if let files = manifest.files, !files.isEmpty {
                ForEach(files) { file in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                        Text(file.path)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer()
                        if let size = file.size {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingXL)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, theme.spacingS)
    }

    private func nodeStatusColor(_ status: String?) -> Color {
        switch status {
        case "online": return theme.greenDot
        case "busy": return theme.amberDot
        case "offline": return theme.textTertiary
        case "fault": return theme.redDot
        default: return theme.textTertiary
        }
    }

    private func triggerSync() {
        guard !modelNameInput.isEmpty else { return }
        isSyncing = true
        syncResult = nil
        let port = Int(sourcePortInput) ?? 11452
        engine.triggerIncrementalSync(
            modelName: modelNameInput,
            sourceHost: sourceHostInput,
            sourcePort: port
        ) { result in
            DispatchQueue.main.async {
                isSyncing = false
                switch result {
                case .success(let json):
                    let synced = json["synced"] as? Int ?? 0
                    let status = json["status"] as? String ?? ""
                    if status == "up_to_date" {
                        syncResult = String(format: i18n.t(.mn_sync_upToDateFmt), modelNameInput)
                    } else {
                        syncResult = String(format: i18n.t(.mn_sync_syncDoneFmt), synced)
                    }
                    syncLog.info("Incremental sync result: \(json)")
                case .failure(let err):
                    syncResult = String(format: i18n.t(.mn_sync_syncFailFmt), err.localizedDescription)
                    syncLog.error("Incremental sync failed: \(err.localizedDescription)")
                }
            }
        }
    }

    private func fetchManifest() {
        guard !modelNameInput.isEmpty else { return }
        engine.fetchModelManifest(modelName: modelNameInput) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let manifest):
                    manifestDisplay = manifest
                    syncLog.info("Manifest fetched for \(manifest.modelName), files: \(manifest.files?.count ?? 0)")
                case .failure(let err):
                    manifestDisplay = nil
                    syncLog.error("Failed to fetch manifest: \(err.localizedDescription)")
                }
            }
        }
    }
}
