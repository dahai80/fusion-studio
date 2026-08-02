// Callers: ModelHubMainView contentArea switch on .schedule.
// Affected API: ModelHubAPIClient listDownloads/getDownload/createDownload.
// Data schemas: HubDownloadTask, HubDownloadListResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let schedLog = Logger(subsystem: "com.fusion.studio", category: "HubSchedule")

struct HubScheduleView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var tasks: [HubDownloadTask] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var pollTimer: Timer?
    @State private var showNewDownload = false
    @State private var newRepoId = ""
    @State private var newSource = "huggingface"
    @State private var newFormat = "mlx"
    @State private var newQuant = "4bit"

    private let sourceOptions = ["huggingface", "modelscope", "private"]
    private let formatOptions = ["mlx", "safetensors", "gguf", "onnx"]
    private let quantOptions = ["fp16", "8bit", "4bit", "3bit", "2bit"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            taskList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadTasks(); startPolling() }
        .onDisappear { stopPolling() }
        .sheet(isPresented: $showNewDownload) { newDownloadSheet }
    }

    private var header: some View {
        HStack {
            Text("下载调度")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            let active = tasks.filter { !$0.isComplete && !$0.isFailed }.count
            if active > 0 {
                Text("\(active) 个下载中")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            Button("新建下载") { showNewDownload = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(theme.spacingM)
    }

    private var taskList: some View {
        Group {
            if isLoading && tasks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tasks.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("暂无下载任务")
                        .foregroundStyle(theme.textSecondary)
                    Button("下载新模型") { showNewDownload = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tasks) { task in
                    DownloadTaskRow(task: task)
                }
                .listStyle(.plain)
            }
            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
    }

    private var newDownloadSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("新建下载")
                .font(.title2).bold()

            TextField("Repo ID (如 mlx-community/Qwen3-9B-4bit)", text: $newRepoId)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("来源", selection: $newSource) {
                    ForEach(sourceOptions, id: \.self) { s in Text(sourceLabel(s)).tag(s) }
                }
                .pickerStyle(.menu)

                Picker("格式", selection: $newFormat) {
                    ForEach(formatOptions, id: \.self) { f in Text(f.uppercased()).tag(f) }
                }
                .pickerStyle(.menu)

                Picker("量化", selection: $newQuant) {
                    ForEach(quantOptions, id: \.self) { q in Text(q).tag(q) }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("取消") { showNewDownload = false }.buttonStyle(.bordered)
                Button("开始下载") {
                    startDownload()
                    showNewDownload = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newRepoId.isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
    }

    private func loadTasks() async {
        isLoading = true
        do {
            let resp = try await client.listDownloads()
            tasks = resp.tasks
        } catch {
            lastError = error.localizedDescription
            schedLog.warning("Load tasks failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func startDownload() {
        Task { @MainActor in
            do {
                _ = try await client.createDownload(repoId: newRepoId, source: newSource, format: newFormat, quantization: newQuant)
                schedLog.info("Download started: \(newRepoId)")
                await loadTasks()
                newRepoId = ""
            } catch {
                lastError = error.localizedDescription
                schedLog.error("Download start failed: \(error.localizedDescription)")
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { await loadTasks() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "huggingface": return "HuggingFace"
        case "modelscope": return "ModelScope"
        case "private": return "私有仓库"
        default: return s
        }
    }
}

private struct DownloadTaskRow: View {
    let task: HubDownloadTask
    @Environment(\.studioTheme) private var theme

    private var statusIcon: String {
        if task.isComplete { return "checkmark.circle.fill" }
        if task.isFailed { return "xmark.circle.fill" }
        return "arrow.down.circle"
    }

    private var statusColor: Color {
        if task.isComplete { return .green }
        if task.isFailed { return .red }
        return .orange
    }

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: statusIcon).foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.repoId ?? task.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 8) {
                    if let src = task.source { Text(src).font(.caption).foregroundStyle(.secondary) }
                    if let fmt = task.targetFormat { Text(fmt.uppercased()).font(.caption).foregroundStyle(.secondary) }
                    if let q = task.quantization { Text(q).font(.caption).foregroundStyle(.secondary) }
                    Text(task.status ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !task.isComplete && !task.isFailed {
                VStack(alignment: .trailing, spacing: 2) {
                    ProgressView(value: task.progress ?? 0).frame(width: 100)
                    HStack(spacing: 8) {
                        if let speed = task.speed { Text(speed).font(.caption2) }
                        if let eta = task.eta { Text("ETA \(eta)").font(.caption2) }
                    }
                    .foregroundStyle(.secondary)
                    Text("\(task.progressPct)%").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
