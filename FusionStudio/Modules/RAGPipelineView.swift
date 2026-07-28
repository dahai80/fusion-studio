// Callers: ModuleDetailView routing.
// Refactored: Query results read from bridge.ragResults directly, RAGEngine kept only for document/chunk indexing.

import SwiftUI
import Combine
import os

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

struct RetrievalResult: Identifiable, Hashable {
    let id: String
    let chunk: DocumentChunk
    let score: Double
    let rank: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RetrievalResult, rhs: RetrievalResult) -> Bool { lhs.id == rhs.id }
}

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

class RAGEngine: ObservableObject {
    static let shared = RAGEngine()

    @Published var documents: [RAGDocument] = []
    @Published var chunks: [DocumentChunk] = []
    @Published var config = RAGPipelineConfig()
    @Published var isIndexing = false
    private let logger = Logger(subsystem: "com.fusion.studio", category: "RAGEngine")

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

    init() {
    }

    // Callers: RAGPipelineView document indexing, indexAll().
    // Affected API: fusion-mlx /v1/embeddings (now available, issue #225 CLOSED).
    // Data schemas: DocumentChunk.embedding now populated with real Float vectors; localSearch/cosineSimilarity added.
    // User instruction: "现在上游的issue和pr已经修复了，没有阻塞了，继续吧" — wire real embeddings now unblocked.
    func indexDocument(_ id: String) {
        guard let doc = documents.first(where: { $0.id == id }), !doc.isIndexed else { return }
        isIndexing = true

        Task { [weak self] in
            guard let self = self else { return }
            let newChunks = self.chunkDocument(doc)
            var embeddedChunks: [DocumentChunk] = []

            for chunk in newChunks {
                let embedding = await self.fetchEmbedding(text: chunk.content)
                embeddedChunks.append(DocumentChunk(
                    id: chunk.id,
                    documentId: chunk.documentId,
                    content: chunk.content,
                    embedding: embedding,
                    metadata: chunk.metadata,
                    chunkIndex: chunk.chunkIndex
                ))
            }

            await MainActor.run {
                self.chunks.append(contentsOf: embeddedChunks)
                let chunkCount = embeddedChunks.count
                let embCount = embeddedChunks.filter { $0.embedding != nil }.count
                if let idx = self.documents.firstIndex(where: { $0.id == id }) {
                    self.documents[idx].chunkCount = chunkCount
                    self.documents[idx].indexedAt = Date()
                    self.documents[idx].isIndexed = true
                }
                self.isIndexing = false
                self.objectWillChange.send()
                self.logger.info("RAGEngine: indexed doc \(id), \(chunkCount) chunks, \(embCount) with embeddings")
            }
        }
    }

    private func fetchEmbedding(text: String) async -> [Float]? {
        do {
            let url = URL(string: "http://localhost:8000/v1/embeddings")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["input": text, "model": "default"]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 60
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                self.logger.warning("RAGEngine: embedding API non-200, falling back to nil")
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  let first = dataArray.first,
                  let embeddingArr = first["embedding"] as? [Double] else {
                self.logger.warning("RAGEngine: could not parse embedding from response")
                return nil
            }
            return embeddingArr.map { Float($0) }
        } catch {
            self.logger.warning("RAGEngine: embedding fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    func localSearch(query: String, topK: Int = 5) -> [RetrievalResult] {
        let hasEmbeddings = chunks.contains { $0.embedding != nil }
        guard hasEmbeddings else {
            logger.info("RAGEngine: localSearch skipped — no embeddings available")
            return []
        }
        guard let qVec = fetchEmbeddingSync(text: query) else {
            logger.warning("RAGEngine: localSearch — could not get query embedding")
            return []
        }

        var scored: [(chunk: DocumentChunk, score: Double)] = []
        for chunk in chunks {
            guard let emb = chunk.embedding else { continue }
            let score = cosineSimilarity(qVec, emb)
            scored.append((chunk, score))
        }
        scored.sort { $0.score > $1.score }
        let top = Array(scored.prefix(topK))
        return top.enumerated().map { (i, item) in
            RetrievalResult(id: "local-\(item.chunk.id)", chunk: item.chunk, score: item.score, rank: i + 1)
        }
    }

    private func fetchEmbeddingSync(text: String) -> [Float]? {
        let sem = DispatchSemaphore(value: 0)
        var result: [Float]?
        Task {
            result = await fetchEmbedding(text: text)
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 30)
        return result
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return Double(dot / denom)
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

    func clearDocuments() {
        documents.removeAll()
        chunks.removeAll()
        objectWillChange.send()
    }
}

struct RAGPipelineView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @StateObject private var engine = RAGEngine.shared
    @State private var selectedTab: RAGTab = .documents
    @State private var queryInput = ""
    @State private var isSearching = false

    // Callers: RAGPipelineView. Affected API: rag.vector_search. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    enum RAGTab: String, CaseIterable {
        case documents    = "文档"
        case query        = "检索"
        case vectorSearch = "向量"
        case config       = "配置"
        case history      = "历史"
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
            case .documents:    DocumentListView()
            case .query:        QueryView()
            case .vectorSearch: VectorSearchView()
            case .config:       RAGConfigView()
            case .history:      QueryHistoryView()
            }
        }
    }

    private func tabIcon(_ tab: RAGTab) -> String {
        switch tab {
        case .documents:    return "doc.text"
        case .query:        return "magnifyingglass"
        case .vectorSearch: return "arrow.triangle.2.circlepath"
        case .config:       return "gearshape"
        case .history:      return "clock.arrow.circlepath"
        }
    }
}

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

struct QueryView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var bridge: AgentBridge
    @State private var queryInput = ""
    @State private var isSearching = false
    @State private var searchMode: SearchMode = .query
    @State private var localResults: [RetrievalResult] = []
    private let logger = Logger(subsystem: "com.fusion.studio", category: "RAGQueryView")

    enum SearchMode: String, CaseIterable {
        case query = "Query"
        case retrieve = "Retrieve"
        case knowledge = "Knowledge"
    }

    private var displayResults: [RAGResultModel] {
        switch searchMode {
        case .query:
            return bridge.ragResults
        case .retrieve, .knowledge:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { m in Text(m.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("输入检索查询...", text: $queryInput)
                    .textFieldStyle(.plain)
                    .onSubmit { search() }
                    .disabled(isSearching)
                if isSearching { ProgressView().controlSize(.small) }
                Button(action: search) { Image(systemName: "play.fill") }
                    .buttonStyle(.borderedProminent).controlSize(.small).disabled(queryInput.isEmpty || isSearching)
                Button("清空") {
                    localResults.removeAll()
                    bridge.ragResults.removeAll()
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(8)
            .background(theme.surfaceSecondary)

            Divider()

            if searchMode == .query {
                if bridge.ragResults.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundColor(.secondary)
                        Text("输入查询开始检索").foregroundColor(.secondary)
                        Spacer()
                    }
                } else if isSearching {
                    ProgressView("检索中...").padding()
                    Spacer()
                } else {
                    List {
                        Text("找到 \(bridge.ragResults.count) 个结果")
                            .font(.headline).foregroundColor(.secondary)
                        ForEach(bridge.ragResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.answer)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(4)
                                if !result.sources.isEmpty {
                                    HStack {
                                        ForEach(result.sources.indices, id: \.self) { i in
                                            Text(result.sources[i])
                                                .font(.system(size: 8)).padding(.horizontal, 4)
                                                .background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                if localResults.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundColor(.secondary)
                        Text("输入查询开始检索").foregroundColor(.secondary)
                        Spacer()
                    }
                } else if isSearching {
                    ProgressView("检索中...").padding()
                    Spacer()
                } else {
                    List {
                        Text("找到 \(localResults.count) 个结果")
                            .font(.headline).foregroundColor(.secondary)
                        ForEach(localResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(result.rank)").font(.caption).foregroundColor(.secondary)
                                    Text("\(result.score, specifier: "%.1f")%")
                                        .font(.caption).foregroundColor(.blue)
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
    }

    private func search() {
        guard !queryInput.isEmpty else { return }
        isSearching = true
        Task {
            switch searchMode {
            case .query:
                do {
                    _ = try await bridge.ragQuery(query: queryInput)
                } catch {
                    logger.error("ragQuery: \(error.localizedDescription)")
                }
            case .retrieve:
                do {
                    let sources = try await bridge.ragRetrieve(query: queryInput, config: [:])
                    var results: [RetrievalResult] = []
                    for (i, source) in sources.enumerated() {
                        let chunk = DocumentChunk(
                            id: "chunk-retrieve-\(i)",
                            documentId: "retrieve",
                            content: source,
                            embedding: nil,
                            metadata: [:],
                            chunkIndex: i
                        )
                        results.append(RetrievalResult(id: "result-\(i)", chunk: chunk, score: 0.9 - Double(i) * 0.1, rank: i + 1))
                    }
                    localResults = results
                } catch {
                    logger.error("ragRetrieve: \(error.localizedDescription)")
                    let chunk = DocumentChunk(id: "chunk-err", documentId: "error", content: error.localizedDescription, embedding: nil, metadata: [:], chunkIndex: 0)
                    localResults = [RetrievalResult(id: "result-err", chunk: chunk, score: 0.0, rank: 1)]
                }
            case .knowledge:
                do {
                    let result = try await bridge.knowledgeSearch(query: queryInput)
                    let entries = result["results"] as? [[String: Any]] ?? []
                    var results: [RetrievalResult] = []
                    for (i, entry) in entries.enumerated() {
                        let content = entry["content"] as? String ?? entry["text"] as? String ?? String(describing: entry)
                        let stringMeta = entry.mapValues { String(describing: $0) }
                        let chunk = DocumentChunk(
                            id: "chunk-knowledge-\(i)",
                            documentId: "knowledge",
                            content: content,
                            embedding: nil,
                            metadata: stringMeta,
                            chunkIndex: i
                        )
                        let score = entry["score"] as? Double ?? (0.9 - Double(i) * 0.1)
                        results.append(RetrievalResult(id: "result-knowledge-\(i)", chunk: chunk, score: score, rank: i + 1))
                    }
                    localResults = results
                } catch {
                    logger.error("knowledgeSearch: \(error.localizedDescription)")
                    let chunk = DocumentChunk(id: "chunk-err", documentId: "error", content: error.localizedDescription, embedding: nil, metadata: [:], chunkIndex: 0)
                    localResults = [RetrievalResult(id: "result-err", chunk: chunk, score: 0.0, rank: 1)]
                }
            }
            isSearching = false
        }
    }
}

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
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct QueryHistoryView: View {
    @EnvironmentObject private var bridge: AgentBridge

    var body: some View {
        if bridge.ragResults.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundColor(.secondary)
                Text("暂无查询记录").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(bridge.ragResults.reversed()) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.query).font(.headline)
                        Text(result.answer)
                            .font(.caption).foregroundColor(.secondary).lineLimit(2)
                        if !result.sources.isEmpty {
                            HStack {
                                Text("\(result.sources.count) 个来源").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// Callers: RAGPipelineView vectorSearch tab. Affected API: rag.vector_search. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
struct VectorSearchView: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @State private var queryInput: String = ""
    @State private var limit: Int = 10
    @State private var threshold: Double = 0.5
    @State private var results: [[String: Any]] = []
    @State private var isSearching: Bool = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: theme.spacingM) {
            HStack(spacing: theme.spacingS) {
                TextField("向量搜索查询...", text: $queryInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }

                Button("搜索") { performSearch() }
                    .disabled(queryInput.isEmpty || isSearching)
            }
            .padding(.horizontal, theme.spacingM)

            HStack(spacing: theme.spacingL) {
                LabeledContent("数量") {
                    Stepper("\(limit)", value: $limit, in: 1...50)
                }
                LabeledContent("阈值") {
                    Slider(value: $threshold, in: 0...1, step: 0.05) {
                        Text(String(format: "%.2f", threshold))
                    }
                }
            }
            .padding(.horizontal, theme.spacingM)

            if let err = errorMsg {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            if isSearching {
                ProgressView("搜索中...")
            } else if results.isEmpty && !queryInput.isEmpty {
                Text("无结果").foregroundStyle(theme.textTertiary)
            } else {
                List(Array(results.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item["id"] as? String ?? "").font(.caption).foregroundStyle(theme.textTertiary)
                            Spacer()
                            if let score = item["score"] as? Double {
                                Text(String(format: "%.3f", score))
                                    .font(.caption).foregroundStyle(theme.accent)
                            }
                        }
                        Text(item["content"] as? String ?? "")
                            .font(.system(size: theme.textSize))
                            .lineLimit(4)
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer()
        }
    }

    private func performSearch() {
        guard !queryInput.isEmpty else { return }
        isSearching = true
        errorMsg = nil
        Task {
            do {
                let result = try await bridge.ipcClient!.ragVectorSearch(
                    query: queryInput, limit: limit, threshold: threshold
                )
                results = result["results"] as? [[String: Any]] ?? []
            } catch {
                errorMsg = error.localizedDescription
            }
            isSearching = false
        }
    }
}
