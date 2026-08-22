// Callers: RAGPipelineView (search debug tab). API: RAGAPIClient.search(). schema: KBSearchResult. user instruction: "完成所有待办任务"

import SwiftUI
import os

struct SearchDebugView: View {
    @StateObject private var client = RAGAPIClient.shared
    @State private var selectedKBId: String = ""
    @State private var query = ""
    @State private var results: [KBSearchResult] = []
    @State private var isSearching = false
    @State private var topK = 5
    @State private var threshold = 0.3
    @State private var rewriteMode: String? = nil
    @State private var searchTimeMs: Double = 0

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SearchDebugView")

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack {
                Picker(I18nManager.shared.t(.kbc_label_kb), selection: $selectedKBId) {
                    Text(I18nManager.shared.t(.kbc_ph_select_kb)).tag("")
                    ForEach(client.knowledgeBases) { kb in
                        Text(kb.name).tag(kb.id)
                    }
                }
                .frame(maxWidth: 180)

                TextField(I18nManager.shared.t(.kbc_ph_search_query), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { doSearch() }

                Stepper("Top \(topK)", value: $topK, in: 1...50)
                    .frame(maxWidth: 100)

                Button(I18nManager.shared.t(.kbc_btn_search)) { doSearch() }
                    .disabled(isSearching || query.isEmpty || selectedKBId.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)

            HStack {
                Picker(I18nManager.shared.t(.kbc_label_rewrite), selection: $rewriteMode) {
                    Text(I18nManager.shared.t(.kbc_rewrite_off)).tag(String?.none)
                    Text("HyDE").tag(String?.some("hyde"))
                    Text(I18nManager.shared.t(.kbc_rewrite_expand)).tag(String?.some("expand"))
                    Text(I18nManager.shared.t(.kbc_rewrite_condense)).tag(String?.some("condense"))
                }
                .frame(maxWidth: 120)
                Slider(value: $threshold, in: 0...1, step: 0.05) {
                    Text(String(format: I18nManager.shared.t(.kbc_label_threshold), threshold))
                }
                .frame(maxWidth: 200)
                if searchTimeMs > 0 {
                    Text(String(format: I18nManager.shared.t(.kbc_label_elapsed), searchTimeMs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Results
            if isSearching {
                Spacer()
                ProgressView(I18nManager.shared.t(.kbc_searching))
                Spacer()
            } else if results.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(query.isEmpty ? I18nManager.shared.t(.kbc_msg_input_to_search) : I18nManager.shared.t(.kbc_msg_no_results))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { result in
                            SearchResultRow(result: result)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .task {
            await client.listBases()
        }
    }

    private func doSearch() {
        guard !query.isEmpty, !selectedKBId.isEmpty else { return }
        isSearching = true
        let start = Date()
        Task {
            let found = await client.search(
                kbId: selectedKBId,
                query: query,
                topK: topK,
                threshold: threshold,
                rewriteMode: rewriteMode
            )
            let elapsed = Date().timeIntervalSince(start) * 1000
            await MainActor.run {
                results = found
                searchTimeMs = elapsed
                isSearching = false
            }
        }
    }
}

struct SearchResultRow: View {
    let result: KBSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Score badge
                Text(String(format: "%.3f", result.score))
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(scoreColor(result.score))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                Text(result.docName)
                    .font(.caption)
                    .fontWeight(.medium)

                if let idx = result.chunkIndex {
                    Text("#\(idx)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let dtype = result.docType {
                    Text(dtype)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Context (if available from Contextualizer)
            if let ctx = result.context, !ctx.isEmpty {
                Text(ctx)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            }

            // Main text
            Text(result.text)
                .font(.caption)
                .lineLimit(4)

            if !result.docPath.isEmpty {
                Text(result.docPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .orange }
        return .red
    }
}
