// Callers: DocView (rag tab in DocSubTab).
// Affected API: DocBridge.ragEnhancedQuery / .reindexAll / .fetchChunks / .graphSearch → REST /api/rag/*, /api/graph/search on localhost:11449.
// Data schemas: DocRAGChunk, DocGraph, RAGResponse (from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let ragLog = Logger(subsystem: "com.fusion.studio", category: "DocRAGPanel")

struct DocRAGPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @State private var ragQuery = ""
    @State private var ragAnswer = ""
    @State private var ragChunks: [DocBridge.RAGResponse.RAGChunkItem] = []
    @State private var isQuerying = false
    @State private var isReindexing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    querySection
                    if let pid = selectedPageId {
                        chunkSection(pid)
                    }
                    reindexSection
                }
                .padding(16)
            }
        }
        .background(theme.surfacePrimary)
    }

    private var header: some View {
        HStack {
            Image(systemName: "books.vertical")
                .foregroundColor(theme.accent)
            Text(i18n.t(.doc_rag_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var querySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.doc_rag_semanticQuery))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack(alignment: .bottom, spacing: 8) {
                TextField(i18n.t(.doc_rag_queryPlaceholder), text: $ragQuery, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(8)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(6)

                Button(action: performRAGQuery) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isQuerying ? .secondary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(ragQuery.isEmpty || isQuerying)
            }

            if !ragAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.doc_rag_answer))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.textSecondary)
                    Text(ragAnswer)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surfaceSecondary)
                        .cornerRadius(6)
                }
            }

            if !ragChunks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: i18n.t(.doc_rag_chunksFmt), ragChunks.count))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.textSecondary)
                    ForEach(ragChunks.indices, id: \.self) { i in
                        Text("\(i + 1). \(String(ragChunks[i].chunk_text?.prefix(200) ?? ""))")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.surfaceSecondary.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }

    private func chunkSection(_ pageId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.doc_rag_pageChunks))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            if bridge.chunks.isEmpty {
                Text(i18n.t(.doc_rag_noChunks))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(bridge.chunks) { chunk in
                    HStack(alignment: .top, spacing: 6) {
                        Text("#\(chunk.chunk_index ?? 0)")
                            .font(.caption2)
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        Text(String(chunk.chunk_text?.prefix(150) ?? ""))
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(3)
                    }
                }
            }

            Button(action: {
                bridge.fetchChunks(pageId: pageId) { _ in }
            }) {
                Label(i18n.t(.doc_rag_loadChunks), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    private var reindexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.doc_rag_indexMgmt))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                Button(action: {
                    isReindexing = true
                    bridge.reindexAll { _ in
                        DispatchQueue.main.async { self.isReindexing = false }
                    }
                }) {
                    Label(i18n.t(.doc_rag_reindexAll), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(isReindexing)

                if isReindexing {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                if let pid = selectedPageId {
                    Button(action: {
                        bridge.reindexPage(pageId: pid)
                    }) {
                        Label(i18n.t(.doc_rag_reindexPage), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }

    private func performRAGQuery() {
        let q = ragQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isQuerying = true
        ragLog.info("RAG query: \(q)")

        bridge.ragEnhancedQuery(query: q) { result in
            DispatchQueue.main.async {
                self.isQuerying = false
                switch result {
                case .success(let data):
                    self.ragAnswer = data.answer ?? ""
                    self.ragChunks = data.chunks ?? []
                case .failure(let err):
                    self.ragAnswer = String(format: self.i18n.t(.doc_rag_queryFailFmt), err.localizedDescription)
                    self.ragChunks = []
                }
            }
        }
    }
}
