import SwiftUI
import Combine
import os.log

// MARK: - RagTabView

struct RagTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var query = ""
    @State private var limit: Double = 10
    @State private var threshold: Double = 0.5
    @State private var mode = "query"
    @State private var answer = ""
    @State private var sources: [String] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RAG Retrieval")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(theme.spacingM)

            VStack(spacing: theme.spacingS) {
                Picker("Mode", selection: $mode) {
                    Text("Query (answer)").tag("query")
                    Text("Retrieve (docs)").tag("retrieve")
                    Text("Vector Search").tag("vector")
                }
                .pickerStyle(.segmented)
                HStack(spacing: theme.spacingS) {
                    TextField("Query...", text: $query, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    FusionButton("Run", icon: "magnifyingglass", isDisabled: query.isEmpty || isLoading) {
                        Task { await runRag() }
                    }
                }
                if mode == "vector" {
                    HStack {
                        Text("Limit: \(Int(limit))")
                            .font(.system(size: theme.captionSize))
                        Slider(value: $limit, in: 1...50, step: 1)
                        Text("Threshold: \(String(format: "%.2f", threshold))")
                            .font(.system(size: theme.captionSize))
                        Slider(value: $threshold, in: 0...1, step: 0.05)
                    }
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView().padding(theme.spacingM)
            }
            if !answer.isEmpty {
                StudioSectionHeader(title: "Answer")
                ScrollView {
                    Text(answer)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingL)
                }
            }
            if !sources.isEmpty {
                StudioSectionHeader(title: "Sources")
                ListGroup {
                    ForEach(Array(sources.enumerated()), id: \.offset) { idx, src in
                        StudioRow(label: src, sublabel: nil, isLast: idx == sources.count - 1) {
                            FusionTag("\(idx + 1)", color: .blue)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    private func runRag() async {
        guard !query.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case "retrieve":
                let docs = try await bridge.ragRetrieve(query: query)
                sources = docs
                answer = ""
                toastManager.show(style: .success, title: "Retrieve", message: "\(docs.count) documents")
            case "vector":
                let docs = try await bridge.ragVectorSearch(query: query, limit: Int(limit), threshold: threshold)
                sources = docs
                answer = ""
                toastManager.show(style: .success, title: "Vector Search", message: "\(docs.count) results")
            default:
                let result = try await bridge.ragQuery(query: query)
                answer = result.answer
                sources = result.sources
                toastManager.show(style: .success, title: "Query", message: "\(result.sources.count) sources")
            }
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}
