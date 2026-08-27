import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 7.4: 工作流协作

struct SpaceWorkflowPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var workflows: [SpaceWorkflow] = []
    @State private var isLoading = false
    @State private var selectedWorkflow: SpaceWorkflow?
    @State private var showCreateDialog = false
    @State private var newWorkflowName = ""
    @State private var newWorkflowDesc = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_wf_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadWorkflows() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if workflows.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_wf_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Button(i18n.t(.cw_wf_create)) { showCreateDialog = true }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(workflows) { wf in
                            workflowRow(wf)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }

            Spacer()
            if let wf = selectedWorkflow {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(String(format: i18n.t(.cw_snap2_dagName), wf.name))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                    WorkflowDagCanvas(nodeCount: wf.nodeCount, status: wf.status)
                        .frame(height: 140)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingM)
            }
        }
        .onAppear { loadWorkflows() }
        .sheet(isPresented: $showCreateDialog) {
            workflowCreateSheet
        }
    }

    private var workflowCreateSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.cw_wf_createTitle))
                .font(.system(size: theme.bodySize, weight: .semibold))
            TextField(i18n.t(.cw_wf_namePh), text: $newWorkflowName)
                .textFieldStyle(.roundedBorder)
            TextField(i18n.t(.cw_wf_descPh), text: $newWorkflowDesc)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(i18n.t(.cancel)) { showCreateDialog = false }
                    .buttonStyle(.bordered)
                Button(i18n.t(.cw_create_btn)) {
                    createWorkflow()
                    showCreateDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newWorkflowName.isEmpty)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
    }

    private func workflowRow(_ wf: SpaceWorkflow) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(wf.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                HStack(spacing: theme.spacingXS) {
                    workflowStatusBadge(wf.status)
                    Text(String(format: i18n.t(.cw_wf_nodeCount), wf.nodeCount))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { selectedWorkflow = wf }) {
                Image(systemName: "eye")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            Button(action: { runWorkflow(wf.id) }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(selectedWorkflow?.id == wf.id ? theme.accent.opacity(0.06) : Color.clear)
        )
    }

    @ViewBuilder
    private func workflowStatusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "running": .green
        case "completed": .blue
        case "failed": .red
        case "idle": Color(theme.textTertiary)
        default: Color(theme.textTertiary)
        }
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(statusLabel(status))
                .font(.system(size: 9))
                .foregroundStyle(color)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "running": return i18n.t(.cw_wf_status_running)
        case "completed": return i18n.t(.cw_wf_status_completed)
        case "failed": return i18n.t(.cw_wf_status_failed)
        case "idle": return i18n.t(.cw_wf_status_idle)
        default: return status
        }
    }

    private func createWorkflow() {
        guard !newWorkflowName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.spaceWorkflowCreate(spaceId: spaceId, name: newWorkflowName)
                spaceLog.info("Workflow created: \(newWorkflowName)")
                newWorkflowName = ""
                newWorkflowDesc = ""
                loadWorkflows()
            } catch {
                spaceLog.error("workflow.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func runWorkflow(_ workflowId: String) {
        Task {
            do {
                _ = try await ipc.spaceWorkflowRun(spaceId: spaceId, workflowId: workflowId)
                spaceLog.info("Workflow started: \(workflowId)")
                loadWorkflows()
            } catch {
                spaceLog.error("workflow.run failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadWorkflows() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceWorkflowList(spaceId: spaceId)
                let items = result["workflows"] as? [[String: Any]] ?? []
                await MainActor.run { workflows = items.map { SpaceWorkflow.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("workflow.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Workflow DAG Canvas (D2 可视化)
