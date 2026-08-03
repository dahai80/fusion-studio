// Callers: ModelHubMainView contentArea switch on .benchmark.
// Affected API: ModelHubAPIClient triggerBenchmark/getBenchmarkCompare/listBenchmarks/getBenchmarkDetail/listEvaluations/createEvaluation.
// Data schemas: HubBenchmarkEntry, HubBenchmarkDetail, HubEvaluation, HubThresholdConfig.
// PRD: Benchmark + auto-trigger rule after quantize/version update

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

    // Tab state
    @State private var selectedTab = 0

    // Detail expansion
    @State private var expandedBenchmarkId: String?
    @State private var benchmarkDetails: [String: HubBenchmarkDetail] = [:]

    // Evaluations
    @State private var evaluations: [HubEvaluation] = []
    @State private var evalModelId: String?
    @State private var evalTemplate: String?
    @State private var showNewEvalSheet = false

    // History
    @State private var historyBenchmarks: [HubBenchmarkEntry] = []

    // Threshold alerts
    @State private var thresholdConfig = HubThresholdConfig()
    @State private var showThresholdSheet = false
    @AppStorage("hubThresholdAccuracy") private var storedAccuracyThreshold: Double = 0.7
    @AppStorage("hubThresholdScore") private var storedScoreThreshold: Double = 50.0

    // Auto-trigger rules (PRD)
    @AppStorage("hubAutoBenchAfterQuantize") private var autoBenchAfterQuantize = true
    @AppStorage("hubAutoBenchAfterVersionUpdate") private var autoBenchAfterVersionUpdate = false
    @AppStorage("hubAutoBenchTemplate") private var autoBenchTemplate = "general"

    private let templates = ["general", "code", "reasoning", "multilingual", "vision"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                headerSection

                Picker("", selection: $selectedTab) {
                    Text("性能评测").tag(0)
                    Text("评测").tag(1)
                }
                .pickerStyle(.segmented)

                if selectedTab == 0 {
                    modelPickerSection
                    quantizeBenchmarkSection
                    autoTriggerSection
                    benchmarkResults
                    historySection
                } else {
                    evaluationsSection
                }
            }
            .padding(theme.spacingL)
        }
        .sheet(isPresented: $showThresholdSheet) {
            thresholdSheet
        }
        .task {
            loadThresholdConfig()
            await loadModels()
            await loadHistory()
            await loadEvaluations()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("性能评测")
                    .font(.system(size: theme.largeTitleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { showThresholdSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("设置阈值")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

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

    // MARK: - Benchmark Results with Detail Expansion + Threshold Alerts

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
                let isExpanded = expandedBenchmarkId == entry.id
                let alertLevel = thresholdAlertLevel(for: entry)

                VStack(spacing: 0) {
                    Button(action: { toggleBenchmarkDetail(entry) }) {
                        HStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(entry.modelName ?? entry.modelId ?? entry.id)
                            }
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
                                HStack(spacing: 2) {
                                    Text(String(format: "%.1f%%", acc * 100))
                                    if alertLevel != .none {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(alertLevel == .critical ? .red : .yellow)
                                    }
                                }
                                .frame(width: 80)
                                .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                            } else { Text("-").frame(width: 80) }
                            if let score = entry.score {
                                HStack(spacing: 2) {
                                    Text(String(format: "%.1f", score))
                                    if alertLevel != .none {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(alertLevel == .critical ? .red : .yellow)
                                    }
                                }
                                .frame(width: 70)
                                .foregroundStyle(score > 80 ? .green : (score > 50 ? .orange : .red))
                            } else { Text("-").frame(width: 70) }
                        }
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(alertLevel == .critical ? Color.red.opacity(0.08) : (alertLevel == .warning ? Color.yellow.opacity(0.06) : Color.clear))
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        benchmarkDetailRow(for: entry)
                    }

                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func benchmarkDetailRow(for entry: HubBenchmarkEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            if let detail = benchmarkDetails[entry.id] {
                detailGrid(detail)
            } else if entry.id == expandedBenchmarkId {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text("加载详情...")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(8)
            }

            // Fallback: show what we already have from HubBenchmarkEntry
            if benchmarkDetails[entry.id] == nil {
                simpleDetailFallback(entry)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    @ViewBuilder
    private func detailGrid(_ detail: HubBenchmarkDetail) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingS) {
            detailMetricCard("每Token延迟", value: detail.perTokenLatency, format: "%.2f ms", icon: "clock")
            detailMetricCard("首Token延迟", value: detail.firstTokenLatency, format: "%.2f ms", icon: "bolt.horizontal")
            detailMetricCard("Prefill延迟", value: detail.prefillLatency, format: "%.2f ms", icon: "arrow.right.circle")
            detailMetricCard("Decode延迟", value: detail.decodeLatency, format: "%.2f ms", icon: "text.append")
            detailMetricCard("Batch=1 吞吐", value: detail.throughputBatch1, format: "%.1f t/s", icon: "1.circle")
            detailMetricCard("Batch=2 吞吐", value: detail.throughputBatch2, format: "%.1f t/s", icon: "2.circle")
            detailMetricCard("Batch=4 吞吐", value: detail.throughputBatch4, format: "%.1f t/s", icon: "4.circle")
            detailMetricCard("Batch=8 吞吐", value: detail.throughputBatch8, format: "%.1f t/s", icon: "8.circle")
            detailMetricCard("内存占用", value: detail.memoryFootprint, format: "%.1f GB", icon: "memorychip")
        }
    }

    @ViewBuilder
    private func detailMetricCard(_ label: String, value: Double?, format: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }
            if let v = value {
                Text(String(format: format, v))
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
            } else {
                Text("-")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }

    @ViewBuilder
    private func simpleDetailFallback(_ entry: HubBenchmarkEntry) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingS) {
            detailMetricCard("Tokens/s", value: entry.tokensPerSecond, format: "%.1f", icon: "speedometer")
            detailMetricCard("首Token延迟", value: entry.timeToFirstToken, format: "%.3f s", icon: "bolt.horizontal")
            detailMetricCard("峰值内存", value: entry.memoryPeak, format: "%.1f GB", icon: "memorychip")
            detailMetricCard("准确率", value: entry.accuracy.map { $0 * 100 }, format: "%.1f%%", icon: "checkmark.shield")
            detailMetricCard("评分", value: entry.score, format: "%.1f", icon: "star")
            if let completed = entry.completedAt {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("完成时间")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(completed)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(4)
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text("历史评测记录")
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { Task { await loadHistory() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if historyBenchmarks.isEmpty {
                    Text("暂无历史记录")
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    historyTable
                }
            }
            .padding(8)
        }
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("时间").frame(width: 150, alignment: .leading)
                Text("模型").frame(width: 160, alignment: .leading)
                Text("模板").frame(width: 80)
                Text("Tokens/s").frame(width: 80)
                Text("准确率").frame(width: 70)
                Text("评分").frame(width: 60)
                Text("对比").frame(width: 60)
            }
            .font(.caption).foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 8).padding(.vertical, 4)

            Divider()

            ForEach(Array(historyBenchmarks.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 0) {
                    Text(entry.completedAt ?? "-")
                        .frame(width: 150, alignment: .leading)
                    Text(entry.modelName ?? entry.modelId ?? "-")
                        .frame(width: 160, alignment: .leading)
                    Text(templateLabel(entry.template ?? "general"))
                        .frame(width: 80)
                    if let tps = entry.tokensPerSecond {
                        Text(String(format: "%.1f", tps)).frame(width: 80)
                    } else { Text("-").frame(width: 80) }
                    if let acc = entry.accuracy {
                        Text(String(format: "%.1f%%", acc * 100)).frame(width: 70)
                            .foregroundStyle(acc > 0.9 ? .green : (acc > 0.7 ? .orange : .red))
                    } else { Text("-").frame(width: 70) }
                    if let score = entry.score {
                        Text(String(format: "%.1f", score)).frame(width: 60)
                            .foregroundStyle(score > 80 ? .green : (score > 50 ? .orange : .red))
                    } else { Text("-").frame(width: 60) }

                    // Regression/improvement indicator vs previous run of same model
                    historyDeltaIcon(for: entry, at: index)
                        .frame(width: 60)
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 8).padding(.vertical, 4)

                Divider()
            }
        }
    }

    @ViewBuilder
    private func historyDeltaIcon(for entry: HubBenchmarkEntry, at index: Int) -> some View {
        let modelId = entry.modelId ?? entry.id
        let sameModelEntries = historyBenchmarks.filter { ($0.modelId ?? $0.id) == modelId }
        if sameModelEntries.count > 1,
           let currentIdx = sameModelEntries.firstIndex(where: { $0.id == entry.id }),
           currentIdx > 0,
           let currentScore = entry.score,
           let prevScore = sameModelEntries[sameModelEntries.index(before: currentIdx)].score
        {
            let delta = currentScore - prevScore
            if delta > 1 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                    Text(String(format: "+%.1f", delta))
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            } else if delta < -1 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%.1f", delta))
                        .font(.caption2)
                }
                .foregroundStyle(.red)
            } else {
                Text("持平")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }
        } else {
            Text("-").foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Evaluations Tab

    private var evaluationsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text("模型评测")
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { showNewEvalSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("新建评测")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if evaluations.isEmpty {
                    Text("暂无评测记录")
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    evalTable
                }
            }
            .padding(8)
        }
        .sheet(isPresented: $showNewEvalSheet) {
            newEvalSheet
        }
    }

    private var evalTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("模型").frame(width: 180, alignment: .leading)
                Text("评测类型").frame(width: 120)
                Text("评分").frame(width: 80)
                Text("状态").frame(width: 80)
                Text("日期").frame(width: 120, alignment: .leading)
            }
            .font(.caption).foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 8).padding(.vertical, 4)

            Divider()

            ForEach(evaluations) { ev in
                HStack(spacing: 0) {
                    Text(ev.modelName ?? ev.modelId ?? "-")
                        .frame(width: 180, alignment: .leading)
                    Text(evalTypeLabel(ev.template))
                        .frame(width: 120)
                    if let score = ev.overallScore {
                        Text(String(format: "%.1f", score))
                            .frame(width: 80)
                            .foregroundStyle(score > 80 ? .green : (score > 50 ? .orange : .red))
                    } else {
                        Text("-").frame(width: 80)
                    }
                    evalStatusLabel(ev.status)
                        .frame(width: 80)
                    Text(ev.completedAt ?? ev.createdAt ?? "-")
                        .frame(width: 120, alignment: .leading)
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 8).padding(.vertical, 6)

                Divider()
            }
        }
    }

    @ViewBuilder
    private func evalStatusLabel(_ status: String?) -> some View {
        switch status {
        case "completed", "done":
            Text("完成").foregroundStyle(.green)
        case "running", "in_progress":
            HStack(spacing: 2) {
                ProgressView().controlSize(.mini)
                Text("运行中")
            }
            .foregroundStyle(.blue)
        case "failed", "error":
            Text("失败").foregroundStyle(.red)
        case "pending", "queued":
            Text("等待中").foregroundStyle(.orange)
        default:
            Text(status ?? "未知").foregroundStyle(theme.textTertiary)
        }
    }

    private var newEvalSheet: some View {
        VStack(spacing: theme.spacingL) {
            Text("新建评测")
                .font(.system(size: theme.headlineSize, weight: .bold))

            GroupBox {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    Text("选择模型")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)

                    Picker("模型", selection: $evalModelId) {
                        Text("请选择").tag(nil as String?)
                        ForEach(models.filter { $0.isDownloaded == true }) { model in
                            Text(model.displayTitle).tag(model.id as String?)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("评测模板")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)

                    Picker("模板", selection: $evalTemplate) {
                        Text("通用").tag(nil as String?)
                        ForEach(["accuracy", "alignment", "safety", "code", "reasoning"], id: \.self) { t in
                            Text(evalTypeLabel(t)).tag(t as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(8)
            }

            HStack {
                Button("取消") { showNewEvalSheet = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("创建") {
                    createEvaluation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(evalModelId == nil)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    // MARK: - Threshold Sheet

    private var thresholdSheet: some View {
        VStack(spacing: theme.spacingL) {
            Text("准确率阈值设置")
                .font(.system(size: theme.headlineSize, weight: .bold))

            GroupBox {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    Text("全局阈值")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("准确率警告阈值: \(String(format: "%.0f%%", thresholdConfig.accuracyThreshold * 100))")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Slider(value: $thresholdConfig.accuracyThreshold, in: 0...1, step: 0.05)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("评分警告阈值: \(String(format: "%.0f", thresholdConfig.scoreThreshold))")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Slider(value: $thresholdConfig.scoreThreshold, in: 0...100, step: 5)
                    }

                    Divider()

                    Text("低于阈值的评测结果将标记警告")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    HStack(spacing: theme.spacingS) {
                        Circle().fill(Color.yellow.opacity(0.6)).frame(width: 8, height: 8)
                        Text("黄色 = 接近阈值").font(.caption2).foregroundStyle(theme.textTertiary)
                        Circle().fill(Color.red.opacity(0.6)).frame(width: 8, height: 8)
                        Text("红色 = 低于阈值").font(.caption2).foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(8)
            }

            if !benchmarks.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text("按模型设置")
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)

                        let uniqueModelIds = Array(Set(benchmarks.compactMap { $0.modelId })).sorted()
                        ForEach(uniqueModelIds, id: \.self) { mid in
                            HStack {
                                Text(mid)
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Text("准确率: \(String(format: "%.0f%%", thresholdConfig.accuracyThreshold(for: mid) * 100))")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                    .padding(8)
                }
            }

            HStack {
                Button("取消") {
                    showThresholdSheet = false
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("保存") {
                    saveThresholdConfig()
                    showThresholdSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450)
    }

    // MARK: - Threshold Logic

    enum ThresholdAlertLevel {
        case none, warning, critical
    }

    private func thresholdAlertLevel(for entry: HubBenchmarkEntry) -> ThresholdAlertLevel {
        let mid = entry.modelId ?? entry.id
        let accThreshold = thresholdConfig.accuracyThreshold(for: mid)
        let scoreThreshold = thresholdConfig.scoreThreshold(for: mid)

        var isCritical = false
        var isWarning = false

        if let acc = entry.accuracy {
            if acc < accThreshold * 0.8 { isCritical = true }
            else if acc < accThreshold { isWarning = true }
        }

        if let score = entry.score {
            if score < scoreThreshold * 0.6 { isCritical = true }
            else if score < scoreThreshold { isWarning = true }
        }

        if isCritical { return .critical }
        if isWarning { return .warning }
        return .none
    }

    private func loadThresholdConfig() {
        thresholdConfig.accuracyThreshold = storedAccuracyThreshold
        thresholdConfig.scoreThreshold = storedScoreThreshold
        benchLog.info("Threshold config loaded: accuracy=\(storedAccuracyThreshold), score=\(storedScoreThreshold)")
    }

    private func saveThresholdConfig() {
        storedAccuracyThreshold = thresholdConfig.accuracyThreshold
        storedScoreThreshold = thresholdConfig.scoreThreshold
        benchLog.info("Threshold config saved: accuracy=\(thresholdConfig.accuracyThreshold), score=\(thresholdConfig.scoreThreshold)")
    }

    // MARK: - Data Loading

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
            benchLog.error("Load models failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadHistory() async {
        do {
            let resp = try await client.listBenchmarks(limit: 100)
            historyBenchmarks = resp.benchmarks
            benchLog.info("History loaded: \(historyBenchmarks.count) benchmark entries")
        } catch {
            benchLog.error("Load history failed: \(error.localizedDescription)")
        }
    }

    private func loadEvaluations() async {
        do {
            let resp = try await client.listEvaluations()
            evaluations = resp.evaluations
            benchLog.info("Evaluations loaded: \(evaluations.count) entries")
        } catch {
            benchLog.error("Load evaluations failed: \(error.localizedDescription)")
        }
    }

    private func toggleBenchmarkDetail(_ entry: HubBenchmarkEntry) {
        if expandedBenchmarkId == entry.id {
            expandedBenchmarkId = nil
            benchLog.info("Benchmark detail collapsed: \(entry.id)")
            return
        }
        expandedBenchmarkId = entry.id
        benchLog.info("Benchmark detail expanded: \(entry.id)")

        if benchmarkDetails[entry.id] == nil {
            Task { @MainActor in
                do {
                    let detail = try await client.getBenchmarkDetail(id: entry.id)
                    benchmarkDetails[entry.id] = detail
                    benchLog.info("Benchmark detail loaded: \(entry.id)")
                } catch {
                    benchLog.warning("Benchmark detail load failed, using fallback: \(error.localizedDescription)")
                }
            }
        }
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
                await loadHistory()
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
                benchLog.error("Compare failed: \(error.localizedDescription)")
            }
        }
    }

    private func createEvaluation() {
        guard let mid = evalModelId else { return }
        Task { @MainActor in
            do {
                _ = try await client.createEvaluation(modelId: mid, template: evalTemplate)
                benchLog.info("Evaluation created: model=\(mid), template=\(evalTemplate ?? "default")")
                showNewEvalSheet = false
                evalModelId = nil
                evalTemplate = nil
                await loadEvaluations()
                successMsg = "评测任务已创建"
            } catch {
                lastError = error.localizedDescription
                benchLog.error("Create evaluation failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

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

    private func evalTypeLabel(_ t: String?) -> String {
        switch t {
        case "accuracy": return "准确率"
        case "alignment": return "对齐度"
        case "safety": return "安全性"
        case "code": return "代码能力"
        case "reasoning": return "推理能力"
        case "general": return "通用"
        default: return t ?? "综合评测"
        }
    }
}
