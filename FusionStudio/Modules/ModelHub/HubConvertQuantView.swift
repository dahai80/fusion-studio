// Callers: ModelHubMainView contentArea switch on .convertQuant.
// Affected API: ModelHubAPIClient startQuantize/listQuantizePresets/listRunningQuantize/getQuantizeTask/batchQuantize/startLayeredQuantize/compareQuantize/triggerBenchmark.
// Data schemas: HubQuantizePreset, HubQuantizeTask, HubPresetListResponse, HubBenchmarkCompareResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let quantLog = Logger(subsystem: "com.fusion.studio", category: "HubConvertQuant")

struct HubConvertQuantView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var presets: [HubQuantizePreset] = []
    @State private var runningTasks: [HubQuantizeTask] = []
    @State private var selectedModelId = ""
    @State private var selectedBits = 4
    @State private var selectedFormat = "mlx"
    @State private var selectedPreset: String?
    @State private var localModels: [HubModel] = []
    @State private var isStarting = false
    @State private var lastError: String?
    @State private var successMsg: String?
    @State private var pollTimer: Timer?

    // Scene presets
    @State private var selectedScenePreset: QuantScenePreset?

    // Layered quantize
    @State private var isAssessing = false
    @State private var assessmentResult: HubBenchmarkCompareResponse?
    @State private var isLayeredStarting = false
    @State private var kvCacheOpt = false
    @State private var attentionQuant = false
    @State private var layeredErrorMsg: String?

    // Compare
    @State private var compareResult: HubBenchmarkCompareResponse?
    @State private var isComparing = false
    @State private var compareErrorMsg: String?

    // Evaluate
    @State private var isEvaluating = false
    @State private var evaluateModelId: String?
    @State private var evaluateSuccessMsg: String?
    @State private var evaluateErrorMsg: String?

    private let bitOptions = [2, 3, 4, 8]
    private let formatOptions = ["mlx", "gguf", "safetensors"]

    var body: some View {
        HStack(spacing: 0) {
            configPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            taskPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadPresets()
            await loadModels()
            await loadRunningTasks()
            startPolling()
        }
        .onDisappear { stopPolling() }
    }

    private var configPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.hub_convertQuantize))
                    .font(.system(size: theme.largeTitleSize, weight: .bold))
                    .foregroundStyle(theme.text)

                GroupBox(i18n.t(.hub_selectModel)) {
                    Picker(i18n.t(.hub_model), selection: $selectedModelId) {
                        Text(i18n.t(.hub_selectModelPlaceholder)).tag("")
                        ForEach(localModels) { m in
                            Text(m.displayTitle).tag(m.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                scenePresetSection

                GroupBox(i18n.t(.hub_quantConfig)) {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        HStack {
                            Text(i18n.t(.hub_targetFormat)).frame(width: 80, alignment: .leading)
                            Picker("", selection: $selectedFormat) {
                                ForEach(formatOptions, id: \.self) { f in Text(f.uppercased()).tag(f) }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack {
                            Text(i18n.t(.hub_quantBits)).frame(width: 80, alignment: .leading)
                            Picker("", selection: $selectedBits) {
                                ForEach(bitOptions, id: \.self) { b in Text("\(b)-bit").tag(b) }
                            }
                            .pickerStyle(.segmented)
                        }

                        if !presets.isEmpty {
                            HStack {
                                Text(i18n.t(.hub_presetScheme)).frame(width: 80, alignment: .leading)
                                Picker("", selection: $selectedPreset) {
                                    Text(i18n.t(.hub_custom)).tag(nil as String?)
                                    ForEach(presets) { p in
                                        Text(p.name ?? p.id).tag(p.id as String?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        if let preset = presets.first(where: { $0.id == selectedPreset }) {
                            HStack {
                                Text(i18n.t(.hub_estimatedReduction)).frame(width: 80, alignment: .leading)
                                if let red = preset.estimatedSizeReduction {
                                    Text(String(format: "%.0f%%", red * 100)).foregroundStyle(.green)
                                }
                            }
                            if let desc = preset.description {
                                Text(desc).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                layeredQuantizeSection

                HStack(spacing: theme.spacingM) {
                    Button(action: startQuantize) {
                        HStack {
                            if isStarting { ProgressView().controlSize(.small) }
                            Text(i18n.t(.hub_startQuantize))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModelId.isEmpty || isStarting)

                    Button(action: triggerEvaluate) {
                        HStack {
                            if isEvaluating { ProgressView().controlSize(.small) }
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text(i18n.t(.hub_benchModel))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedModelId.isEmpty || isEvaluating)
                }

                if let err = lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if let msg = successMsg {
                    Text(msg).font(.caption).foregroundStyle(.green)
                }
                if let err = layeredErrorMsg {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if let err = evaluateErrorMsg {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if let msg = evaluateSuccessMsg {
                    Text(msg).font(.caption).foregroundStyle(.green)
                }

                compareSection
            }
            .padding(theme.spacingL)
        }
        .frame(minWidth: 360, maxWidth: 500)
    }

    // MARK: - Scene Presets

    private var scenePresetSection: some View {
        GroupBox(i18n.t(.hub_scenePreset)) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_quickPresetHint))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: theme.spacingS),
                    GridItem(.flexible(), spacing: theme.spacingS)
                ], spacing: theme.spacingS) {
                    ForEach(QuantScenePreset.allCases) { preset in
                        scenePresetButton(preset)
                    }
                }

                if let sp = selectedScenePreset {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sp.description)
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                            Text(String(format: i18n.t(.hub_formatBitsMem), sp.format.uppercased(), sp.bits, sp.memoryLabel))
                                .font(.caption2)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(theme.spacingS)
                    .background(theme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
            .padding(8)
        }
    }

    private func scenePresetButton(_ preset: QuantScenePreset) -> some View {
        Button(action: { applyScenePreset(preset) }) {
            VStack(spacing: theme.spacingXS) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedScenePreset == preset ? theme.accentText : theme.accent)
                Text(preset.label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(selectedScenePreset == preset ? theme.accentText : theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingS)
            .background(selectedScenePreset == preset ? theme.accent : theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }

    private func applyScenePreset(_ preset: QuantScenePreset) {
        selectedScenePreset = preset
        selectedFormat = preset.format
        selectedBits = preset.bits
        kvCacheOpt = preset.kvCacheOpt
        attentionQuant = preset.attentionQuant
        quantLog.info("Scene preset applied: \(preset.label) format=\(preset.format) bits=\(preset.bits)")
    }

    // MARK: - Layered Quantize

    private var layeredQuantizeSection: some View {
        GroupBox(i18n.t(.hub_layeredQuantize)) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_layeredQuantHint))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                Toggle(isOn: $kvCacheOpt) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "memorychip")
                            .foregroundStyle(theme.accent)
                        Text(i18n.t(.hub_kvCacheOpt))
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $attentionQuant) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "eye")
                            .foregroundStyle(theme.accent)
                        Text(i18n.t(.hub_attentionQuant))
                    }
                }
                .toggleStyle(.checkbox)

                HStack(spacing: theme.spacingM) {
                    Button(action: assessQuantize) {
                        HStack(spacing: theme.spacingXS) {
                            if isAssessing { ProgressView().controlSize(.small) }
                            Image(systemName: "waveform.path.ecg")
                            Text(i18n.t(.hub_evaluateQuant))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedModelId.isEmpty || isAssessing)

                    Button(action: startLayeredQuantize) {
                        HStack(spacing: theme.spacingXS) {
                            if isLayeredStarting { ProgressView().controlSize(.small) }
                            Image(systemName: "layer.3")
                            Text(i18n.t(.hub_startLayeredQuantize))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModelId.isEmpty || isLayeredStarting)
                }

                if let compare = assessmentResult, let first = compare.benchmarks.first {
                    assessmentResultCard(first)
                }
            }
            .padding(8)
        }
    }

    private func assessmentResultCard(_ bench: HubBenchmarkEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "chart.bar")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text(i18n.t(.hub_evalResult))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }

            HStack(spacing: theme.spacingL) {
                if let score = bench.score {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", score * 100))
                            .font(.system(size: theme.headlineSize, weight: .bold))
                            .foregroundStyle(score > 0.8 ? .green : (score > 0.6 ? .orange : .red))
                        Text(i18n.t(.hub_qualityScore))
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                if let tps = bench.tokensPerSecond {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", tps))
                            .font(.system(size: theme.headlineSize, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("tok/s")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                if let mem = bench.memoryPeak {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", mem))
                            .font(.system(size: theme.headlineSize, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(i18n.t(.hub_gbMemory))
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                if let ttft = bench.timeToFirstToken {
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", ttft))
                            .font(.system(size: theme.headlineSize, weight: .bold))
                            .foregroundStyle(.purple)
                        Text(i18n.t(.hub_firstTokenSec))
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
        }
        .padding(theme.spacingM)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Compare Section

    private var compareSection: some View {
        GroupBox(i18n.t(.hub_quantCompare)) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack(spacing: theme.spacingM) {
                    Button(action: compareQuantizeResult) {
                        HStack(spacing: theme.spacingXS) {
                            if isComparing { ProgressView().controlSize(.small) }
                            Image(systemName: "arrow.left.arrow.right")
                            Text(i18n.t(.hub_compareQuantResults))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(latestCompletedTaskId == nil || isComparing)
                }

                if let err = compareErrorMsg {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                if let compare = compareResult, compare.benchmarks.count >= 2 {
                    compareCard(compare.benchmarks)
                } else if let compare = compareResult, compare.benchmarks.count == 1 {
                    singleBenchmarkCard(compare.benchmarks[0])
                }
            }
            .padding(8)
        }
    }

    private func compareCard(_ benchmarks: [HubBenchmarkEntry]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text(i18n.t(.hub_originalVsQuant))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }

            let original = benchmarks[0]
            let quantized = benchmarks.count > 1 ? benchmarks[1] : benchmarks[0]

            HStack(spacing: theme.spacingL) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.hub_originalModel))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    benchmarkMetrics(original, color: .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingS)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                Image(systemName: "arrow.right")
                    .foregroundStyle(theme.textTertiary)

                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.hub_quantizedModel))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    benchmarkMetrics(quantized, color: .green)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingS)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }

            if let origScore = original.score, let quantScore = quantized.score {
                let diff = quantScore - origScore
                let pct = origScore > 0 ? String(format: "%+.1f%%", diff * 100) : ""
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diff >= 0 ? .green : .red)
                    Text(String(format: i18n.t(.hub_qualityChange), pct))
                        .font(.caption)
                        .foregroundStyle(diff >= 0 ? .green : .red)
                }
            }
        }
    }

    private func singleBenchmarkCard(_ bench: HubBenchmarkEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "chart.bar")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text(i18n.t(.hub_quantPostBench))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            benchmarkMetrics(bench, color: .green)
        }
        .padding(theme.spacingS)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    private func benchmarkMetrics(_ bench: HubBenchmarkEntry, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let score = bench.score {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "star").font(.caption2)
                    Text(String(format: i18n.t(.hub_qualityLabel), score * 100))
                        .font(.caption)
                }
                .foregroundStyle(score > 0.8 ? .green : (score > 0.6 ? .orange : .red))
            }
            if let tps = bench.tokensPerSecond {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent").font(.caption2)
                    Text(String(format: i18n.t(.hub_speedLabel), tps))
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }
            if let mem = bench.memoryPeak {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "memorychip").font(.caption2)
                    Text(String(format: i18n.t(.hub_memoryLabelFmt), mem))
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
            if let ttft = bench.timeToFirstToken {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "clock").font(.caption2)
                    Text(String(format: i18n.t(.hub_firstTokenFmt), ttft))
                        .font(.caption)
                }
                .foregroundStyle(.purple)
            }
            if let acc = bench.accuracy {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "checkmark.shield").font(.caption2)
                    Text(String(format: i18n.t(.hub_accuracyFmt), acc * 100))
                        .font(.caption)
                }
                .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
            }
        }
    }

    // MARK: - Task Panel

    private var taskPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t(.hub_quantizeTask))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { Task { await loadRunningTasks() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingM)

            Divider()

            if runningTasks.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "checkmark.circle").font(.system(size: 36)).foregroundStyle(.green)
                    Text(i18n.t(.hub_noRunningQuantTask))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runningTasks) { task in
                    QuantTaskRow(task: task)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed

    private var latestCompletedTaskId: String? {
        runningTasks.first(where: { $0.isComplete })?.id
    }

    // MARK: - Data Loading

    private func loadPresets() async {
        do {
            let resp = try await client.listQuantizePresets()
            presets = resp.presets
            quantLog.info("Loaded \(presets.count) presets")
        } catch {
            quantLog.warning("Load presets failed: \(error.localizedDescription)")
        }
    }

    private func loadModels() async {
        do {
            let resp = try await client.listModels()
            localModels = resp.models.filter { $0.isDownloaded == true }
            quantLog.info("Loaded \(localModels.count) local models for quantize")
        } catch {
            quantLog.warning("Load models failed: \(error.localizedDescription)")
        }
    }

    private func loadRunningTasks() async {
        do {
            let resp = try await client.listRunningQuantize()
            runningTasks = resp.tasks
        } catch {
            quantLog.warning("Load running tasks failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    private func startQuantize() {
        guard !selectedModelId.isEmpty else { return }
        isStarting = true
        lastError = nil
        successMsg = nil
        Task { @MainActor in
            do {
                _ = try await client.startQuantize(
                    modelId: selectedModelId,
                    format: selectedFormat,
                    bits: selectedBits,
                    preset: selectedPreset
                )
                successMsg = i18n.t(.hub_quantizeStarted)
                quantLog.info("Quantize started: \(selectedModelId) \(selectedBits)-bit \(selectedFormat)")
                await loadRunningTasks()
            } catch {
                lastError = error.localizedDescription
                quantLog.error("Quantize start failed: \(error.localizedDescription)")
            }
            isStarting = false
        }
    }

    private func assessQuantize() {
        guard !selectedModelId.isEmpty else { return }
        isAssessing = true
        layeredErrorMsg = nil
        Task { @MainActor in
            do {
                let result = try await client.compareQuantize(taskId: selectedModelId)
                assessmentResult = result
                quantLog.info("Quantize assessment done for \(selectedModelId), benchmarks=\(result.benchmarks.count)")
            } catch {
                layeredErrorMsg = String(format: i18n.t(.hub_evalFailed), error.localizedDescription)
                quantLog.error("Assess quantize failed: \(error.localizedDescription)")
            }
            isAssessing = false
        }
    }

    private func startLayeredQuantize() {
        guard !selectedModelId.isEmpty else { return }
        isLayeredStarting = true
        layeredErrorMsg = nil
        successMsg = nil
        Task { @MainActor in
            do {
                _ = try await client.startLayeredQuantize(
                    modelId: selectedModelId,
                    format: selectedFormat,
                    bits: selectedBits,
                    kvCacheOptimize: kvCacheOpt,
                    attentionQuantize: attentionQuant
                )
                successMsg = i18n.t(.hub_layeredQuantizeStarted)
                quantLog.info("Layered quantize started: \(selectedModelId) \(selectedBits)-bit kv=\(kvCacheOpt) attn=\(attentionQuant)")
                await loadRunningTasks()
            } catch {
                layeredErrorMsg = String(format: i18n.t(.hub_layeredQuantFailed), error.localizedDescription)
                quantLog.error("Layered quantize failed: \(error.localizedDescription)")
            }
            isLayeredStarting = false
        }
    }

    private func compareQuantizeResult() {
        guard let taskId = latestCompletedTaskId else { return }
        isComparing = true
        compareErrorMsg = nil
        Task { @MainActor in
            do {
                let result = try await client.compareQuantize(taskId: taskId)
                compareResult = result
                quantLog.info("Compare quantize done for task \(taskId), benchmarks=\(result.benchmarks.count)")
            } catch {
                compareErrorMsg = String(format: i18n.t(.hub_compareFailed), error.localizedDescription)
                quantLog.error("Compare quantize failed: \(error.localizedDescription)")
            }
            isComparing = false
        }
    }

    private func triggerEvaluate() {
        guard !selectedModelId.isEmpty else { return }
        isEvaluating = true
        evaluateErrorMsg = nil
        evaluateSuccessMsg = nil
        let modelId = selectedModelId
        Task { @MainActor in
            do {
                _ = try await client.triggerBenchmark(modelId: modelId)
                evaluateSuccessMsg = String(format: i18n.t(.hub_evalStartedForModel), modelId)
                evaluateModelId = modelId
                quantLog.info("Evaluation triggered for model \(modelId)")
            } catch {
                evaluateErrorMsg = String(format: i18n.t(.hub_evalFailed), error.localizedDescription)
                quantLog.error("Evaluate model failed: \(error.localizedDescription)")
            }
            isEvaluating = false
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { await loadRunningTasks() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - Scene Preset Definition

private enum QuantScenePreset: String, CaseIterable, Identifiable {
    case chat = "chat"
    case code = "code"
    case embedding = "embedding"
    case rag = "rag"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat: return I18nManager.shared.t(.hub_presetChatLabel)
        case .code: return I18nManager.shared.t(.hub_presetCodeLabel)
        case .embedding: return I18nManager.shared.t(.hub_presetEmbeddingLabel)
        case .rag: return I18nManager.shared.t(.hub_presetRagLabel)
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .embedding: return "point.3.connected.trianglepath.dotted"
        case .rag: return "doc.text.magnifyingglass"
        }
    }

    var format: String {
        switch self {
        case .chat, .code, .embedding: return "mlx"
        case .rag: return "gguf"
        }
    }

    var bits: Int {
        switch self {
        case .chat, .rag: return 4
        case .code: return 8
        case .embedding: return 16
        }
    }

    var memoryLabel: String {
        switch self {
        case .chat: return I18nManager.shared.t(.hub_presetChatMem)
        case .code: return I18nManager.shared.t(.hub_presetCodeMem)
        case .embedding: return I18nManager.shared.t(.hub_presetEmbeddingMem)
        case .rag: return I18nManager.shared.t(.hub_presetRagMem)
        }
    }

    var description: String {
        switch self {
        case .chat: return I18nManager.shared.t(.hub_presetChatDesc)
        case .code: return I18nManager.shared.t(.hub_presetCodeDesc)
        case .embedding: return I18nManager.shared.t(.hub_presetEmbeddingDesc)
        case .rag: return I18nManager.shared.t(.hub_presetRagDesc)
        }
    }

    var kvCacheOpt: Bool {
        switch self {
        case .chat, .rag: return true
        case .code, .embedding: return false
        }
    }

    var attentionQuant: Bool {
        switch self {
        case .chat: return true
        case .rag: return true
        case .code, .embedding: return false
        }
    }
}

// MARK: - Quant Task Row

private struct QuantTaskRow: View {
    let task: HubQuantizeTask
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : (task.isFailed ? "xmark.circle.fill" : "arrow.triangle.2.circlepath"))
                    .foregroundStyle(task.isComplete ? .green : (task.isFailed ? .red : .orange))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.modelId ?? task.id)
                        .font(.system(size: theme.textSize, weight: .medium))
                    HStack(spacing: 8) {
                        if let fmt = task.targetFormat { Text(fmt.uppercased()).font(.caption) }
                        if let bits = task.bits { Text("\(bits)-bit").font(.caption) }
                        Text(task.status ?? "running").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !task.isComplete && !task.isFailed {
                    VStack(alignment: .trailing) {
                        ProgressView(value: task.progress ?? 0)
                            .frame(width: 80)
                        Text("\(task.progressPct)%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            if let bench = task.benchmarkResult, task.isComplete {
                HStack(spacing: theme.spacingM) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.caption).foregroundStyle(.blue)
                    Text(i18n.t(.hub_benchResultColon)).font(.caption).foregroundStyle(.secondary)
                    if let acc = bench.accuracy {
                        Text(String(format: i18n.t(.hub_accuracyPrefix), acc * 100))
                            .font(.caption)
                            .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                    }
                    if let tps = bench.tokensPerSecond {
                        Text(String(format: "%.1f tok/s", tps)).font(.caption).foregroundStyle(.blue)
                    }
                    if let ttft = bench.timeToFirstToken {
                        Text(String(format: i18n.t(.hub_firstTokenPrefix), ttft)).font(.caption).foregroundStyle(.secondary)
                    }
                    if let mem = bench.memoryPeak {
                        Text(String(format: i18n.t(.hub_memoryPrefix), mem)).font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}
