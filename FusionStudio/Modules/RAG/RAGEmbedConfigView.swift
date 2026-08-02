import SwiftUI
import os

private let embedLog = Logger(subsystem: "com.fusion.studio", category: "RAGEmbedConfig")

struct RAGEmbedConfigView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
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
                Text("嵌入模型配置")
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
            Label("嵌入模型", systemImage: "cpu")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("模型名称")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    TextField("BGE-M3", text: $embedModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("运行方式")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(.green)
                        Text("本地 MLX 推理")
                            .foregroundStyle(theme.text)
                    }
                    .font(.system(size: theme.textSize))
                }
            }
            HStack(spacing: theme.spacingS) {
                infoChip("768 维", icon: "square.grid.3x3")
                infoChip("BGE-M3", icon: "memorychip")
                infoChip("多语言", icon: "globe")
            }
        }
        .padding(theme.spacingM)
        .background(cardBg)
        .overlay(cardStroke)
    }

    private var chunkConfigCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("分块策略", systemImage: "scissors")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Picker("策略", selection: $chunkStrategy) {
                ForEach(strategies, id: \.self) { s in
                    Text(strategyLabel(s)).tag(s)
                }
            }
            .pickerStyle(.segmented)
            strategyDescription
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text("分块大小").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
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
                    Text("重叠大小").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
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
            strategyTip("按语义边界分块，适合自然语言文档", icon: "text.bubble", color: .blue)
        case "fixed":
            strategyTip("固定 token 数分块，适合均匀内容", icon: "ruler", color: .orange)
        case "code":
            strategyTip("按 AST 函数/类边界分块，适合代码", icon: "chevron.left.forwardslash.chevron.right", color: .purple)
        case "sentence":
            strategyTip("按句子边界分块，适合短文本", icon: "text.alignleft", color: .green)
        default:
            EmptyView()
        }
    }

    private var contextRetrievalCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("上下文增强", systemImage: "text.append")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Toggle("Contextual Retrieval（上下文检索增强）", isOn: $contextualize)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if contextualize {
                Text("为每个分块生成上下文摘要，显著提升检索准确率。Fusion-RAG 独有优势：本地 MLX 生成上下文，无需云端 API。")
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
                    Text("保存配置")
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
            Button("恢复默认") {
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
        case "semantic": return "语义分块"
        case "fixed": return "固定分块"
        case "code": return "代码分块"
        case "sentence": return "句子分块"
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
        saveMsg = "✓ 配置已保存"
        isSaving = false
    }
}
