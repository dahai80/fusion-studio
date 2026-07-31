import SwiftUI
import os.log

private let fsbLog = Logger(subsystem: "com.fusion.studio", category: "FSB")

struct FSBWorkspaceView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme

    @State private var workspaces: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showCreateDialog = false
    @State private var newWsName = ""
    @State private var newWsDesc = ""
    @State private var selectedWsId: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            workspaceList
            if let wsId = selectedWsId {
                FSBWorkbenchView(workspaceId: wsId, onBack: { selectedWsId = nil })
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadWorkspaces() }
        .alert("新建工作台", isPresented: $showCreateDialog) {
            TextField("名称", text: $newWsName)
            TextField("描述（可选）", text: $newWsDesc)
            Button("创建") { createWorkspace() }
            Button("取消", role: .cancel) { newWsName = ""; newWsDesc = "" }
        }
    }

    private var workspaceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FSB 工作台")
                    .font(.system(size: theme.textSize, weight: .bold))
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingM)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    ForEach(workspaces.indices, id: \.self) { idx in
                        let ws = workspaces[idx]
                        let wsId = ws["id"] as? String ?? ""
                        let name = ws["name"] as? String ?? "未命名"
                        let desc = ws["description"] as? String ?? ""
                        let status = ws["status"] as? String ?? "active"

                        HStack(spacing: theme.spacingS) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: theme.textSize, weight: .medium))
                                    .foregroundStyle(selectedWsId == wsId ? theme.accent : theme.text)
                                if !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Circle()
                                .fill(status == "active" ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, theme.spacingXS)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedWsId = wsId }
                        .contextMenu {
                            Button("删除") { deleteWorkspace(wsId) }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 260)
        .background(theme.surfaceSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "storefront")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("选择或创建一个工作台")
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadWorkspaces() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.call(method: "fsb.workspace_list", params: [:])
                if let items = result["workspaces"] as? [[String: Any]] {
                    await MainActor.run { workspaces = items }
                }
            } catch {
                fsbLog.error("workspace_list failed: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func createWorkspace() {
        guard !newWsName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.call(method: "fsb.workspace_create", params: [
                    "name": newWsName,
                    "description": newWsDesc,
                ])
                await MainActor.run { newWsName = ""; newWsDesc = "" }
                fsbLog.info("workspace created")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace_create failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteWorkspace(_ wsId: String) {
        Task {
            do {
                _ = try await ipc.call(method: "fsb.workspace_delete", params: ["workspace_id": wsId])
                fsbLog.info("workspace \(wsId) deleted")
                if selectedWsId == wsId { selectedWsId = nil }
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace_delete failed: \(error.localizedDescription)")
            }
        }
    }
}

struct FSBWorkbenchView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let workspaceId: String
    let onBack: () -> Void

    @State private var workflows: [[String: Any]] = []
    @State private var selectedWfId: String? = nil
    @State private var showWorkflowEditor = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("工作台")
                    .font(.system(size: theme.textSize, weight: .semibold))
                Spacer()
                Button(action: { showWorkflowEditor = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("新建工作流")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(theme.spacingM)

            if workflows.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "flowchart")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无工作流")
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(workflows.indices, id: \.self) { idx in
                        let wf = workflows[idx]
                        let wfId = wf["id"] as? String ?? ""
                        let name = wf["name"] as? String ?? "未命名"
                        let status = wf["status"] as? String ?? "draft"

                        HStack {
                            Image(systemName: "flowchart")
                                .foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: theme.textSize, weight: .medium))
                                Text(status)
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            Button(action: { selectedWfId = wfId; showWorkflowEditor = true }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, theme.spacingXS)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadWorkflows() }
        .sheet(isPresented: $showWorkflowEditor) {
            if let wfId = selectedWfId {
                FSBWorkflowEditorView(workspaceId: workspaceId, workflowId: wfId)
            } else {
                FSBWorkflowEditorView(workspaceId: workspaceId, workflowId: nil)
            }
        }
    }

    private func loadWorkflows() {
        Task {
            do {
                let result = try await ipc.call(method: "fsb.workflow_list", params: ["workspace_id": workspaceId])
                if let items = result["workflows"] as? [[String: Any]] {
                    await MainActor.run { workflows = items }
                }
            } catch {
                fsbLog.error("workflow_list failed: \(error.localizedDescription)")
            }
        }
    }
}

struct FSBWorkflowEditorView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let workspaceId: String
    let workflowId: String?

    @State private var nodes: [[String: Any]] = []
    @State private var edges: [[String: Any]] = []
    @State private var selectedNodeId: String? = nil
    @State private var isSaving = false

    private let nodeTypes = [
        ("connector", "连接器", "plug"),
        ("skill", "技能", "star"),
        ("condition", "条件", "arrow.triangle.branch"),
        ("approval", "审批", "checkmark.shield"),
        ("output", "输出", "arrow.up.doc"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            nodePalette
            canvasArea
            if let nodeId = selectedNodeId {
                nodePropertyPanel(nodeId: nodeId)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear { loadWorkflow() }
    }

    private var nodePalette: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("节点")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
            ForEach(nodeTypes, id: \.0) { type in
                HStack(spacing: theme.spacingS) {
                    Image(systemName: type.2)
                        .frame(width: 16)
                    Text(type.1)
                        .font(.system(size: theme.footnoteSize))
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
                .onTapGesture { addNode(type: type.0, name: type.1) }
            }
            Spacer()
        }
        .padding(theme.spacingM)
        .frame(width: 160)
        .background(theme.inputBg)
    }

    private var canvasArea: some View {
        VStack(spacing: 0) {
            HStack {
                Text(workflowId == nil ? "新建工作流" : "编辑工作流")
                    .font(.system(size: theme.textSize, weight: .semibold))
                Spacer()
                Button(action: validateAndSave) {
                    HStack(spacing: 4) {
                        if isSaving { ProgressView().controlSize(.small) }
                        Text("保存")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSaving)
                .help("保存并校验（DAG 环检测）")
                Button("关闭") { dismiss() }
                    .controlSize(.small)
            }
            .padding(theme.spacingS)

            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .fill(theme.surfaceSecondary)
                        .frame(minWidth: 600, minHeight: 400)
                    ForEach(nodes.indices, id: \.self) { idx in
                        let node = nodes[idx]
                        let nodeId = node["id"] as? String ?? ""
                        let name = node["name"] as? String ?? ""
                        let x = node["x"] as? Double ?? 0
                        let y = node["y"] as? Double ?? 0

                        workflowNodeCard(id: nodeId, name: name, x: x, y: y)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func workflowNodeCard(id: String, name: String, x: Double, y: Double) -> some View {
        VStack(spacing: theme.spacingXS) {
            Text(name)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(selectedNodeId == id ? theme.accentText : theme.text)
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(selectedNodeId == id ? theme.accent : theme.inputBg)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
        .offset(x: x, y: y)
        .onTapGesture { selectedNodeId = id }
    }

    private func nodePropertyPanel(nodeId: String) -> some View {
        let node = nodes.first { ($0["id"] as? String) == nodeId } ?? [:]
        let name = node["name"] as? String ?? ""
        let type = node["type"] as? String ?? ""

        return VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("节点属性")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
            HStack {
                Text("名称:")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Text(name)
                    .font(.system(size: theme.footnoteSize))
            }
            HStack {
                Text("类型:")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Text(type)
                    .font(.system(size: theme.footnoteSize))
            }
            Spacer()
            Button("删除节点") {
                nodes.removeAll { ($0["id"] as? String) == nodeId }
                selectedNodeId = nil
            }
            .foregroundStyle(.red)
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
        .frame(width: 200)
        .background(theme.inputBg)
    }

    private func loadWorkflow() {
        guard let wfId = workflowId else { return }
        Task {
            do {
                let result = try await ipc.call(method: "fsb.workflow_get", params: [
                    "workspace_id": workspaceId,
                    "workflow_id": wfId,
                ])
                if let n = result["nodes"] as? [[String: Any]] {
                    await MainActor.run { nodes = n }
                }
                if let e = result["edges"] as? [[String: Any]] {
                    await MainActor.run { edges = e }
                }
            } catch {
                fsbLog.error("workflow_get failed: \(error.localizedDescription)")
            }
        }
    }

    private func addNode(type: String, name: String) {
        let id = "node_\(UUID().uuidString.prefix(8))"
        let offsetX = Double(nodes.count) * 120 + 50
        let newNode: [String: Any] = [
            "id": id,
            "type": type,
            "name": name,
            "x": offsetX,
            "y": 100,
        ]
        nodes.append(newNode)
        fsbLog.info("added node \(id) type=\(type)")
    }

    private func validateAndSave() {
        isSaving = true
        Task {
            do {
                var params: [String: Any] = [
                    "workspace_id": workspaceId,
                    "nodes": nodes,
                    "edges": edges,
                ]
                if let wfId = workflowId {
                    params["workflow_id"] = wfId
                }
                let result = try await ipc.call(method: "fsb.workflow_save", params: params)
                if let errors = result["validation_errors"] as? [[String: Any]], !errors.isEmpty {
                    fsbLog.warning("workflow validation errors: \(errors.count)")
                } else {
                    fsbLog.info("workflow saved successfully")
                    await MainActor.run { dismiss() }
                }
            } catch {
                fsbLog.error("workflow_save failed: \(error.localizedDescription)")
            }
            await MainActor.run { isSaving = false }
        }
    }
}
