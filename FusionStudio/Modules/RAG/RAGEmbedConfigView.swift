import SwiftUI
import os

private let embedLog = Logger(subsystem: "com.fusion.studio", category: "RAGEmbedConfig")

struct RAGEmbedConfigView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @StateObject private var i18n = I18nManager.shared
    @State private var chunkSize: Double = 512
    @State private var chunkOverlap: Double = 64
    @State private var chunkStrategy: String = "semantic"
    @State private var embedModel: String = "BGE-M3"
    @State private var contextualize: Bool = true
    @State private var isSaving = false
    @State private var saveMsg: String?

    let strategies = ["semantic", "fixed", "code", "sentence"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.rag_emb_title))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                embedModelCard
                chunkConfigCard
                contextRetrievalCard
                saveButton
            }
            .padding(theme.spacingL)
        }
        .task { await loadCurrentConfig() }
    }

    private var embedModelCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_emb_model), systemImage: "cpu")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_emb_modelName))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    TextField("BGE-M3", text: $embedModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_emb_runMode))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(.green)
                        Text(i18n.t(.rag_emb_localMlx))
                            .foregroundStyle(theme.text)
                    }
                    .font(.system(size: theme.textSize))
                }
            }
            HStack(spacing: theme.spacingS) {
                infoChip(i18n.t(.rag_emb_dim768), icon: "square.grid.3x3")
                infoChip("BGE-M3", icon: "memorychip")
                infoChip(i18n.t(.rag_emb_multilang), icon: "globe")
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private var chunkConfigCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_emb_chunkStrategy), systemImage: "scissors")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Picker(i18n.t(.rag_emb_strategyPicker), selection: $chunkStrategy) {
                ForEach(strategies, id: \.self) { s in
                    Text(strategyLabel(s)).tag(s)
                }
            }
            .pickerStyle(.segmented)
            strategyDescription
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text(i18n.t(.rag_emb_chunkSize)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                    Spacer()
                    Text("\(Int(chunkSize)) tokens")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                Slider(value: $chunkSize, in: 128...2048, step: 64).tint(theme.accent)
                HStack {
                    Text("128").font(.system(size: 8)).foregroundStyle(theme.textTertiary)
                    Spacer()
                    Text("2048").font(.system(size: 8)).foregroundStyle(theme.textTertiary)
                }
            }
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text(i18n.t(.rag_emb_overlap)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                    Spacer()
                    Text("\(Int(chunkOverlap)) tokens")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                Slider(value: $chunkOverlap, in: 0...512, step: 16).tint(theme.accent)
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    @ViewBuilder
    private var strategyDescription: some View {
        switch chunkStrategy {
        case "semantic":
            strategyTip(i18n.t(.rag_emb_tip_semantic), icon: "text.bubble", color: .blue)
        case "fixed":
            strategyTip(i18n.t(.rag_emb_tip_fixed), icon: "ruler", color: .orange)
        case "code":
            strategyTip(i18n.t(.rag_emb_tip_code), icon: "chevron.left.forwardslash.chevron.right", color: .purple)
        case "sentence":
            strategyTip(i18n.t(.rag_emb_tip_sentence), icon: "text.alignleft", color: .green)
        default:
            EmptyView()
        }
    }

    private var contextRetrievalCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label(i18n.t(.rag_emb_context), systemImage: "text.append")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Toggle(i18n.t(.rag_emb_contextToggle), isOn: $contextualize)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if contextualize {
                Text(i18n.t(.rag_emb_contextDesc))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .padding(theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(Color.blue.opacity(0.08))
                    )
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private var saveButton: some View {
        HStack(spacing: theme.spacingM) {
            Button(action: { Task { await saveConfig() } }) {
                HStack(spacing: theme.spacingXS) {
                    if isSaving { ProgressView().controlSize(.small) }
                    Text(i18n.t(.save))
                }
            }
            .disabled(isSaving)
            .buttonStyle(.borderedProminent)
            if let msg = saveMsg {
                Text(msg)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(msg.hasPrefix("✓") ? .green : .red)
            }
            Spacer()
            Button(i18n.t(.rag_emb_reset)) {
                chunkSize = 512; chunkOverlap = 64; chunkStrategy = "semantic"
                embedModel = "BGE-M3"; contextualize = true
            }
            .buttonStyle(.bordered)
        }
    }

    private func infoChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8))
            Text(text).font(.system(size: theme.captionSize))
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(theme.surfaceSecondary))
    }

    private func strategyTip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: icon).foregroundStyle(color)
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

    private func strategyLabel(_ s: String) -> String {
        switch s {
        case "semantic": return i18n.t(.rag_emb_strategy_semantic)
        case "fixed": return i18n.t(.rag_emb_strategy_fixed)
        case "code": return i18n.t(.rag_emb_strategy_code)
        case "sentence": return i18n.t(.rag_emb_strategy_sentence)
        default: return s
        }
    }

    private func loadCurrentConfig() async {
        if let base = client.knowledgeBases.first {
            if let cs = base.chunkStrategy { chunkStrategy = cs }
            if let em = base.embeddingModel { embedModel = em }
        }
        embedLog.info("Embed config loaded: strategy=\(chunkStrategy) model=\(embedModel)")
    }

    private func saveConfig() async {
        isSaving = true
        saveMsg = nil
        if client.knowledgeBases.isEmpty {
            let _ = await client.createBase(name: "default", chunkStrategy: chunkStrategy, embeddingModel: embedModel)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        saveMsg = i18n.t(.rag_emb_saved)
        isSaving = false
    }
}
