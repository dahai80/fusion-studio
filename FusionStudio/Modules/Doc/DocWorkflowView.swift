// Callers: DocView (case .workflow: DocWorkflowView).
// Affected API: DocBridge fetchWorkflows, runWorkflow, fetchWorkflowRuns, createWorkflow, deleteWorkflow, fetchWorkflowDetail, seedWorkflows, fetchPageWorkflowStatus, fetchPageTransitions, executeTransition.
// Data schemas: DocWorkflow, DocWorkflowRun, DocWorkflowState, DocWorkflowTransition (from DocBridge.swift).
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
    @State private var showCreateSheet = false
    @State private var newWfName = ""
    @State private var newWfDesc = ""
    @State private var newWfYaml = ""
    @State private var transitionPageId = ""
    @State private var pageTransitions: [DocWorkflowTransition] = []
    @State private var pageWfState: DocWorkflowState?

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
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 12) {
                Text("新建工作流").font(.headline)
                TextField("名称", text: $newWfName).textFieldStyle(.roundedBorder)
                TextField("描述", text: $newWfDesc).textFieldStyle(.roundedBorder)
                TextEditor(text: $newWfYaml)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .border(Color.gray.opacity(0.3))
                HStack {
                    Button("取消") { showCreateSheet = false }
                    Button("创建") {
                        guard !newWfName.isEmpty else { return }
                        bridge.createWorkflow(name: newWfName, description: newWfDesc.isEmpty ? nil : newWfDesc, yamlDef: newWfYaml.isEmpty ? nil : newWfYaml) { _ in }
                        newWfName = ""; newWfDesc = ""; newWfYaml = ""
                        showCreateSheet = false
                    }
                    .disabled(newWfName.isEmpty)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
    }

    private var workflowHeader: some View {
        HStack {
            Text("工作流")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
            }
            .help("新建")
            Button(action: { bridge.seedWorkflows { _ in bridge.fetchWorkflows() } }) {
                Image(systemName: "leaf.arrow.circlepath")
            }
            .help("种子工作流")
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
        .contextMenu {
            Button("删除工作流", role: .destructive) {
                bridge.deleteWorkflow(id: wf.id) { _ in }
            }
        }
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

                    Divider()
                    pageTransitionSection
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

    private var pageTransitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("页面状态转换")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.textSecondary)
            HStack {
                TextField("页面 ID", text: $transitionPageId)
                    .textFieldStyle(.roundedBorder)
                Button("查询") {
                    guard !transitionPageId.isEmpty else { return }
                    bridge.fetchPageTransitions(pageId: transitionPageId) { result in
                        if case .success(let ts) = result {
                            DispatchQueue.main.async { self.pageTransitions = ts }
                        }
                    }
                    bridge.fetchPageWorkflowStatus(pageId: transitionPageId) { result in
                        if case .success(let s) = result {
                            DispatchQueue.main.async { self.pageWfState = s }
                        }
                    }
                }
                .disabled(transitionPageId.isEmpty)
            }
            if let st = pageWfState {
                Text("当前状态: \(st.current_state ?? "-")")
                    .font(.caption)
                    .foregroundColor(theme.accent)
            }
            ForEach(pageTransitions, id: \.name) { t in
                HStack {
                    Text(t.name ?? "").font(.caption)
                    Spacer()
                    Text("→ \(t.target_state ?? "")").font(.caption2).foregroundColor(.secondary)
                    Button("执行") {
                        bridge.executeTransition(pageId: transitionPageId, transition: t.name ?? "") { _ in }
                    }
                    .font(.caption2)
                }
            }
        }
    }
}
