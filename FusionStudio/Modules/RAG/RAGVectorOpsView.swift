import SwiftUI
import os

private let vecLog = Logger(subsystem: "com.fusion.studio", category: "RAGVectorOps")

struct RAGVectorOpsView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
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
                Text("向量库运维")
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
        .alert("确认增量同步", isPresented: $showSyncConfirm) {
            Button("取消", role: .cancel) {}
            Button("同步", role: .destructive) { Task { await incrementalSync() } }
        } message: {
            Text("将对知识库目录执行增量同步，检测文件变更并重新索引。确定继续？")
        }
        .sheet(isPresented: $showCreateSnapshot) {
            VStack(spacing: theme.spacingM) {
                Text("创建版本快照").font(.headline)
                TextField("快照描述（可选）", text: $snapshotDesc).textFieldStyle(.roundedBorder)
                HStack {
                    Button("取消") { showCreateSnapshot = false; snapshotDesc = "" }
                    Spacer()
                    Button("创建") {
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
            Label("服务状态", systemImage: "server.rack")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXL) {
                statusItem("嵌入引擎", value: serviceStatus?["embedding_available"] as? Bool == true ? "可用" : "不可用", icon: "cpu", color: serviceStatus?["embedding_available"] as? Bool == true ? .green : .red)
                statusItem("知识库数", value: "\(serviceStatus?["knowledge_bases"] as? Int ?? 0)", icon: "archivebox", color: .blue)
                statusItem("服务状态", value: serviceStatus?["status"] as? String ?? "-", icon: "checkmark.circle", color: .green)
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
            Label("向量统计", systemImage: "chart.bar.xaxis")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if let s = stats {
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible()),
                ], spacing: theme.spacingM) {
                    statCard("文档数", value: "\(s.documents)", icon: "doc", color: .blue)
                    statCard("分块数", value: "\(s.chunks)", icon: "square.grid.2x2", color: .green)
                    statCard("向量数", value: "\(s.vectors)", icon: "arrow.triangle.2.circlepath", color: .purple)
                    statCard("文件数", value: "\(s.fileCount ?? 0)", icon: "folder", color: .orange)
                }
            } else if selectedKBId.isEmpty {
                Text("请先选择知识库").foregroundStyle(theme.textTertiary)
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
            Label("运维操作", systemImage: "wrench.and.screwdriver")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if let msg = operationMsg {
                Text(msg)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(msg.hasPrefix("✓") ? .green : msg.hasPrefix("✗") ? .red : .orange)
            }
            VStack(spacing: theme.spacingS) {
                opRow("增量同步", desc: "检测文件变更并重新索引", icon: "arrow.triangle.2.circlepath", color: .orange, destructive: true) {
                    showSyncConfirm = true
                }
                opRow("创建快照", desc: "保存当前知识库状态到版本快照", icon: "camera", color: .blue, destructive: false) {
                    showCreateSnapshot = true
                }
                opRow("健康检查", desc: "检查向量存储和嵌入服务状态", icon: "heart.text.square", color: .green, destructive: false) {
                    Task { await healthCheck() }
                }
                opRow("刷新统计", desc: "重新获取知识库统计信息", icon: "arrow.clockwise", color: .purple, destructive: false) {
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
                Label("版本快照", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                if !snapshots.isEmpty {
                    Text("\(snapshots.count) 个快照")
                        .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                }
            }
            if snapshots.isEmpty {
                Text("暂无快照，点击「创建快照」保存当前知识库状态")
                    .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(snapshots.indices, id: \.self) { i in
                    snapshotRow(snapshots[i])
                }
            }
            Text("版本快照是 Fusion-RAG 相对 Claude RAG 的关键竞争力：支持时间点回滚、增量对比、数据恢复。")
                .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func snapshotRow(_ snap: [String: Any]) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(snap["description"] as? String ?? snap["version_id"] as? String ?? "快照")
                    .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.text)
                if let ts = snap["created_at"] as? Double {
                    Text(formatTimestamp(ts))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { Task { await rollbackSnapshot(snap["version_id"] as? String ?? "") } }) {
                Text("回滚").font(.system(size: theme.captionSize))
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
        operationMsg = "同步中..."
        if let result = await client.incrementalSync(kbId: selectedKBId, directory: "/Users/dahai/fusion") {
            let indexed = result["files_indexed"] as? Int ?? 0
            operationMsg = "✓ 同步完成: \(indexed) 文件已更新"
            await refresh()
        } else {
            operationMsg = "✗ 同步失败"
        }
    }

    private func createSnapshot() async {
        guard !selectedKBId.isEmpty else { return }
        operationMsg = "创建快照中..."
        if let result = await client.createSnapshot(kbId: selectedKBId, description: snapshotDesc) {
            let vid = result["version_id"] as? String ?? ""
            operationMsg = "✓ 快照已创建: \(vid)"
            snapshotDesc = ""
            await refresh()
        } else {
            operationMsg = "✗ 快照创建失败"
        }
    }

    private func rollbackSnapshot(_ versionId: String) async {
        guard !selectedKBId.isEmpty, !versionId.isEmpty else { return }
        operationMsg = "回滚中..."
        if await client.rollbackSnapshot(kbId: selectedKBId, versionId: versionId) {
            operationMsg = "✓ 已回滚到快照 \(versionId)"
            await refresh()
        } else {
            operationMsg = "✗ 回滚失败"
        }
    }

    private func healthCheck() async {
        let healthy = await client.healthCheck()
        operationMsg = healthy ? "✓ 服务健康" : "✗ 服务异常"
        serviceStatus = await client.serviceStatus()
    }
}
