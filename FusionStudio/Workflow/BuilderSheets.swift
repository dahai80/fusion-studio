import SwiftUI
import os.log

// P3 sheet 组装: #432 RunHistorySheet (历史 + 回放 diff) / #433 AIBuildSheet (NL 构图)。

private let sheetsLog = Logger(subsystem: "com.fusion.studio", category: "BuilderSheets")

// MARK: - #432 运行历史 + diff

struct RunHistorySheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let flowStore: WorkflowFlowStore
    let flowId: UUID

    @State private var runs: [WorkflowRunRecord] = []
    @State private var selectedA: WorkflowRunRecord?
    @State private var selectedB: WorkflowRunRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("Run History")
                .font(.system(size: theme.textSize, weight: .semibold))
            if runs.isEmpty {
                Text("No runs recorded yet — run this flow with the local backend, then reopen.")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                HStack(alignment: .top, spacing: theme.spacingM) {
                    // 左列: 最近 20 轮, 点选为 A (基线) / B (对比)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Runs (tap: first=A, second=B)")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                        List(runs) { run in
                            Button {
                                pick(run)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        if selectedA?.id == run.id {
                                            Text("A").font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(theme.accent.opacity(0.2))
                                        }
                                        if selectedB?.id == run.id {
                                            Text("B").font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(theme.accent.opacity(0.2))
                                        }
                                        Text(Self.timeFmt.string(from: Date(timeIntervalSince1970: run.startedAt)))
                                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    }
                                    Text("\(run.ok ? "ok" : "failed") · \(run.nodeStatuses.count) nodes · \(run.summary)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.inset)
                    }
                    .frame(width: 280)
                    // 右列: diff rows
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diff")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                        if let a = selectedA, let b = selectedB {
                            List(RunDiff.compare(a, b), id: \.self) { row in
                                diffRow(row)
                            }
                            .listStyle(.inset)
                        } else {
                            Text("Select two runs to compare.")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Spacer()
                FusionButton("Close", icon: "xmark", style: .secondary, size: .small) { dismiss() }
            }
        }
        .padding(theme.spacingM)
        .frame(width: 640, height: 460)
        .task {
            runs = RunHistoryStore(root: flowStore.root.appendingPathComponent("runs")).history(of: flowId)
            if runs.count >= 2 {
                selectedA = runs[1]
                selectedB = runs[0]
            } else {
                selectedB = runs.first
            }
            sheetsLog.info("history loaded flow=\(flowId.uuidString.prefix(8)) runs=\(runs.count)")
        }
    }

    private func pick(_ run: WorkflowRunRecord) {
        if selectedA == nil || (selectedA?.id == run.id && selectedB != nil) {
            selectedA = run
        } else if selectedB?.id == run.id {
            selectedB = selectedA
            selectedA = run
        } else {
            selectedB = run
        }
        sheetsLog.info("history pick A=\(selectedA?.id ?? "-") B=\(selectedB?.id ?? "-")")
    }

    @ViewBuilder
    private func diffRow(_ row: RunDiff.Row) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tag(row))
                .font(.system(size: 10, weight: .bold))
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(rowTagColor(row))
            switch row {
            case .same(let id, let value), .onlyA(let id, let value), .onlyB(let id, let value):
                Text("\(id): \(value)")
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .lineLimit(2)
            case .changed(let id, let before, let after):
                Text("\(id): \(before) -> \(after)")
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .lineLimit(2)
            }
            Spacer()
        }
        .background(rowBackground(row))
    }

    private func tag(_ row: RunDiff.Row) -> String {
        switch row {
        case .same: return "same"
        case .changed: return "CHG"
        case .onlyA: return "only A"
        case .onlyB: return "only B"
        }
    }

    private func rowTagColor(_ row: RunDiff.Row) -> Color {
        switch row {
        case .same: return theme.textTertiary
        case .changed: return .orange
        case .onlyA, .onlyB: return .indigo
        }
    }

    private func rowBackground(_ row: RunDiff.Row) -> Color {
        if case .same = row { return Color.clear }
        return theme.accent.opacity(0.08)
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()
}

extension RunDiff.Row: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .same(let id, let v): hasher.combine("s\(id)\(v)")
        case .changed(let id, let a, let b): hasher.combine("c\(id)\(a)\(b)")
        case .onlyA(let id, let v): hasher.combine("a\(id)\(v)")
        case .onlyB(let id, let v): hasher.combine("b\(id)\(v)")
        }
    }
}

// MARK: - #433 AI Build (NL → plan → apply)

struct AIBuildSheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var prompt: String
    let infer: NLGraphPlanner.InferFn?
    let onApply: (GraphPlan) -> Void

    @State private var planning = false
    @State private var planPreview: GraphPlan?
    @State private var errorText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("AI Build")
                .font(.system(size: theme.textSize, weight: .semibold))
            Text("Describe the flow in one sentence. The model proposes a graph plan; review before applying.")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            TextField("e.g. Classify a question then route to two answers", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
            if let plan = planPreview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan: \(plan.name) — \(plan.nodes.count) nodes")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                        ForEach(Array(plan.nodes.enumerated()), id: \.offset) { idx, node in
                            Text("[\(idx)] \(node.type)")
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                        }
                        ForEach(plan.edges ?? [], id: \.self) { e in
                            Text("edge \(e.from) -> \(e.to)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }
            if !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                FusionButton("Close", icon: "xmark", style: .secondary, size: .small) { dismiss() }
                FusionButton(planning ? "Planning…" : "Plan", icon: "wand.and.stars", style: .secondary, size: .small, isDisabled: planning || prompt.isEmpty || infer == nil) {
                    Task { await makePlan() }
                }
                FusionButton("Apply", icon: "checkmark", style: .primary, size: .small, isDisabled: planPreview == nil) {
                    if let plan = planPreview {
                        onApply(plan)
                        dismiss()
                    }
                }
            }
            if infer == nil {
                Text("MLX inference unavailable — AI Build needs fusion-mlx running.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingM)
        .frame(width: 480)
    }

    private func makePlan() async {
        planning = true
        errorText = ""
        defer { planning = false }
        do {
            guard let infer else {
                throw WorkflowError.corruptFlowFile("no inference backend")
            }
            let planner = NLGraphPlanner(infer: infer)
            let plan = try await planner.plan(prompt: prompt)
            planPreview = plan
            sheetsLog.info("ai plan ready name=\(plan.name, privacy: .public) nodes=\(plan.nodes.count)")
        } catch {
            errorText = error.localizedDescription
            sheetsLog.error("ai plan failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
