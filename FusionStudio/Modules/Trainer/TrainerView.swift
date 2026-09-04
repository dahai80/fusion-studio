import SwiftUI
import os.log

// Callers: ModuleDetailView (case .trainer → TrainerView()), FusionSidebarView/SidebarSection.trainer.
// Affected API: TrainerView + subviews read TrainerBridge (@EnvironmentObject, injected in FusionStudioApp).
// Data schemas: TrainerRun/TrainerPreset/TrainerDataset/TrainerAdapter/TrainerProgressEvent (System/TrainerBridge.swift).
// User instruction: "continue Task" — fusion-trainer RunManager GUI panel (#175)

private let trainerViewLogger = Logger(subsystem: "com.fusion.studio", category: "TrainerView")

struct TrainerView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: TrainerBridge
    @State private var selectedTab: TrainerTab = .runs

    enum TrainerTab: String, CaseIterable {
        case runs
        case start
        case presets
        case datasets
        case adapters
        case info

        var localizedName: String {
            switch self {
            case .runs:      return I18nManager.shared.t(.tr_tab_runs)
            case .start:     return I18nManager.shared.t(.tr_tab_start)
            case .presets:   return I18nManager.shared.t(.tr_tab_presets)
            case .datasets:  return I18nManager.shared.t(.tr_tab_datasets)
            case .adapters:  return I18nManager.shared.t(.tr_tab_adapters)
            case .info:      return I18nManager.shared.t(.tr_tab_info)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                eyebrow: "Fusion Trainer",
                title: I18nManager.shared.t(.tr_title),
                subtitle: I18nManager.shared.t(.tr_subtitle)
            )

            HStack(spacing: 8) {
                Picker("", selection: $selectedTab) {
                    ForEach(TrainerTab.allCases, id: \.self) { tab in
                        Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button {
                    Task { await refreshAll() }
                } label: {
                    Label(I18nManager.shared.t(.tr_btn_refresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(theme.toolbarBg)

            Divider()

            if let error = bridge.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(error).font(.caption).foregroundColor(theme.textSecondary).lineLimit(2)
                    Spacer()
                    Button(I18nManager.shared.t(.tr_btn_clear)) { bridge.lastError = nil }.buttonStyle(.borderless).controlSize(.small)
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
                EmptyStateView(icon: "tray", text: I18nManager.shared.t(.tr_runs_empty))
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
                                } label: { Label(I18nManager.shared.t(.tr_run_stop), systemImage: "stop.fill") }
                                .buttonStyle(.borderedProminent).tint(theme.accentDestructive).controlSize(.small)
                            }
                        }

                        detailRow(I18nManager.shared.t(.tr_detail_status), run.status)
                        detailRow(I18nManager.shared.t(.tr_detail_progress), String(format: "%.1f%%", run.progress * 100))
                        detailRow(I18nManager.shared.t(.tr_detail_steps), "\(run.current_step) / \(run.total_steps)")
                        if let error = run.error, !error.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(I18nManager.shared.t(.tr_detail_error)).font(.caption.bold()).foregroundColor(.red)
                                Text(error).font(.caption).foregroundColor(.red).padding(8)
                                    .background(theme.accentSoft.opacity(0.3)).cornerRadius(6)
                            }
                        }

                        Divider()
                        Text(I18nManager.shared.t(.tr_detail_realtime)).font(.subheadline.bold())
                        if bridge.progressEvents.isEmpty {
                            Text(I18nManager.shared.t(.tr_detail_wait_events)).font(.caption).foregroundColor(theme.textTertiary)
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
                EmptyStateView(icon: "sidebar.left", text: I18nManager.shared.t(.tr_detail_select_hint))
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
    @State private var publishAdapter: Bool = false
    @State private var hubUrl: String = "http://localhost:11432"
    @State private var hubApiKey: String = ""

    enum TrainerMode: String, CaseIterable {
        case sft
        case rlsl

        var localizedName: String {
            switch self {
            case .sft:  return I18nManager.shared.t(.tr_mode_sft)
            case .rlsl: return I18nManager.shared.t(.tr_mode_rlsl)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(I18nManager.shared.t(.tr_start_label_mode), selection: $mode) {
                    ForEach(TrainerMode.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(.segmented)

                Group {
                    Form {
                        Section(I18nManager.shared.t(.tr_start_section_model)) {
                            TextField(I18nManager.shared.t(.tr_start_label_model), text: $model)
                            TextField(I18nManager.shared.t(.tr_start_label_dataset), text: $dataset)
                            Picker(I18nManager.shared.t(.tr_start_label_preset), selection: $preset) {
                                ForEach(bridge.presets) { p in Text(p.name).tag(p.name) }
                            }
                        }
                        if mode == .rlsl {
                            Section(I18nManager.shared.t(.tr_start_section_rlsl)) {
                                Picker("method", selection: $method) {
                                    ForEach(["dpo", "orpo", "grpo"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        Section(I18nManager.shared.t(.tr_start_section_params)) {
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
                        Section(I18nManager.shared.t(.tr_start_section_publish)) {
                            Toggle(I18nManager.shared.t(.tr_start_label_publish_adapter), isOn: $publishAdapter)
                            if publishAdapter {
                                TextField(I18nManager.shared.t(.tr_start_label_hub_url), text: $hubUrl)
                                SecureField(I18nManager.shared.t(.tr_start_label_hub_api_key), text: $hubApiKey)
                            }
                        }
                    }
                    .frame(maxHeight: 480)
                }
                .background(theme.surfaceSecondary).cornerRadius(8)

                HStack {
                    Spacer()
                    Button {
                        let cfg = buildConfig()
                        if mode == .sft {
                            trainerViewLogger.info("start SFT: model=\(model, privacy: .public) dataset=\(dataset, privacy: .public) publish=\(publishAdapter, privacy: .public)")
                            Task { await bridge.startSft(config: cfg) }
                        } else {
                            trainerViewLogger.info("start RLSL: method=\(method, privacy: .public) model=\(model, privacy: .public) publish=\(publishAdapter, privacy: .public)")
                            Task { await bridge.startRlsl(config: cfg) }
                        }
                    } label: {
                        Label(bridge.isStarting ? I18nManager.shared.t(.tr_start_btn_submitting) : I18nManager.shared.t(.tr_start_btn_start), systemImage: "play.fill")
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
            "publish_adapter": publishAdapter,
            "hub_url": hubUrl,
            "hub_api_key": hubApiKey,
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
                    EmptyStateView(icon: "slider.horizontal.3", text: I18nManager.shared.t(.tr_presets_empty))
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
                EmptyStateView(icon: "doc.text", text: I18nManager.shared.t(.tr_datasets_empty))
            } else {
                List(bridge.datasets) { ds in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ds.name).font(.caption.bold())
                            Text(ds.path).font(.caption2).foregroundColor(theme.textTertiary).lineLimit(1)
                        }
                        Spacer()
                        Text(I18nManager.shared.tf(.tr_datasets_samples, ds.samples)).font(.caption2).foregroundColor(theme.textSecondary)
                        Text(ds.format).font(.caption2).foregroundColor(theme.accentText)
                        Button(I18nManager.shared.t(.tr_datasets_preview)) {
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
                EmptyStateView(icon: "externaldrive.badge.plus", text: I18nManager.shared.t(.tr_adapters_empty))
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
        .confirmationDialog(I18nManager.shared.tf(.tr_adapters_delete_title, pendingDelete?.name ?? ""),
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button(I18nManager.shared.t(.tr_adapters_delete_btn), role: .destructive) {
                if let ad = pendingDelete { Task { await bridge.deleteAdapter(name: ad.name) } }
                pendingDelete = nil
            }
            Button(I18nManager.shared.t(.tr_adapters_cancel), role: .cancel) { pendingDelete = nil }
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
                    EmptyStateView(icon: "info.circle", text: I18nManager.shared.t(.tr_info_empty))
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
