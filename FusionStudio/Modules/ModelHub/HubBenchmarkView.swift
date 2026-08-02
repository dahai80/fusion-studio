// Callers: ModelHubMainView contentArea switch on .benchmark.
// Affected API: ModelHubAPIClient triggerBenchmark/getBenchmarkCompare.
// Data schemas: HubBenchmarkEntry, HubBenchmarkCompareResponse.
// PRD: Benchmark + auto-trigger rule after quantize/version update
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let benchLog = Logger(subsystem: "com.fusion.studio", category: "HubBenchmark")

struct HubBenchmarkView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var models: [HubModel] = []
    @State private var benchmarks: [HubBenchmarkEntry] = []
    @State private var selectedModelIds: Set<String> = []
    @State private var selectedTemplate = "general"
    @State private var isRunning = false
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var successMsg: String?
    @State private var quantizeTasks: [HubQuantizeTask] = []

    // Auto-trigger rules (PRD)
    @AppStorage("hubAutoBenchAfterQuantize") private var autoBenchAfterQuantize = true
    @AppStorage("hubAutoBenchAfterVersionUpdate") private var autoBenchAfterVersionUpdate = false
    @AppStorage("hubAutoBenchTemplate") private var autoBenchTemplate = "general"

    private let templates = ["general", "code", "reasoning", "multilingual", "vision"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                headerSection
                modelPickerSection
                quantizeBenchmarkSection
                autoTriggerSection
                benchmarkResults
            }
            .padding(theme.spacingL)
        }
        .task { await loadModels() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("性能评测")
                .font(.system(size: theme.largeTitleSize, weight: .bold))
                .foregroundStyle(theme.text)

            Text("对比模型推理性能：Tokens/s、首 Token 延迟、峰值内存")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingM) {
                Picker("评测模板", selection: $selectedTemplate) {
                    ForEach(templates, id: \.self) { t in Text(templateLabel(t)).tag(t) }
                }
                .pickerStyle(.menu)

                Button(action: runBenchmark) {
                    HStack {
                        if isRunning { ProgressView().controlSize(.small) }
                        Text("运行评测")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedModelIds.isEmpty || isRunning)

                if !selectedModelIds.isEmpty {
                    Button("对比选中 (\(selectedModelIds.count))") {
                        compareSelected()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedModelIds.count < 2)
                }
            }

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            if let msg = successMsg {
                Text(msg).font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var modelPickerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("选择评测模型")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if models.isEmpty {
                    Text("加载中...").foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(Array(models.filter { $0.isDownloaded == true }), id: \.id) { model in
                        let selected = selectedModelIds.contains(model.id)
                        Button(action: {
                            if selected { selectedModelIds.remove(model.id) }
                            else { selectedModelIds.insert(model.id) }
                        }) {
                            HStack(spacing: theme.spacingS) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                                Text(model.displayTitle)
                                    .font(.system(size: theme.textSize))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                if let fam = model.family { Text(fam).font(.caption).foregroundStyle(.secondary) }
                                if let q = model.quantization { Text(q).font(.caption).foregroundStyle(.secondary) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
        }
    }

    // issue #63 sub-feature 3: linked quantize benchmark results
    private var quantizeBenchmarkSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("量化关联评测")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("量化任务完成后的自动评测结果")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                let completedWithBench = quantizeTasks.filter { $0.isComplete && $0.benchmarkResult != nil }
                if completedWithBench.isEmpty {
                    Text("暂无量化关联评测数据")
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(completedWithBench) { task in
                        if let bench = task.benchmarkResult {
                            HStack(spacing: theme.spacingM) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.modelId ?? task.id)
                                        .font(.system(size: theme.textSize, weight: .medium))
                                        .foregroundStyle(theme.text)
                                    HStack(spacing: theme.spacingS) {
                                        if let bits = task.bits { Text("\(bits)-bit").font(.caption).foregroundStyle(.secondary) }
                                        if let fmt = task.targetFormat { Text(fmt).font(.caption).foregroundStyle(.secondary) }
                                    }
                                }
                                Spacer()
                                if let acc = bench.accuracy {
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.1f%%", acc * 100))
                                            .font(.system(size: theme.textSize, weight: .semibold))
                                            .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                                        Text("准确率").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                if let tps = bench.tokensPerSecond {
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.1f", tps))
                                            .font(.system(size: theme.textSize, weight: .semibold))
                                            .foregroundStyle(.blue)
                                        Text("Tokens/s").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                if let ttft = bench.timeToFirstToken {
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.2fs", ttft))
                                            .font(.system(size: theme.textSize, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text("首Token").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                if let mem = bench.memoryPeak {
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.1f GB", mem))
                                            .font(.system(size: theme.textSize, weight: .medium))
                                            .foregroundStyle(.orange)
                                        Text("内存").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    // PRD: auto-trigger rule after quantize / version update
    private var autoTriggerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("自动评测规则")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                Toggle(isOn: $autoBenchAfterQuantize) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("量化完成后自动评测")
                            .foregroundStyle(theme.text)
                        Text("模型量化转换成功后，自动运行性能评测")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Toggle(isOn: $autoBenchAfterVersionUpdate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("版本更新后自动评测")
                            .foregroundStyle(theme.text)
                        Text("模型新版本加载后，自动运行性能评测对比")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                HStack(spacing: theme.spacingS) {
                    Text("自动评测模板:")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Picker("", selection: $autoBenchTemplate) {
                        ForEach(templates, id: \.self) { t in Text(templateLabel(t)).tag(t) }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }
            .padding(8)
        }
    }

    private var benchmarkResults: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("评测结果")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if benchmarks.isEmpty {
                    Text("暂无评测数据，选择模型并运行评测")
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    benchmarkTable
                }
            }
            .padding(8)
        }
    }

    private var benchmarkTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("模型").frame(width: 180, alignment: .leading)
                Text("Tokens/s").frame(width: 90)
                Text("首Token延迟").frame(width: 90)
                Text("峰值内存").frame(width: 90)
                Text("准确率").frame(width: 80)
                Text("评分").frame(width: 70)
            }
            .font(.caption).foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 8).padding(.vertical, 4)

            Divider()

            ForEach(benchmarks) { entry in
                HStack(spacing: 0) {
                    Text(entry.modelName ?? entry.modelId ?? entry.id)
                        .frame(width: 180, alignment: .leading)
                    if let tps = entry.tokensPerSecond {
                        Text(String(format: "%.1f", tps)).frame(width: 90)
                    } else { Text("-").frame(width: 90) }
                    if let ttft = entry.timeToFirstToken {
                        Text(String(format: "%.2fs", ttft)).frame(width: 90)
                    } else { Text("-").frame(width: 90) }
                    if let mem = entry.memoryPeak {
                        Text(String(format: "%.1f GB", mem)).frame(width: 90)
                    } else { Text("-").frame(width: 90) }
                    if let acc = entry.accuracy {
                        Text(String(format: "%.1f%%", acc * 100)).frame(width: 80)
                            .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                    } else { Text("-").frame(width: 80) }
                    if let score = entry.score {
                        Text(String(format: "%.1f", score)).frame(width: 70)
                            .foregroundStyle(score > 80 ? .green : (score > 50 ? .orange : .red))
                    } else { Text("-").frame(width: 70) }
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 8).padding(.vertical, 6)

                Divider()
            }
        }
    }

    private func loadModels() async {
        isLoading = true
        do {
            async let modelsResp = client.listModels()
            async let tasksResp = client.listRunningQuantize()
            let m = try await modelsResp
            let t = try await tasksResp
            models = m.models
            quantizeTasks = t.tasks
            benchLog.info("Loaded \(models.count) models, \(quantizeTasks.count) quantize tasks for benchmark")
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    private func runBenchmark() {
        isRunning = true
        lastError = nil
        successMsg = nil
        Task { @MainActor in
            do {
                for modelId in selectedModelIds {
                    _ = try await client.triggerBenchmark(modelId: modelId, template: selectedTemplate)
                    benchLog.info("Benchmark triggered: \(modelId)")
                }
                successMsg = "评测已启动，稍后查看结果"
            } catch {
                lastError = error.localizedDescription
                benchLog.error("Benchmark failed: \(error.localizedDescription)")
            }
            isRunning = false
        }
    }

    private func compareSelected() {
        let ids = Array(selectedModelIds)
        Task { @MainActor in
            do {
                let resp = try await client.getBenchmarkCompare(modelIds: ids)
                benchmarks = resp.benchmarks
                benchLog.info("Compare loaded: \(benchmarks.count) entries")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func templateLabel(_ t: String) -> String {
        switch t {
        case "general": return "通用"
        case "code": return "代码"
        case "reasoning": return "推理"
        case "multilingual": return "多语言"
        case "vision": return "视觉"
        default: return t
        }
    }
}
