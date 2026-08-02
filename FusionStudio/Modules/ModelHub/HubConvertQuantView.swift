// Callers: ModelHubMainView contentArea switch on .convertQuant.
// Affected API: ModelHubAPIClient startQuantize/listQuantizePresets/listRunningQuantize/getQuantizeTask/batchQuantize.
// Data schemas: HubQuantizePreset, HubQuantizeTask, HubPresetListResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let quantLog = Logger(subsystem: "com.fusion.studio", category: "HubConvertQuant")

struct HubConvertQuantView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

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
                Text("转换 & 量化")
                    .font(.system(size: theme.largeTitleSize, weight: .bold))
                    .foregroundStyle(theme.text)

                GroupBox("选择模型") {
                    Picker("模型", selection: $selectedModelId) {
                        Text("选择模型...").tag("")
                        ForEach(localModels) { m in
                            Text(m.displayTitle).tag(m.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                GroupBox("量化配置") {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        HStack {
                            Text("目标格式").frame(width: 80, alignment: .leading)
                            Picker("", selection: $selectedFormat) {
                                ForEach(formatOptions, id: \.self) { f in Text(f.uppercased()).tag(f) }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack {
                            Text("量化位数").frame(width: 80, alignment: .leading)
                            Picker("", selection: $selectedBits) {
                                ForEach(bitOptions, id: \.self) { b in Text("\(b)-bit").tag(b) }
                            }
                            .pickerStyle(.segmented)
                        }

                        if !presets.isEmpty {
                            HStack {
                                Text("预设方案").frame(width: 80, alignment: .leading)
                                Picker("", selection: $selectedPreset) {
                                    Text("自定义").tag(nil as String?)
                                    ForEach(presets) { p in
                                        Text(p.name ?? p.id).tag(p.id as String?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        if let preset = presets.first(where: { $0.id == selectedPreset }) {
                            HStack {
                                Text("预计缩减").frame(width: 80, alignment: .leading)
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

                Button(action: startQuantize) {
                    HStack {
                        if isStarting { ProgressView().controlSize(.small) }
                        Text("开始量化")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedModelId.isEmpty || isStarting)

                if let err = lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if let msg = successMsg {
                    Text(msg).font(.caption).foregroundStyle(.green)
                }
            }
            .padding(theme.spacingL)
        }
        .frame(minWidth: 360, maxWidth: 500)
    }

    private var taskPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("量化任务")
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
                    Text("没有正在运行的量化任务")
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
                successMsg = "量化任务已启动"
                quantLog.info("Quantize started: \(selectedModelId) \(selectedBits)-bit \(selectedFormat)")
                await loadRunningTasks()
            } catch {
                lastError = error.localizedDescription
                quantLog.error("Quantize start failed: \(error.localizedDescription)")
            }
            isStarting = false
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

private struct QuantTaskRow: View {
    let task: HubQuantizeTask
    @Environment(\.studioTheme) private var theme

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
                    Text("评测结果:").font(.caption).foregroundStyle(.secondary)
                    if let acc = bench.accuracy {
                        Text(String(format: "准确率 %.1f%%", acc * 100))
                            .font(.caption)
                            .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                    }
                    if let tps = bench.tokensPerSecond {
                        Text(String(format: "%.1f tok/s", tps)).font(.caption).foregroundStyle(.blue)
                    }
                    if let ttft = bench.timeToFirstToken {
                        Text(String(format: "首Token %.2fs", ttft)).font(.caption).foregroundStyle(.secondary)
                    }
                    if let mem = bench.memoryPeak {
                        Text(String(format: "内存 %.1f GB", mem)).font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}
