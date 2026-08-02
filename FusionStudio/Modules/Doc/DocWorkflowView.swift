// Callers: DocView toolbar button, DocSidebar workflow tab.
// Affected API: DocBridge fetchWorkflows, runWorkflow, fetchWorkflowRuns.
// Data schemas: DocWorkflow, DocWorkflowRun (from DocBridge.swift).
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let workflowLog = Logger(subsystem: "com.fusion.studio", category: "DocWorkflow")

struct DocWorkflowView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var selectedWorkflow: DocWorkflow?
    @State private var runs: [DocWorkflowRun] = []
    @State private var runInput = ""

    var body: some View {
        VStack(spacing: 0) {
            workflowHeader
            Divider()
            HSplitView {
                workflowList
                    .frame(minWidth: 200, maxWidth: 300)
                workflowDetail
                    .frame(minWidth: 300)
            }
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.fetchWorkflows()
        }
    }

    private var workflowHeader: some View {
        HStack {
            Text("工作流")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { bridge.fetchWorkflows() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var workflowList: some View {
        List(selection: $selectedWorkflow) {
            if bridge.workflows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无工作流")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(bridge.workflows) { wf in
                    workflowRow(wf)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func workflowRow(_ wf: DocWorkflow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: workflowIcon(wf.name))
                    .foregroundColor(theme.accent)
                    .font(.caption)
                Text(wf.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            if let desc = wf.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .tag(wf)
    }

    private var workflowDetail: some View {
        Group {
            if let wf = selectedWorkflow {
                VStack(alignment: .leading, spacing: 12) {
                    Text(wf.name)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)

                    if let desc = wf.description {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(theme.textSecondary)
                    }

                    if let yaml = wf.yaml_def {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YAML 定义")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(theme.textSecondary)
                            ScrollView {
                                Text(yaml)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(theme.surfaceSecondary)
                                    .cornerRadius(6)
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("运行输入")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textSecondary)
                        TextEditor(text: $runInput)
                            .font(.system(.caption, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(height: 80)
                            .padding(4)
                            .background(theme.surfaceSecondary)
                            .cornerRadius(6)
                    }

                    Button(action: { runWorkflow(wf) }) {
                        Label("执行工作流", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    if !runs.isEmpty {
                        Divider()
                        Text("运行记录")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textSecondary)
                        List(runs) { run in
                            HStack {
                                runStatusIcon(run.status)
                                Text(run.started_at ?? "")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Text(run.status ?? "")
                                    .font(.caption2)
                                    .foregroundColor(run.status == "completed" ? Color.green : Color.orange)
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 150)
                    }

                    Spacer()
                }
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("选择工作流查看详情")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func workflowIcon(_ name: String) -> String {
        if name.contains("报告") { return "doc.text.fill" }
        if name.contains("翻译") { return "globe" }
        if name.contains("知识") { return "brain" }
        if name.contains("周报") { return "calendar" }
        if name.contains("论文") { return "book.fill" }
        return "gearshape"
    }

    private func runStatusIcon(_ status: String?) -> some View {
        switch status {
        case "completed":
            return Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case "failed":
            return Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case "running":
            return Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.orange)
        default:
            return Image(systemName: "circle").foregroundColor(.secondary)
        }
    }

    private func runWorkflow(_ wf: DocWorkflow) {
        var input: [String: Any]? = nil
        if !runInput.isEmpty {
            input = ["text": runInput]
        }
        bridge.runWorkflow(id: wf.id, input: input)
        workflowLog.info("Workflow started: \(wf.id)")

        bridge.fetchWorkflowRuns(id: wf.id) { result in
            if case .success(let data) = result {
                DispatchQueue.main.async { self.runs = data }
            }
        }
    }
}
