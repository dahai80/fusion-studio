// Callers: ModuleDetailView routing.
// Affected API: RAGPipelineView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Combine

// MARK: - 文档块

struct DocumentChunk: Identifiable, Hashable {
    let id: String
    let documentId: String
    let content: String
    let embedding: [Float]?
    let metadata: [String: String]
    let chunkIndex: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocumentChunk, rhs: DocumentChunk) -> Bool { lhs.id == rhs.id }
}

// MARK: - 检索结果

struct RetrievalResult: Identifiable, Hashable {
    let id: String
    let chunk: DocumentChunk
    let score: Double
    let rank: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RetrievalResult, rhs: RetrievalResult) -> Bool { lhs.id == rhs.id }
}

// MARK: - 检索策略

enum RetrievalStrategy: String, CaseIterable {
    case dense   = "稠密检索"
    case sparse  = "稀疏检索"
    case hybrid  = "混合检索"
    case rerank  = "重排序"

    var description: String {
        switch self {
        case .dense:  return "使用 MLX 嵌入模型进行语义搜索"
        case .sparse: return "使用 BM25 关键词匹配"
        case .hybrid: return "融合稠密和稀疏检索结果"
        case .rerank: return "使用交叉编码器重排序"
        }
    }
    var icon: String {
        switch self {
        case .dense:  return "circle.grid.3x3"
        case .sparse: return "text.magnifyingglass"
        case .hybrid: return "arrow.triangle.branch"
        case .rerank: return "arrow.up.arrow.down"
        }
    }
}

// MARK: - 分块策略

enum ChunkStrategy: String, CaseIterable {
    case fixed    = "固定大小"
    case semantic = "语义分块"
    case sliding  = "滑动窗口"
    case recursive = "递归分块"

    var description: String {
        switch self {
        case .fixed:    return "按固定 token 数切分"
        case .semantic: return "按语义段落切分"
        case .sliding:  return "滑动窗口重叠分块"
        case .recursive: return "递归切分保持结构"
        }
    }
}

// MARK: - RAG 流水线

struct RAGPipelineConfig {
    var chunkSize: Int = 512
    var chunkOverlap: Int = 64
    var strategy: ChunkStrategy = .fixed
    var retrievalStrategy: RetrievalStrategy = .hybrid
    var topK: Int = 5
    var minScore: Double = 0.3
    var enableRerank: Bool = true
    var maxContextLength: Int = 4096
    var includeMetadata: Bool = true
}

// MARK: - RAG 引擎

class RAGEngine: ObservableObject {
    static let shared = RAGEngine()

    @Published var documents: [RAGDocument] = []
    @Published var chunks: [DocumentChunk] = []
    @Published var config = RAGPipelineConfig()
    @Published var isIndexing = false
    @Published var lastQueryResults: [RetrievalResult] = []
    @Published var queryHistory: [RAGQuery] = []

    struct RAGDocument: Identifiable, Hashable {
        let id: String
        var title: String
        var content: String
        var source: String
        var chunkCount: Int
        var indexedAt: Date?
        var isIndexed: Bool

        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: RAGDocument, rhs: RAGDocument) -> Bool { lhs.id == rhs.id }
    }

    struct RAGQuery: Identifiable, Hashable {
        let id: String
        let query: String
        let strategy: RetrievalStrategy
        let results: [RetrievalResult]
        let timestamp: Date
        let latencyMs: Double

        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: RAGQuery, rhs: RAGQuery) -> Bool { lhs.id == rhs.id }
    }

    init() {
        loadSampleDocuments()
    }

    private func loadSampleDocuments() {
        documents = [
            RAGDocument(id: "doc-1", title: "Fusion Studio 使用指南", content: "Fusion Studio 是 Fusion-MLX 生态的统一桌面客户端...", source: "docs/guide.md", chunkCount: 0, indexedAt: nil, isIndexed: false),
            RAGDocument(id: "doc-2", title: "API 文档", content: "Fusion Studio 使用 JSON-RPC 2.0 协议...", source: "docs/api.md", chunkCount: 0, indexedAt: nil, isIndexed: false),
            RAGDocument(id: "doc-3", title: "架构设计文档", content: "Fusion Studio 采用五层架构...", source: "ARCHITECTURE.md", chunkCount: 0, indexedAt: nil, isIndexed: false),
            RAGDocument(id: "doc-4", title: "MLX 模型推理指南", content: "fusion-mlx 是 Apple Silicon 上的推理引擎...", source: "fusion-mlx/docs", chunkCount: 0, indexedAt: nil, isIndexed: false),
        ]
    }

    // MARK: - 索引

    func indexDocument(_ id: String) {
        guard let doc = documents.first(where: { $0.id == id }), !doc.isIndexed else { return }
        isIndexing = true

        // 调用 fusion-mlx 嵌入 API 进行文档索引
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let url = URL(string: "http://localhost:8000/v1/embeddings")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["input": doc.content, "model": "default"]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 60
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    let newChunks = self.chunkDocument(doc)
                    await MainActor.run {
                        self.chunks.append(contentsOf: newChunks)
                        if let idx = self.documents.firstIndex(where: { $0.id == id }) {
                            self.documents[idx].chunkCount = newChunks.count
                            self.documents[idx].indexedAt = Date()
                            self.documents[idx].isIndexed = true
                        }
                        self.isIndexing = false
                        self.objectWillChange.send()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isIndexing = false
                    self.objectWillChange.send()
                }
            }
        }
    }

    func indexAll() {
        for doc in documents where !doc.isIndexed {
            indexDocument(doc.id)
        }
    }

    private func chunkDocument(_ doc: RAGDocument) -> [DocumentChunk] {
        let text = doc.content
        let chunkSize = config.chunkSize
        let overlap = config.chunkOverlap
        var chunks: [DocumentChunk] = []
        var start = 0

        while start < text.count {
            let end = min(start + chunkSize, text.count)
            let content = String(text[text.index(text.startIndex, offsetBy: start)..<text.index(text.startIndex, offsetBy: end)])
            chunks.append(DocumentChunk(
                id: "chunk-\(doc.id)-\(chunks.count)",
                documentId: doc.id,
                content: content,
                embedding: nil,
                metadata: ["source": doc.source, "title": doc.title],
                chunkIndex: chunks.count
            ))
            if end >= text.count { break }
            start = end - overlap
        }
        return chunks
    }

    // MARK: - 检索

    func query(_ queryText: String, bridge: AgentBridge? = nil) async -> [RetrievalResult] {
        let start = CFAbsoluteTimeGetCurrent()

        var results: [RetrievalResult] = []
        if let bridge = bridge {
            do {
                let ragResult = try await bridge.ragQuery(query: queryText)
                for (i, source) in ragResult.sources.enumerated() {
                    let chunk = DocumentChunk(
                        id: "chunk-rag-\(i)",
                        documentId: "rag-result",
                        content: source,
                        embedding: nil,
                        metadata: ["answer": ragResult.answer],
                        chunkIndex: i
                    )
                    results.append(RetrievalResult(id: "result-\(i)", chunk: chunk, score: 0.9 - Double(i) * 0.1, rank: i + 1))
                }
            } catch {
                let chunk = DocumentChunk(id: "chunk-err", documentId: "error", content: error.localizedDescription, embedding: nil, metadata: [:], chunkIndex: 0)
                results = [RetrievalResult(id: "result-err", chunk: chunk, score: 0.0, rank: 1)]
            }
        } else {
            let filtered = chunks.filter { $0.content.localizedCaseInsensitiveContains(queryText) }
            let topResults = Array(filtered.prefix(config.topK))
            results = topResults.enumerated().map { i, chunk in
                RetrievalResult(id: "result-\(i)", chunk: chunk, score: Double.random(in: 0.5...0.95), rank: i + 1)
            }.sorted { $0.score > $1.score }
        }

        let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000

        await MainActor.run {
            lastQueryResults = results
            let queryRecord = RAGQuery(
                id: "q-\(UUID().uuidString.prefix(6))",
                query: queryText,
                strategy: config.retrievalStrategy,
                results: results,
                timestamp: Date(),
                latencyMs: latency
            )
            queryHistory.append(queryRecord)
            if queryHistory.count > 50 { queryHistory.removeFirst(queryHistory.count - 50) }
            objectWillChange.send()
        }
        return results
    }

    func clearDocuments() {
        documents.removeAll()
        chunks.removeAll()
        lastQueryResults.removeAll()
        objectWillChange.send()
    }
}

// MARK: - RAG 面板

struct RAGPipelineView: View {
    @StateObject private var engine = RAGEngine.shared
    @State private var selectedTab: RAGTab = .documents
    @State private var queryInput = ""
    @State private var isSearching = false

    enum RAGTab: String, CaseIterable {
        case documents = "文档"
        case query     = "检索"
        case config    = "配置"
        case history   = "历史"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(RAGTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .documents: DocumentListView()
            case .query:     QueryView()
            case .config:    RAGConfigView()
            case .history:   QueryHistoryView()
            }
        }
    }

    private func tabIcon(_ tab: RAGTab) -> String {
        switch tab {
        case .documents: return "doc.text"
        case .query:     return "magnifyingglass"
        case .config:    return "gearshape"
        case .history:   return "clock.arrow.circlepath"
        }
    }
}

// MARK: - 文档列表

struct DocumentListView: View {
    @StateObject private var engine = RAGEngine.shared
    @State private var selectedDoc: RAGEngine.RAGDocument?

    var body: some View {
        HSplitView {
            List(selection: $selectedDoc) {
                ForEach(engine.documents) { doc in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.title).font(.headline)
                            Text(doc.source).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if doc.isIndexed {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(doc)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250)

            if let doc = selectedDoc {
                VStack(alignment: .leading, spacing: 12) {
                    Text(doc.title).font(.title2).bold()
                    Text("来源: \(doc.source)").font(.subheadline).foregroundColor(.secondary)
                    Text(doc.content).font(.body).padding(.top, 4)
                    Spacer()
                    HStack {
                        if doc.isIndexed {
                            Label("\(doc.chunkCount) 个块", systemImage: "square.grid.3x3")
                            Spacer()
                            Label("索引于 \(doc.indexedAt?.formatted(date: .numeric, time: .shortened) ?? "")", systemImage: "clock")
                        } else {
                            Button("索引此文档") { engine.indexDocument(doc.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(.secondary)
                    Text("选择文档查看详情").foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("索引全部") { engine.indexAll() }
                    .buttonStyle(.bordered).controlSize(.small).disabled(engine.isIndexing)
                if engine.isIndexing { ProgressView().controlSize(.small) }
            }
        }
    }
}

// MARK: - 检索视图

struct QueryView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var engine = RAGEngine.shared
    @State private var queryInput = ""
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("输入检索查询...", text: $queryInput)
                    .textFieldStyle(.plain)
                    .onSubmit { search() }
                    .disabled(isSearching)
                if isSearching { ProgressView().controlSize(.small) }
                Button(action: search) { Image(systemName: "play.fill") }
                    .buttonStyle(.borderedProminent).controlSize(.small).disabled(queryInput.isEmpty || isSearching)
                Button("清空") { engine.lastQueryResults.removeAll() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(8)
            .background(theme.surfaceSecondary)

            Divider()

            // 结果
            if engine.lastQueryResults.isEmpty && !isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("输入查询开始检索").foregroundColor(.secondary)
                    Text("当前使用 \(engine.config.retrievalStrategy.rawValue) 策略").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else if isSearching {
                ProgressView("检索中...").padding()
                Spacer()
            } else {
                List {
                    Text("找到 \(engine.lastQueryResults.count) 个结果")
                        .font(.headline).foregroundColor(.secondary)
                    ForEach(engine.lastQueryResults) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(result.rank)").font(.caption).foregroundColor(.secondary)
                                Text("\(result.score, specifier: "%.1f")%")
                                    .font(.caption).foregroundColor(.blue)
                                Spacer()
                                Text(engine.documents.first(where: { $0.id == result.chunk.documentId })?.title ?? "")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Text(result.chunk.content)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(4)
                            if !result.chunk.metadata.isEmpty {
                                HStack {
                                    ForEach(Array(result.chunk.metadata.keys), id: \.self) { key in
                                        Text("\(key): \(result.chunk.metadata[key] ?? "")")
                                            .font(.system(size: 8)).padding(.horizontal, 4)
                                            .background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func search() {
        guard !queryInput.isEmpty else { return }
        isSearching = true
        Task {
            _ = await engine.query(queryInput, bridge: bridgeIfConnected)
            await MainActor.run { isSearching = false }
        }
    }

    private var bridgeIfConnected: AgentBridge? {
        (NSApp.delegate as? AppDelegate)?.agentBridge
    }
}

// MARK: - 配置

struct RAGConfigView: View {
    @StateObject private var engine = RAGEngine.shared

    var body: some View {
        Form {
            Section("分块策略") {
                Picker("分块方式", selection: $engine.config.strategy) {
                    ForEach(ChunkStrategy.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s == .fixed ? "square.split.2x2" : "doc.text").tag(s)
                    }
                }
                HStack {
                    Text("块大小: \(engine.config.chunkSize) tokens")
                    Slider(value: Binding(get: { Double(engine.config.chunkSize) }, set: { engine.config.chunkSize = Int($0) }), in: 128...2048, step: 64)
                }
                HStack {
                    Text("重叠: \(engine.config.chunkOverlap) tokens")
                    Slider(value: Binding(get: { Double(engine.config.chunkOverlap) }, set: { engine.config.chunkOverlap = Int($0) }), in: 0...256, step: 16)
                }
            }

            Section("检索策略") {
                Picker("检索方式", selection: $engine.config.retrievalStrategy) {
                    ForEach(RetrievalStrategy.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                HStack {
                    Text("Top-K: \(engine.config.topK)")
                    Slider(value: Binding(get: { Double(engine.config.topK) }, set: { engine.config.topK = Int($0) }), in: 1...20)
                }
                HStack {
                    Text("最低分数: \(engine.config.minScore, specifier: "%.2f")")
                    Slider(value: $engine.config.minScore, in: 0...1, step: 0.05)
                }
                Toggle("启用重排序", isOn: $engine.config.enableRerank)
                HStack {
                    Text("最大上下文: \(engine.config.maxContextLength)")
                    Slider(value: Binding(get: { Double(engine.config.maxContextLength) }, set: { engine.config.maxContextLength = Int($0) }), in: 1024...8192, step: 512)
                }
            }

            Section("统计") {
                HStack { Text("文档数"); Spacer(); Text("\(engine.documents.count)").font(.system(.body, design: .monospaced)) }
                HStack { Text("文档块数"); Spacer(); Text("\(engine.chunks.count)").font(.system(.body, design: .monospaced)) }
                HStack { Text("查询次数"); Spacer(); Text("\(engine.queryHistory.count)").font(.system(.body, design: .monospaced)) }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 查询历史

struct QueryHistoryView: View {
    @StateObject private var engine = RAGEngine.shared

    var body: some View {
        if engine.queryHistory.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundColor(.secondary)
                Text("暂无查询记录").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(engine.queryHistory.reversed()) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.query).font(.headline)
                            Spacer()
                            Text("\(record.latencyMs, specifier: "%.0f")ms").font(.caption).foregroundColor(.secondary)
                        }
                        HStack {
                            Text(record.strategy.rawValue).font(.caption2).padding(.horizontal, 4)
                                .background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                            Text("\(record.results.count) 个结果").font(.caption2).foregroundColor(.secondary)
                            Text(record.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
                        }
                        if !record.results.isEmpty {
                            Text("最佳: \(record.results.first?.chunk.content.prefix(80) ?? "")...")
                                .font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}