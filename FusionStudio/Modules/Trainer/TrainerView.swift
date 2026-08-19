import SwiftUI
import os.log

// Callers: ModuleDetailView (case .trainer → TrainerView()), FusionSidebarView/SidebarSection.trainer.
// Affected API: TrainerView + subviews read TrainerBridge (@EnvironmentObject, injected in FusionStudioApp).
// Data schemas: TrainerRun/TrainerPreset/TrainerDataset/TrainerAdapter/TrainerProgressEvent (System/TrainerBridge.swift).
// User instruction: "continue Task" — fusion-trainer RunManager GUI panel (#175)

struct TrainerView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge
    @State private var selectedTab: TrainerTab = .runs

    enum TrainerTab: String, CaseIterable {
        case runs = "训练运行"
        case start = "启动训练"
        case presets = "预设"
        case datasets = "数据集"
        case adapters = "适配器"
        case info = "环境信息"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                eyebrow: "Fusion Trainer",
                title: "训练管理",
                subtitle: "SFT / RLSL / DPO / ORPO / GRPO — 本地训练编排，通过 trainer.* IPC 委托 fusion-mlx 执行梯度循环。"
            )

            HStack(spacing: 8) {
                Picker("", selection: $selectedTab) {
                    ForEach(TrainerTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button {
                    Task { await refreshAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(theme.toolbarBg)

            Divider()

            if let err = bridge.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(err).font(.caption).foregroundColor(theme.textSecondary).lineLimit(2)
                    Spacer()
                    Button("清除") { bridge.lastError = nil }.buttonStyle(.borderless).controlSize(.small)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(theme.accentSoft.opacity(0.3))
            }

            switch selectedTab {
            case .runs: TrainerRunsTab()
            case .start: TrainerStartTab()
            case .presets: TrainerPresetsTab()
            case .datasets: TrainerDatasetsTab()
            case .adapters: TrainerAdaptersTab()
            case .info: TrainerInfoTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.contentBg)
        .task { await refreshAll() }
        .onDisappear { bridge.stopPollingProgress() }
    }

    private func tabIcon(_ tab: TrainerTab) -> String {
        switch tab {
        case .runs: return "list.bullet.rectangle"
        case .start: return "play.circle.fill"
        case .presets: return "slider.horizontal.3"
        case .datasets: return "doc.text.fill"
        case .adapters: return "externaldrive.badge.plus"
        case .info: return "info.circle"
        }
    }

    private func refreshAll() async {
        await bridge.refreshRuns()
        await bridge.refreshPresets()
        await bridge.refreshDatasets()
        await bridge.refreshAdapters()
        await bridge.refreshInfo()
    }
}

// MARK: - Runs

struct TrainerRunsTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge

    var body: some View {
        HSplitView {
            runsList.frame(minWidth: 280)
            runDetail.frame(minWidth: 320)
        }
    }

    private var runsList: some View {
        VStack(spacing: 0) {
            if bridge.runs.isEmpty {
                EmptyStateView(icon: "tray", text: "暂无训练运行。在「启动训练」发起一次 SFT 或 RLSL。")
            } else {
                List(bridge.runs, selection: Binding(
                    get: { bridge.selectedRun?.run_id },
                    set: { id in bridge.selectRun(bridge.runs.first(where: { $0.run_id == id })) }
                )) { run in
                    runRow(run).tag(run.run_id)
                }
                .listStyle(.plain)
            }
        }
        .background(theme.surfacePrimary)
    }

    private func runRow(_ run: TrainerRun) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.method.uppercased()).font(.caption.bold()).foregroundColor(theme.accentText)
                Text(run.model).font(.caption).foregroundColor(theme.textSecondary).lineLimit(1)
                Spacer()
                statusBadge(run.status)
            }
            ProgressView(value: run.progress)
                .progressViewStyle(.linear)
                .tint(progressTint(run.status))
            HStack(spacing: 8) {
                Text("step \(run.current_step)/\(run.total_steps)").font(.caption2).foregroundColor(theme.textTertiary)
                Text(run.created_at).font(.caption2).foregroundColor(theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var runDetail: some View {
        Group {
            if let run = bridge.selectedRun {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(run.method.uppercased()) · \(run.model)").font(.headline)
                                Text("run_id: \(run.run_id)").font(.caption).foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            if run.status == "running" {
                                Button(role: .destructive) {
                                    Task { await bridge.stopRun(runId: run.run_id) }
                                } label: { Label("停止", systemImage: "stop.fill") }
                                .buttonStyle(.borderedProminent).tint(theme.accentDestructive).controlSize(.small)
                            }
                        }

                        detailRow("状态", run.status)
                        detailRow("进度", String(format: "%.1f%%", run.progress * 100))
                        detailRow("步数", "\(run.current_step) / \(run.total_steps)")
                        if let err = run.error, !err.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("错误").font(.caption.bold()).foregroundColor(.red)
                                Text(err).font(.caption).foregroundColor(.red).padding(8)
                                    .background(theme.accentSoft.opacity(0.3)).cornerRadius(6)
                            }
                        }

                        Divider()
                        Text("实时指标").font(.subheadline.bold())
                        if bridge.progressEvents.isEmpty {
                            Text("等待事件流…").font(.caption).foregroundColor(theme.textTertiary)
                        } else {
                            TrainerProgressChart(events: bridge.progressEvents)
                                .frame(height: 160)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(bridge.progressEvents.suffix(60)) { e in
                                        HStack {
                                            Text("step \(e.step)").font(.caption2).foregroundColor(theme.textTertiary).frame(width: 60, alignment: .leading)
                                            Text(e.metric).font(.caption2).frame(width: 120, alignment: .leading)
                                            Spacer()
                                            Text(String(format: "%.4f", e.value)).font(.caption2).foregroundColor(theme.accentText)
                                        }
                                    }
                                }
                                .padding(8)
                            }
                            .frame(maxHeight: 220)
                            .background(theme.surfaceSecondary).cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyStateView(icon: "sidebar.left", text: "选择左侧运行查看详情与实时指标。")
            }
        }
        .background(theme.contentBg)
        .onChange(of: bridge.selectedRun?.run_id) { _, newId in
            if let id = newId { bridge.startPollingProgress(runId: id) }
        }
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.caption).foregroundColor(theme.textSecondary).frame(width: 80, alignment: .leading)
            Text(v).font(.caption)
            Spacer()
        }
    }

    private func statusBadge(_ s: String) -> some View {
        let c: Color = {
            switch s {
            case "running": return theme.accent
            case "completed": return .green
            case "failed": return .red
            case "stopped": return .orange
            default: return theme.textTertiary
            }
        }()
        return Text(s).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
            .background(c.opacity(0.2)).foregroundColor(c).cornerRadius(4)
    }

    private func progressTint(_ s: String) -> Color {
        switch s {
        case "completed": return .green
        case "failed": return .red
        case "stopped": return .orange
        default: return theme.accent
        }
    }
}

struct TrainerProgressChart: View {
    let events: [TrainerProgressEvent]
    @Environment(\.studioTheme) private var theme

    var body: some View {
        let metrics = Dictionary(grouping: events, by: { $0.metric })
        GeometryReader { geo in
            ZStack {
                ForEach(Array(metrics.keys.sorted().enumerated()), id: \.element) { _, metric in
                    line(for: metrics[metric] ?? [], in: geo.size)
                }
            }
        }
    }

    private func line(for evs: [TrainerProgressEvent], in size: CGSize) -> some View {
        guard evs.count > 1 else { return AnyView(EmptyView()) }
        let vals = evs.map { $0.value }
        guard let minV = vals.min(), let maxV = vals.max(), maxV > minV else { return AnyView(EmptyView()) }
        let dx = size.width / CGFloat(max(evs.count - 1, 1))
        let path = Path { p in
            for (i, e) in evs.enumerated() {
                let x = CGFloat(i) * dx
                let y = size.height - CGFloat((e.value - minV) / (maxV - minV)) * size.height
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        return AnyView(path.stroke(theme.accent, lineWidth: 1.5))
    }
}

// MARK: - Start

struct TrainerStartTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge
    @State private var mode: TrainerMode = .sft
    @State private var model: String = "qwen2.5-7b-4bit"
    @State private var dataset: String = "hub:sft/code_alpaca"
    @State private var preset: String = "sft_7b_lora"
    @State private var method: String = "dpo"
    @State private var iters: Int = 100
    @State private var batchSize: Int = 2
    @State private var loraRank: Int = 16
    @State private var lr: Double = 1e-4

    enum TrainerMode: String, CaseIterable { case sft = "SFT 微调", rlsl = "RLSL 对齐" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("模式", selection: $mode) {
                    ForEach(TrainerMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Group {
                    Form {
                        Section("模型与数据") {
                            TextField("基础模型", text: $model)
                            TextField("数据集", text: $dataset)
                            Picker("预设", selection: $preset) {
                                ForEach(bridge.presets) { p in Text(p.name).tag(p.name) }
                            }
                        }
                        if mode == .rlsl {
                            Section("RLSL 方法") {
                                Picker("method", selection: $method) {
                                    ForEach(["dpo", "orpo", "grpo"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        Section("训练超参") {
                            Stepper("iters: \(iters)", value: $iters, in: 1...10000, step: 10)
                            Stepper("batch_size: \(batchSize)", value: $batchSize, in: 1...32)
                            Stepper("lora_rank: \(loraRank)", value: $loraRank, in: 4...128, step: 4)
                            HStack {
                                Text("lr: \(String(format: "%.1e", lr))")
                                Slider(value: $lr, in: 1e-6...1e-2).onAppear {
                                    if lr < 1e-6 { lr = 1e-4 }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 420)
                }
                .background(theme.surfaceSecondary).cornerRadius(8)

                HStack {
                    Spacer()
                    Button {
                        let cfg = buildConfig()
                        if mode == .sft { Task { await bridge.startSft(config: cfg) } }
                        else { Task { await bridge.startRlsl(config: cfg) } }
                    } label: {
                        Label(bridge.isStarting ? "提交中…" : "启动训练", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.regular)
                    .disabled(bridge.isStarting || model.isEmpty || dataset.isEmpty)
                }

                if bridge.isStarting { ProgressView().scaleEffect(0.8).padding(.top, 4) }
            }
            .padding(16)
        }
        .background(theme.contentBg)
    }

    private func buildConfig() -> [String: Any] {
        let datasetCfg: [String: Any] = ["path": dataset]
        let sftCfg: [String: Any] = [
            "iters": iters,
            "batch_size": batchSize,
            "lora_rank": loraRank,
            "lr": lr,
            "preset": preset,
        ]
        var base: [String: Any] = [
            "model": model,
            "dataset": datasetCfg,
            "sft": sftCfg,
            "seed": 42,
        ]
        if mode == .rlsl {
            base["rlsl"] = ["method": method, "preset": preset, "iters": iters, "batch_size": batchSize] as [String: Any]
        }
        return base
    }
}

// MARK: - Presets

struct TrainerPresetsTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if bridge.presets.isEmpty {
                    EmptyStateView(icon: "slider.horizontal.3", text: "无预设。确认 fusion-trainer 已安装且 IPC 已连接。")
                } else {
                    ForEach(bridge.presets) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(p.name).font(.headline)
                                Text(p.kind).font(.caption).foregroundColor(theme.textSecondary)
                                Spacer()
                                Text(String(format: "~%.0f GB", p.memory_estimate_gb))
                                    .font(.caption.bold()).foregroundColor(theme.accentText)
                            }
                            Text(p.summary).font(.caption).foregroundColor(theme.textSecondary)
                        }
                        .padding(12)
                        .background(theme.surfaceSecondary).cornerRadius(8)
                    }
                }
            }
            .padding(16)
        }
        .background(theme.contentBg)
    }
}

// MARK: - Datasets

struct TrainerDatasetsTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge
    @State private var previewName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if bridge.datasets.isEmpty {
                EmptyStateView(icon: "doc.text", text: "无数据集。fusion-trainer 从 hub 路径只读加载。")
            } else {
                List(bridge.datasets) { ds in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ds.name).font(.caption.bold())
                            Text(ds.path).font(.caption2).foregroundColor(theme.textTertiary).lineLimit(1)
                        }
                        Spacer()
                        Text("\(ds.samples) 样本").font(.caption2).foregroundColor(theme.textSecondary)
                        Text(ds.format).font(.caption2).foregroundColor(theme.accentText)
                        Button("预览") {
                            previewName = ds.name
                            Task { await bridge.previewDataset(name: ds.name) }
                        }
                        .buttonStyle(.borderless).controlSize(.small)
                    }
                }
                .listStyle(.plain)
            }
            Divider()
            if !bridge.datasetPreview.isEmpty {
                ScrollView {
                    Text(bridge.datasetPreview).font(.system(.caption, design: .monospaced))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
                .background(theme.surfaceSecondary)
            }
        }
        .background(theme.contentBg)
    }
}

// MARK: - Adapters

struct TrainerAdaptersTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge
    @State private var pendingDelete: TrainerAdapter?

    var body: some View {
        Group {
            if bridge.adapters.isEmpty {
                EmptyStateView(icon: "externaldrive.badge.plus", text: "无适配器。训练完成后权重写入 ~/.fusion-mlx/adapters/。")
            } else {
                List(bridge.adapters) { ad in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ad.name).font(.caption.bold())
                            Text("\(ad.model) · \(ad.method)").font(.caption2).foregroundColor(theme.textSecondary)
                            Text(ad.path).font(.caption2).foregroundColor(theme.textTertiary).lineLimit(1)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            pendingDelete = ad
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.contentBg)
        .confirmationDialog("删除适配器 \(pendingDelete?.name ?? "")？此操作不可恢复。",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("删除", role: .destructive) {
                if let ad = pendingDelete { Task { await bridge.deleteAdapter(name: ad.name) } }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }
}

// MARK: - Info

struct TrainerInfoTab: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if bridge.info.isEmpty {
                    EmptyStateView(icon: "info.circle", text: "无环境信息。")
                } else {
                    ForEach(bridge.info.keys.sorted(), id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key).font(.caption.bold()).foregroundColor(theme.textSecondary).frame(width: 160, alignment: .leading)
                            Text(String(describing: bridge.info[key]?.value ?? "")).font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(theme.contentBg)
    }
}

// MARK: - Shared empty state

struct EmptyStateView: View {
    @Environment(\.studioTheme) private var theme
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 36)).foregroundColor(theme.textTertiary)
            Text(text).font(.caption).foregroundColor(theme.textTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.contentBg)
    }
}
