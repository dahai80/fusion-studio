import SwiftUI
import os

private let searchLog = Logger(subsystem: "com.fusion.studio", category: "RAGSearchConfig")

struct RAGSearchConfigView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @State private var hybridAlpha: Double = 0.7
    @State private var sparseWeight: Double = 0.3
    @State private var denseWeight: Double = 0.7
    @State private var rerankEnabled: Bool = true
    @State private var hybridEnabled: Bool = true
    @State private var topK: Double = 5
    @State private var threshold: Double = 0.3
    @State private var rewriteMode: String = "none"
    @State private var activePreset: SearchPreset = .general
    @State private var testQuery: String = ""
    @State private var testResults: [KBSearchResult] = []
    @State private var isSearching = false

    enum SearchPreset: String, CaseIterable {
        case general = "通用"
        case code = "代码"
        case design = "设计"
        var icon: String {
            switch self {
            case .general: return "doc.text.magnifyingglass"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .design: return "paintbrush"
            }
        }
        var config: (alpha: Double, sparse: Double, dense: Double, rerank: Bool, hybrid: Bool, topK: Double, threshold: Double, rewrite: String) {
            switch self {
            case .general: return (0.7, 0.3, 0.7, true, true, 5, 0.3, "none")
            case .code: return (0.5, 0.5, 0.5, true, true, 8, 0.2, "decompose")
            case .design: return (0.8, 0.2, 0.8, true, true, 5, 0.4, "expand")
            }
        }
    }

    let rewriteModes = ["none", "expand", "decompose", "hyde"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text("检索策略配置")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                presetCard
                weightCard
                paramsCard
                rewriteCard
                testCard
            }
            .padding(theme.spacingL)
        }
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("场景预设", systemImage: "slider.horizontal.3")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                ForEach(SearchPreset.allCases, id: \.self) { preset in
                    Button(action: { applyPreset(preset) }) {
                        VStack(spacing: theme.spacingXS) {
                            Image(systemName: preset.icon)
                                .font(.system(size: theme.iconL))
                                .foregroundStyle(activePreset == preset ? theme.accent : theme.textTertiary)
                            Text(preset.rawValue)
                                .font(.system(size: theme.textSize, weight: activePreset == preset ? .semibold : .regular))
                                .foregroundStyle(activePreset == preset ? theme.accent : theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingM)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .fill(activePreset == preset ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .stroke(activePreset == preset ? theme.accent : theme.separator, lineWidth: activePreset == preset ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            presetDescription
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    @ViewBuilder
    private var presetDescription: some View {
        switch activePreset {
        case .general:
            tipBanner("通用场景：均衡稀疏+稠密检索，适合文档问答", color: .blue)
        case .code:
            tipBanner("代码场景：提升稀疏权重（BM25 精确匹配函数名），开启查询分解", color: .purple)
        case .design:
            tipBanner("设计场景：提升稠密权重（语义理解设计描述），开启查询扩展", color: .orange)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("检索权重", systemImage: "balance.scale")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Toggle("混合检索（BM25 + 向量 RRF）", isOn: $hybridEnabled)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if hybridEnabled {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text("稀疏检索（BM25）").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text("\(Int(sparseWeight * 100))%")
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(.orange)
                    }
                    Slider(value: $sparseWeight, in: 0...1, step: 0.05).tint(.orange)
                }
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text("稠密检索（向量）").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text("\(Int(denseWeight * 100))%")
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(.blue)
                    }
                    Slider(value: $denseWeight, in: 0...1, step: 0.05).tint(.blue)
                }
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text("混合 Alpha（RRF 权重）").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text(String(format: "%.2f", hybridAlpha))
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.accent)
                    }
                    Slider(value: $hybridAlpha, in: 0...1, step: 0.05).tint(theme.accent)
                }
                weightBalanceBar
            }
            Toggle("重排序（Rerank）", isOn: $rerankEnabled)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if rerankEnabled {
                tipBanner("重排序使用 BGE-Reranker 对初步结果二次打分，显著提升 Top-5 准确率", color: .green)
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private var weightBalanceBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.orange.opacity(0.6)).frame(width: geo.size.width * sparseWeight)
                    Rectangle().fill(Color.blue.opacity(0.6)).frame(width: geo.size.width * denseWeight)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            HStack {
                Text("BM25").font(.system(size: 8)).foregroundStyle(.orange)
                Spacer()
                Text("Vector").font(.system(size: 8)).foregroundStyle(.blue)
            }
        }
    }

    private var paramsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("检索参数", systemImage: "gearshape")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXL) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Top-K 返回数").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                    Stepper("Top-\(Int(topK))", value: $topK, in: 1...50, step: 1)
                        .font(.system(size: theme.textSize))
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("相似度阈值").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                    HStack {
                        Slider(value: $threshold, in: 0...1, step: 0.05).tint(theme.accent)
                        Text(String(format: "%.2f", threshold))
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.accent).frame(width: 40)
                    }
                }
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private var rewriteCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("查询改写", systemImage: "text.append")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Picker("改写模式", selection: $rewriteMode) {
                ForEach(rewriteModes, id: \.self) { m in Text(rewriteLabel(m)).tag(m) }
            }
            .pickerStyle(.segmented)
            rewriteDescription
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    @ViewBuilder
    private var rewriteDescription: some View {
        switch rewriteMode {
        case "none": tipBanner("不进行查询改写，直接使用原始查询", color: .gray)
        case "expand": tipBanner("查询扩展：生成同义表述增加召回率", color: .blue)
        case "decompose": tipBanner("查询分解：将复杂查询拆解为子问题分别检索", color: .purple)
        case "hyde": tipBanner("HyDE：先用 LLM 生成假设性答案，再用假设答案检索", color: .green)
        default: EmptyView()
        }
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("检索测试", systemImage: "flask")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingS) {
                TextField("输入测试查询...", text: $testQuery).textFieldStyle(.roundedBorder)
                Button(action: { Task { await runTest() } }) {
                    HStack(spacing: theme.spacingXS) {
                        if isSearching { ProgressView().controlSize(.small) }
                        Text("测试")
                    }
                }
                .disabled(testQuery.isEmpty || selectedKBId.isEmpty || isSearching)
                .buttonStyle(.borderedProminent)
            }
            if !testResults.isEmpty {
                ForEach(testResults) { r in testResultRow(r) }
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private func testResultRow(_ r: KBSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: "%.3f", r.score))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(r.score > 0.7 ? .green : r.score > 0.4 ? .orange : .red)
                Text(r.docName).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                Spacer()
            }
            Text(r.text.prefix(120))
                .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary).lineLimit(2)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
    }

    private func tipBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "info.circle").foregroundStyle(color)
            Text(text).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(color.opacity(0.06)))
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary)
    }
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1)
    }

    private func applyPreset(_ preset: SearchPreset) {
        activePreset = preset
        let c = preset.config
        hybridAlpha = c.alpha; sparseWeight = c.sparse; denseWeight = c.dense
        rerankEnabled = c.rerank; hybridEnabled = c.hybrid; topK = c.topK
        threshold = c.threshold; rewriteMode = c.rewrite
        searchLog.info("Applied preset: \(preset.rawValue)")
    }

    private func rewriteLabel(_ m: String) -> String {
        switch m {
        case "none": return "无"; case "expand": return "扩展"
        case "decompose": return "分解"; case "hyde": return "HyDE"
        default: return m
        }
    }

    private func runTest() async {
        guard !selectedKBId.isEmpty else { return }
        isSearching = true
        testResults = await client.search(
            kbId: selectedKBId, query: testQuery, topK: Int(topK), threshold: threshold,
            rewriteMode: rewriteMode == "none" ? nil : rewriteMode,
            hybrid: hybridEnabled, rerank: rerankEnabled, hybridAlpha: hybridAlpha
        )
        isSearching = false
        searchLog.info("Test search: \(testResults.count) results for '\(testQuery)'")
    }
}
