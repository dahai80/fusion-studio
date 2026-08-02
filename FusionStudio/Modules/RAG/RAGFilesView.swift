import SwiftUI
import os

private let filesLog = Logger(subsystem: "com.fusion.studio", category: "RAGFiles")

struct RAGFilesView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @State private var documents: [KBDocument] = []
    @State private var watches: [KBWatchInfo] = []
    @State private var isLoading = false
    @State private var showAddFile = false
    @State private var addFilePath = ""
    @State private var showWatch = false
    @State private var watchPaths = ""
    @State private var watchInterval = 30
    @State private var searchQuery = ""

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingM) {
                toolbar
                if isLoading {
                    ProgressView().padding(theme.spacingL)
                } else if filteredDocs.isEmpty {
                    emptyState
                } else {
                    docList
                }
                watchSection
            }
            .padding(theme.spacingL)
        }
        .task { await loadDocuments() }
        .onChange(of: selectedKBId) { _ in Task { await loadDocuments() } }
        .sheet(isPresented: $showAddFile) { addFileSheet }
        .sheet(isPresented: $showWatch) { addWatchSheet }
    }

    private var toolbar: some View {
        HStack(spacing: theme.spacingS) {
            TextField("搜索文件...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Spacer()
            Button(action: { showWatch = true }) {
                Label("监控", systemImage: "eye")
                    .font(.system(size: theme.textSize))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button(action: { showAddFile = true }) {
                Label("添加文件", systemImage: "doc.badge.plus")
                    .font(.system(size: theme.textSize))
            }
            .buttonStyle(.bordered)
            Button(action: { Task { await loadDocuments() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text(selectedKBId.isEmpty ? "请先选择知识库" : "暂无文档")
                .foregroundStyle(theme.textTertiary)
            if !selectedKBId.isEmpty {
                Button("添加文件") { showAddFile = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private var filteredDocs: [KBDocument] {
        guard !searchQuery.isEmpty else { return documents }
        return documents.filter {
            $0.fileName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.filePath.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var docList: some View {
        VStack(spacing: 0) {
            docTableHeader
            Divider()
            ForEach(filteredDocs) { doc in
                docRow(doc)
                if doc.id != filteredDocs.last?.id {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        )
    }

    private var docTableHeader: some View {
        HStack(spacing: theme.spacingS) {
            Text("文件名")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("类型").frame(width: 60)
            Text("大小").frame(width: 70)
            Text("分块").frame(width: 50)
            Text("状态").frame(width: 60)
            Text("").frame(width: 60)
        }
        .font(.system(size: theme.captionSize, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private func docRow(_ doc: KBDocument) -> some View {
        HStack(spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: docIcon(doc.docType))
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(docColor(doc.docType))
                Text(doc.fileName)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(doc.docType.uppercased())
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 60)
            Text(ByteCountFormatter.string(fromByteCount: Int64(doc.size), countStyle: .file))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 70)
            Text("\(doc.chunkCount)")
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 50)
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("已索引")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            }
            .frame(width: 60)
            Button(action: { Task { await deleteDoc(doc) } }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(width: 60)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 8)
    }

    private var watchSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("文件监控")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            if watches.isEmpty {
                Text("无活跃监控")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(watches) { w in
                    watchRow(w)
                }
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        )
    }

    private func watchRow(_ w: KBWatchInfo) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "eye")
                .foregroundStyle(theme.accent)
            Text("监控 \(w.fileCount) 个文件")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text)
            if w.changesDetected > 0 {
                Text("\(w.changesDetected) 次变更")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.orange)
            }
            Spacer()
            if let last = w.lastReindex {
                Text("上次重建: \(last)")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            Button("停止") {
                Task {
                    guard !selectedKBId.isEmpty else { return }
                    let ok = await client.unwatchFiles(kbId: selectedKBId, watchId: w.id)
                    if ok { await loadWatches() }
                }
            }
            .font(.system(size: theme.captionSize))
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    private var addFileSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("添加文件").font(.headline)
            TextField("文件路径（逗号分隔多个）", text: $addFilePath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showAddFile = false; addFilePath = "" }
                Spacer()
                Button("添加") { Task { await addFiles() } }
                    .disabled(addFilePath.isEmpty || selectedKBId.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var addWatchSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("设置文件监控").font(.headline)
            TextField("文件路径（逗号分隔）", text: $watchPaths)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("轮询间隔(秒)")
                Stepper("\(watchInterval)s", value: $watchInterval, in: 10...300, step: 10)
            }
            HStack {
                Button("取消") { showWatch = false }
                Spacer()
                Button("开始监控") { Task { await startWatch() } }
                    .disabled(watchPaths.isEmpty || selectedKBId.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func docIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.richtext"
        case "md", "markdown": return "doc.text"
        case "py", "swift", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "toml": return "doc.text.below.ecg"
        default: return "doc"
        }
    }

    private func docColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "pdf": return .red
        case "md", "markdown": return .blue
        case "py", "swift", "js", "ts": return .purple
        default: return .gray
        }
    }

    private func loadDocuments() async {
        guard !selectedKBId.isEmpty else { documents = []; return }
        isLoading = true
        documents = await client.listDocuments(kbId: selectedKBId)
        await loadWatches()
        isLoading = false
        filesLog.info("Loaded \(documents.count) docs for kb=\(selectedKBId)")
    }

    private func loadWatches() async {
        guard !selectedKBId.isEmpty else { watches = []; return }
        watches = await client.watchStatus(kbId: selectedKBId)
    }

    private func addFiles() async {
        guard !selectedKBId.isEmpty else { return }
        let paths = addFilePath.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if paths.count == 1 {
            let _ = await client.uploadDocument(kbId: selectedKBId, filePath: paths[0])
        } else {
            let _ = await client.batchUpload(kbId: selectedKBId, filePaths: paths)
        }
        showAddFile = false
        addFilePath = ""
        await loadDocuments()
    }

    private func deleteDoc(_ doc: KBDocument) async {
        guard !selectedKBId.isEmpty else { return }
        let ok = await client.deleteDocument(kbId: selectedKBId, docId: doc.id)
        if ok { await loadDocuments() }
    }

    private func startWatch() async {
        guard !selectedKBId.isEmpty else { return }
        let paths = watchPaths.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let _ = await client.watchFiles(kbId: selectedKBId, filePaths: paths, pollInterval: watchInterval)
        showWatch = false
        watchPaths = ""
        await loadWatches()
    }
}
