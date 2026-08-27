import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")


struct SpaceAgentPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var agents: [SpaceAgent] = []
    @State private var isLoading = false
    @State private var showEditor = false
    @State private var editAgentId: String?
    @State private var editName = ""
    @State private var editPrompt = ""
    @State private var editPerm = "all_member"
    @State private var editModel = ""
    @State private var isSaving = false
    @State private var searchPublished = ""
    @State private var publishedAgents: [SpaceAgent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_agent_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showEditor = true; editAgentId = nil; editName = ""; editPrompt = ""; editPerm = "all_member"; editModel = "" }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadAgents() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if agents.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_agent_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Button(i18n.t(.cw_agent_add)) {
                        showEditor = true; editAgentId = nil; editName = ""; editPrompt = ""
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(agents) { agent in
                            agentRow(agent)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadAgents() }
        .sheet(isPresented: $showEditor) {
            agentEditorSheet
        }
    }

    private func agentRow(_ agent: SpaceAgent) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    Text(permLabel(agent.permission))
                        .font(.system(size: 9))
                    if !agent.model.isEmpty {
                        Text(agent.model)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(agent.source)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Menu {
                Button(i18n.t(.cw_agent_edit)) {
                    editAgentId = agent.id
                    editName = agent.name
                    editPrompt = agent.systemPrompt
                    editPerm = agent.permission
                    editModel = agent.model
                    showEditor = true
                }
                Button(i18n.t(.cw_agent_copyToProject)) { }
                Divider()
                Button(i18n.t(.cw_agent_remove), role: .destructive) { removeAgent(agent) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private var agentEditorSheet: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(editAgentId == nil ? i18n.t(.cw_agent_addTitle) : i18n.t(.cw_agent_editTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_name)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.cw_agent_namePh), text: $editName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_model)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.cw_agent_modelPh), text: $editModel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_perm)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                Picker("", selection: $editPerm) {
                    Text(i18n.t(.cw_agent_permAll)).tag("all_member")
                    Text(i18n.t(.cw_agent_permAdmin)).tag("admin_only")
                    Text(i18n.t(.cw_agent_permCustom)).tag("custom")
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt").font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextEditor(text: $editPrompt)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
            }

            Spacer(minLength: 0)
            HStack {
                Button(i18n.t(.cancel)) { showEditor = false }
                Spacer()
                Button(i18n.t(.save)) { saveAgent() }
                    .disabled(editName.isEmpty || isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 440)
    }

    private func permLabel(_ perm: String) -> String {
        switch perm {
        case "all_member": return i18n.t(.cw_agent_permAllLabel)
        case "admin_only": return i18n.t(.cw_agent_permAdmin)
        case "custom": return i18n.t(.cw_agent_permCustomLabel)
        default: return perm
        }
    }

    private func saveAgent() {
        isSaving = true
        Task {
            do {
                if let aid = editAgentId {
                    _ = try await ipc.spaceCall(method: "desk.space.agent.update", params: [
                        "space_id": spaceId, "agent_id": aid,
                        "agent_name": editName, "system_prompt": editPrompt,
                        "permission": editPerm, "model": editModel,
                    ])
                } else {
                    _ = try await ipc.spaceAgentAdd(
                        spaceId: spaceId, agentName: editName,
                        systemPrompt: editPrompt, permission: editPerm, model: editModel
                    )
                }
                spaceLog.info("Agent saved: \(editName)")
                await MainActor.run { showEditor = false; isSaving = false }
                loadAgents()
            } catch {
                spaceLog.error("saveAgent failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func removeAgent(_ agent: SpaceAgent) {
        Task {
            do {
                _ = try await ipc.spaceAgentRemove(spaceId: spaceId, agentId: agent.id)
                loadAgents()
            } catch {
                spaceLog.error("removeAgent failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadAgents() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { agents = items.map { SpaceAgent.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("agent.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 6: 快照管理
