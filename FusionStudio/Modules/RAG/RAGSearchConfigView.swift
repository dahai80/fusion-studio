import SwiftUI
import os

private let searchLog = Logger(subsystem: "com.fusion.studio", category: "RAGSearchConfig")

struct RAGSearchConfigView: View {
    let selectedKBId: String
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @StateObject private var i18n = I18nManager.shared
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
        case general
        case code
        case design
        var localLabel: String {
            switch self {
            case .general: return I18nManager.shared.t(.rag_srch_preset_general)
            case .code: return I18nManager.shared.t(.rag_srch_preset_code)
            case .design: return I18nManager.shared.t(.rag_srch_preset_design)
            }
        }
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
                Text(i18n.t(.rag_srch_title))
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
            Label(i18n.t(.rag_srch_presetLabel), systemImage: "slider.horizontal.3")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                ForEach(SearchPreset.allCases, id: \.self) { preset in
                    Button(action: { applyPreset(preset) }) {
                        VStack(spacing: theme.spacingXS) {
                            Image(systemName: preset.icon)
                                .font(.system(size: theme.iconL))
                                .foregroundStyle(activePreset == preset ? theme.accent : theme.textTertiary)
                            Text(preset.localLabel)
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
            tipBanner(i18n.t(.rag_srch_presetDesc_general), color: .blue)
        case .code:
            tipBanner(i18n.t(.rag_srch_presetDesc_code), color: .purple)
        case .design:
            tipBanner(i18n.t(.rag_srch_presetDesc_design), color: .orange)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_srch_weightLabel), systemImage: "balance.scale")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Toggle(i18n.t(.rag_srch_hybridToggle), isOn: $hybridEnabled)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if hybridEnabled {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(i18n.t(.rag_srch_sparseLabel)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text("\(Int(sparseWeight * 100))%")
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(.orange)
                    }
                    Slider(value: $sparseWeight, in: 0...1, step: 0.05).tint(.orange)
                }
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(i18n.t(.rag_srch_denseLabel)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text("\(Int(denseWeight * 100))%")
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(.blue)
                    }
                    Slider(value: $denseWeight, in: 0...1, step: 0.05).tint(.blue)
                }
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(i18n.t(.rag_srch_alphaLabel)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text(String(format: "%.2f", hybridAlpha))
                            .font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.accent)
                    }
                    Slider(value: $hybridAlpha, in: 0...1, step: 0.05).tint(theme.accent)
                }
                weightBalanceBar
            }
            Toggle(i18n.t(.rag_srch_rerankToggle), isOn: $rerankEnabled)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if rerankEnabled {
                tipBanner(i18n.t(.rag_srch_rerankTip), color: .green)
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
            Label(i18n.t(.rag_srch_paramsLabel), systemImage: "gearshape")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXL) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_srch_topKLabel)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                    Stepper("Top-\(Int(topK))", value: $topK, in: 1...50, step: 1)
                        .font(.system(size: theme.textSize))
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_srch_thresholdLabel)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
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
            Label(i18n.t(.rag_srch_rewriteCard), systemImage: "text.append")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Picker(i18n.t(.rag_srch_rewriteModePicker), selection: $rewriteMode) {
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
        case "none": tipBanner(i18n.t(.rag_srch_rewriteDesc_none), color: .gray)
        case "expand": tipBanner(i18n.t(.rag_srch_rewriteDesc_expand), color: .blue)
        case "decompose": tipBanner(i18n.t(.rag_srch_rewriteDesc_decompose), color: .purple)
        case "hyde": tipBanner(i18n.t(.rag_srch_rewriteDesc_hyde), color: .green)
        default: EmptyView()
        }
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_srch_testLabel), systemImage: "flask")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.rag_srch_testQueryPh), text: $testQuery).textFieldStyle(.roundedBorder)
                Button(action: { Task { await runTest() } }) {
                    HStack(spacing: theme.spacingXS) {
                        if isSearching { ProgressView().controlSize(.small) }
                        Text(i18n.t(.rag_srch_testBtn))
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
        case "none": return i18n.t(.rag_srch_rw_none); case "expand": return i18n.t(.rag_srch_rw_expand)
        case "decompose": return i18n.t(.rag_srch_rw_decompose); case "hyde": return i18n.t(.rag_srch_rw_hyde)
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
