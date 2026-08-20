import SwiftUI
import os

private let benchLog = Logger(subsystem: "com.fusion.studio", category: "RAGBenchEval")

struct RAGBenchEvalView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @ObservedObject var client: RAGAPIClient
    @StateObject private var i18n = I18nManager.shared
    @State private var isRunning = false
    @State private var benchResults: [BenchResult] = []
    @State private var selectedPreset: BenchPreset = .standard
    @State private var customQueries: [BenchQuery] = []
    @State private var showAddQuery = false
    @State private var newQueryText = ""
    @State private var newQueryExpected = ""
    @State private var previousResults: [[String: Any]] = []

    enum BenchPreset: String, CaseIterable {
        case standard
        case code
        case design
        var localLabel: String {
            switch self {
            case .standard: return I18nManager.shared.t(.rag_bench_preset_standard)
            case .code: return I18nManager.shared.t(.rag_bench_preset_code)
            case .design: return I18nManager.shared.t(.rag_bench_preset_design)
            }
        }
        var icon: String {
            switch self {
            case .standard: return "chart.bar.xaxis"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .design: return "paintbrush"
            }
        }
    }

    struct BenchResult: Identifiable {
        let id: String
        let query: String
        let expectedInTop: Bool
        let actualRank: Int
        let topScore: Double
        let latencyMs: Double
    }

    struct BenchQuery: Identifiable {
        let id: String
        let query: String
        let expectedDoc: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.rag_bench_title))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                competitiveCard
                presetCard
                customQueryCard
                runButton
                resultsCard
                historyCard
            }
            .padding(theme.spacingL)
        }
        .task { await loadHistory() }
    }

    private var competitiveCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("Fusion-RAG vs Claude RAG", systemImage: "chart.bar.doc.horizontal")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                advantageChip(i18n.t(.rag_bench_adv_local), icon: "desktopcomputer", color: .green)
                advantageChip(i18n.t(.rag_bench_adv_ast), icon: "chevron.left.forwardslash.chevron.right", color: .purple)
                advantageChip(i18n.t(.rag_bench_adv_rrf), icon: "arrow.triangle.merge", color: .blue)
                advantageChip(i18n.t(.rag_bench_adv_context), icon: "text.append", color: .orange)
                advantageChip(i18n.t(.rag_bench_adv_sync), icon: "arrow.triangle.2.circlepath", color: .cyan)
                advantageChip(i18n.t(.rag_bench_adv_snap), icon: "clock.arrow.circlepath", color: .pink)
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func advantageChip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8)).foregroundStyle(color)
            Text(text).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.08)))
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_bench_presetLabel), systemImage: "slider.horizontal.3")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                ForEach(BenchPreset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func presetButton(_ preset: BenchPreset) -> some View {
        let isActive = selectedPreset == preset
        return Button(action: { selectedPreset = preset }) {
            VStack(spacing: theme.spacingXS) {
                Image(systemName: preset.icon)
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                Text(preset.localLabel)
                    .font(.system(size: theme.textSize, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(isActive ? theme.accent : theme.separator, lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customQueryCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Label(i18n.t(.rag_bench_customQueryLabel), systemImage: "text.badge.plus")
                    .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button(action: { showAddQuery = true }) {
                    Image(systemName: "plus").font(.system(size: theme.iconS))
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            if customQueries.isEmpty {
                Text(i18n.t(.rag_bench_customEmpty))
                    .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(customQueries) { q in
                    HStack(spacing: theme.spacingS) {
                        Text(q.query).font(.system(size: theme.captionSize)).foregroundStyle(theme.text)
                        Text("→").foregroundStyle(theme.textTertiary)
                        Text(q.expectedDoc).font(.system(size: theme.captionSize)).foregroundStyle(theme.accent)
                        Spacer()
                        Button(action: { customQueries.removeAll { $0.id == q.id } }) {
                            Image(systemName: "xmark").font(.system(size: 8)).foregroundStyle(.red.opacity(0.5))
                        }.buttonStyle(.plain)
                    }
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                }
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
        .sheet(isPresented: $showAddQuery) {
            VStack(spacing: theme.spacingM) {
                Text(i18n.t(.rag_bench_addQueryTitle)).font(.headline)
                TextField(i18n.t(.rag_bench_queryPh), text: $newQueryText).textFieldStyle(.roundedBorder)
                TextField(i18n.t(.rag_bench_expectedPh), text: $newQueryExpected).textFieldStyle(.roundedBorder)
                HStack {
                    Button(i18n.t(.cancel)) { showAddQuery = false; newQueryText = ""; newQueryExpected = "" }
                    Spacer()
                    Button(i18n.t(.rag_bench_addBtn)) {
                        guard !newQueryText.isEmpty else { return }
                        customQueries.append(BenchQuery(id: UUID().uuidString, query: newQueryText, expectedDoc: newQueryExpected))
                        newQueryText = ""; newQueryExpected = ""; showAddQuery = false
                    }
                    .disabled(newQueryText.isEmpty).buttonStyle(.borderedProminent)
                }
            }
            .padding(20).frame(width: 350)
        }
    }

    private var runButton: some View {
        HStack(spacing: theme.spacingM) {
            Button(action: { Task { await runBenchmark() } }) {
                HStack(spacing: theme.spacingXS) {
                    if isRunning { ProgressView().controlSize(.small) }
                    Text(i18n.t(.rag_bench_runBtn))
                }
            }
            .disabled(isRunning || selectedKBId.isEmpty)
            .buttonStyle(.borderedProminent)
            if !benchResults.isEmpty {
                let hitRate = Double(benchResults.filter(\.expectedInTop).count) / Double(benchResults.count) * 100
                Text(String(format: i18n.t(.rag_bench_hitRateFmt), String(format: "%.1f%%", hitRate)))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(hitRate > 80 ? .green : hitRate > 50 ? .orange : .red)
            }
            Spacer()
            if !benchResults.isEmpty {
                Button(i18n.t(.rag_bench_clearResultsBtn)) { benchResults = [] }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_bench_resultsLabel), systemImage: "chart.bar.xaxis")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if benchResults.isEmpty {
                Text(i18n.t(.rag_bench_resultsEmpty)).foregroundStyle(theme.textTertiary)
            } else {
                summaryBar
                ForEach(benchResults) { r in resultRow(r) }
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private var summaryBar: some View {
        let hits = benchResults.filter(\.expectedInTop).count
        let total = benchResults.count
        let avgLatency = total > 0 ? benchResults.map(\.latencyMs).reduce(0, +) / Double(total) : 0
        return HStack(spacing: theme.spacingM) {
            miniStat(i18n.t(.rag_bench_miniHit), value: "\(hits)/\(total)", icon: "target", color: .green)
            miniStat(i18n.t(.rag_bench_miniLatency), value: String(format: "%.0fms", avgLatency), icon: "clock", color: .orange)
            miniStat(i18n.t(.rag_bench_miniTopScore), value: String(format: "%.3f", benchResults.map(\.topScore).max() ?? 0), icon: "star", color: .blue)
        }
    }

    private func miniStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: theme.iconS)).foregroundStyle(color)
            Text(value).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            Text(label).font(.system(size: 8)).foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(color.opacity(0.06)))
    }

    private func resultRow(_ r: BenchResult) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: r.expectedInTop ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(r.expectedInTop ? .green : .red)
            Text(r.query.prefix(30)).font(.system(size: theme.captionSize)).foregroundStyle(theme.text).lineLimit(1)
            Spacer()
            Text("#\(r.actualRank)").font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(r.actualRank <= 5 ? .green : .orange)
            Text(String(format: "%.3f", r.topScore)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
            Text(String(format: "%.0fms", r.latencyMs)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .fill(r.expectedInTop ? Color.green.opacity(0.04) : Color.red.opacity(0.04)))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_bench_historyLabel), systemImage: "clock.arrow.circlepath")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            if previousResults.isEmpty {
                Text(i18n.t(.rag_bench_historyEmpty)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(previousResults.prefix(5).indices, id: \.self) { i in
                    let r = previousResults[i]
                    HStack(spacing: theme.spacingS) {
                        Text(r["test_name"] as? String ?? "bench-\(i)")
                            .font(.system(size: theme.captionSize)).foregroundStyle(theme.text)
                        Spacer()
                        if let mrr = r["mrr"] as? Double {
                            Text("MRR: \(String(format: "%.3f", mrr))")
                                .font(.system(size: theme.captionSize)).foregroundStyle(.blue)
                        }
                        if let recall = r["recall_at_5"] as? Double {
                            Text("Recall@5: \(String(format: "%.1f%%", recall * 100))")
                                .font(.system(size: theme.captionSize)).foregroundStyle(.green)
                        }
                    }
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                }
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary)
    }
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1)
    }

    private func loadHistory() async {
        guard !selectedKBId.isEmpty else { return }
        previousResults = await client.listBenchResults(kbId: selectedKBId)
        benchLog.info("Loaded \(previousResults.count) bench history records")
    }

    private func runBenchmark() async {
        guard !selectedKBId.isEmpty else { return }
        isRunning = true
        benchResults = []
        let queries = customQueries.isEmpty ? defaultQueries() : customQueries
        let benchQueries = queries.map { q -> [String: Any] in
            ["query": q.query, "expected_doc": q.expectedDoc]
        }
        if let result = await client.runBench(kbId: selectedKBId, queries: benchQueries) {
            let details = result["results"] as? [[String: Any]] ?? []
            benchResults = details.compactMap { d -> BenchResult? in
                guard let q = d["query"] as? String else { return nil }
                let rank = d["rank"] as? Int ?? 99
                return BenchResult(
                    id: UUID().uuidString,
                    query: q,
                    expectedInTop: rank <= 5,
                    actualRank: rank,
                    topScore: d["top_score"] as? Double ?? d["score"] as? Double ?? 0,
                    latencyMs: d["latency_ms"] as? Double ?? 0
                )
            }
            if benchResults.isEmpty {
                benchResults = await runClientSideBenchmark(queries: queries)
            }
        } else {
            benchResults = await runClientSideBenchmark(queries: queries)
        }
        isRunning = false
        benchLog.info("Benchmark done: \(benchResults.count) queries, hits=\(benchResults.filter(\.expectedInTop).count)")
        await loadHistory()
    }

    private func runClientSideBenchmark(queries: [BenchQuery]) async -> [BenchResult] {
        var results: [BenchResult] = []
        for q in queries {
            let start = Date().timeIntervalSince1970
            let searchResults = await client.search(kbId: selectedKBId, query: q.query, topK: 5, hybrid: true, rerank: true)
            let latency = (Date().timeIntervalSince1970 - start) * 1000
            let rank = searchResults.firstIndex(where: { $0.docName.localizedCaseInsensitiveContains(q.expectedDoc) }).map { $0 + 1 } ?? 99
            let topScore = searchResults.first?.score ?? 0
            results.append(BenchResult(
                id: UUID().uuidString, query: q.query,
                expectedInTop: rank <= 5, actualRank: rank,
                topScore: topScore, latencyMs: latency
            ))
        }
        return results
    }

    private func defaultQueries() -> [BenchQuery] {
        [
            BenchQuery(id: "b1", query: "如何配置RAG检索", expectedDoc: "rag"),
            BenchQuery(id: "b2", query: "MLX部署步骤", expectedDoc: "mlx"),
            BenchQuery(id: "b3", query: "API认证方式", expectedDoc: "auth"),
            BenchQuery(id: "b4", query: "向量索引重建", expectedDoc: "index"),
            BenchQuery(id: "b5", query: "文件监控机制", expectedDoc: "watch"),
        ]
    }
}
