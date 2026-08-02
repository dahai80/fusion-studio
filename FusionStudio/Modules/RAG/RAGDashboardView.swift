import SwiftUI
import os

private let dashLog = Logger(subsystem: "com.fusion.studio", category: "RAGDashboard")

struct RAGDashboardView: View {
    @Binding var selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newChunkStrategy = "semantic"
    @State private var newEmbedModel = "BGE-M3"
    @State private var showScanDir = false
    @State private var scanDirPath = ""
    @State private var scanKBId = ""
    @State private var serviceHealthy = false
    @State private var kbStats: [String: KBStats] = [:]

    let chunkStrategies = ["semantic", "fixed", "code"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                serviceStatusBanner

                HStack {
                    Text("知识库")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { Task { await refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: theme.iconM))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("刷新")
                    Button(action: { showCreate = true }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "plus")
                            Text("新建")
                        }
                        .font(.system(size: theme.textSize, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }

                if client.knowledgeBases.isEmpty {
                    emptyState
                } else {
                    kbCardGrid
                }

                if let err = client.lastError {
                    Text(err)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(.red)
                        .padding(theme.spacingS)
                }
            }
            .padding(theme.spacingL)
        }
        .sheet(isPresented: $showCreate) { createSheet }
        .sheet(isPresented: $showScanDir) { scanDirSheet }
        .task { await refresh() }
    }

    private var serviceStatusBanner: some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(serviceHealthy ? .green : .red)
                .frame(width: 8, height: 8)
            Text(serviceHealthy ? "Fusion-RAG 服务正常" : "Fusion-RAG 服务不可用")
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(serviceHealthy ? .green : .red)
            Spacer()
            Text(client.knowledgeBases.count.description + " 个知识库")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(serviceHealthy ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        )
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("暂无知识库")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textTertiary)
            Button("创建知识库") { showCreate = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private var kbCardGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 280, maximum: 400), spacing: theme.spacingM),
            GridItem(.flexible(minimum: 280, maximum: 400), spacing: theme.spacingM),
            GridItem(.flexible(minimum: 280, maximum: 400), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(client.knowledgeBases) { kb in
                KBCardView(
                    kb: kb,
                    stats: kbStats[kb.id],
                    isSelected: selectedKBId == kb.id,
                    onSelect: { selectedKBId = kb.id },
                    onScan: {
                        scanKBId = kb.id
                        scanDirPath = ""
                        showScanDir = true
                    },
                    onDelete: {
                        Task {
                            let ok = await client.deleteBase(kbId: kb.id)
                            if ok { await refresh() }
                        }
                    },
                    onChat: {
                        selectedKBId = kb.id
                    }
                )
            }
        }
    }

    private var createSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("创建知识库").font(.headline)
            TextField("名称", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("描述", text: $newDesc)
                .textFieldStyle(.roundedBorder)
            Picker("分块策略", selection: $newChunkStrategy) {
                ForEach(chunkStrategies, id: \.self) { Text($0).tag($0) }
            }
            TextField("嵌入模型", text: $newEmbedModel)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") {
                    showCreate = false
                    newName = ""
                    newDesc = ""
                }
                Spacer()
                Button("创建") {
                    guard !newName.isEmpty else { return }
                    Task {
                        if let _ = await client.createBase(
                            name: newName, description: newDesc,
                            chunkStrategy: newChunkStrategy, embeddingModel: newEmbedModel
                        ) {
                            await refresh()
                            showCreate = false
                            newName = ""
                            newDesc = ""
                        }
                    }
                }
                .disabled(newName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var scanDirSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("扫描目录导入").font(.headline)
            if !scanKBId.isEmpty {
                Text("知识库: \(client.knowledgeBases.first(where: { $0.id == scanKBId })?.name ?? scanKBId)")
                    .foregroundStyle(.secondary)
            }
            TextField("目录路径", text: $scanDirPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showScanDir = false }
                Spacer()
                Button("开始扫描") {
                    guard !scanKBId.isEmpty, !scanDirPath.isEmpty else { return }
                    Task {
                        let _ = await client.scanDirectory(kbId: scanKBId, dirPath: scanDirPath)
                        showScanDir = false
                        await refresh()
                    }
                }
                .disabled(scanDirPath.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func refresh() async {
        serviceHealthy = await client.healthCheck()
        await client.listBases()
        for kb in client.knowledgeBases {
            if let stats = await client.getStats(kbId: kb.id) {
                kbStats[kb.id] = stats
            }
        }
        dashLog.info("RAG dashboard refreshed: \(client.knowledgeBases.count) bases, healthy=\(serviceHealthy)")
    }
}

struct KBCardView: View {
    let kb: KBInfo
    let stats: KBStats?
    let isSelected: Bool
    let onSelect: () -> Void
    let onScan: () -> Void
    let onDelete: () -> Void
    let onChat: () -> Void

    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kb.name)
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(kb.description)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }

            Divider()

            HStack(spacing: theme.spacingM) {
                statBadge(icon: "doc", label: "文件", value: stats?.documents ?? kb.fileCount ?? 0)
                statBadge(icon: "square.grid.2x2", label: "分块", value: stats?.chunks ?? kb.chunkCount ?? 0)
                if let vectors = stats?.vectors {
                    statBadge(icon: "arrow.triangle.2.circlepath", label: "向量", value: vectors)
                }
                Spacer()
            }

            if let model = kb.embeddingModel {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "cpu")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    Text(model)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            HStack(spacing: theme.spacingS) {
                Button(action: onSelect) {
                    Label("进入", systemImage: "arrow.right.circle")
                        .font(.system(size: theme.captionSize, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onScan) {
                    Label("导入", systemImage: "folder.badge.plus")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Menu {
                    Button(action: onChat) {
                        Label("RAG 对话", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button(action: onScan) {
                        Label("扫描目录", systemImage: "folder.badge.plus")
                    }
                    Divider()
                    Button(action: onDelete, label: {
                        Label("删除", systemImage: "trash")
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.5) : theme.separator, lineWidth: isSelected ? 2 : 1)
        )
    }

    private func statBadge(icon: String, label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.accent)
            Text("\(value)")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(theme.textTertiary)
        }
    }
}
