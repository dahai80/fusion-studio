import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct AgentConfigSheet: View {
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAgentId: String?
    @State private var availableAgents: [AgentMeta] = []
    @State private var promptMergeMode: PromptMergeMode = .AGENT_FIRST
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(i18n.t(.proj_agentConfigTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_agentConfigDefault))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Menu {
                    Button(i18n.t(.proj_createNoAgent)) { selectedAgentId = nil }
                    Divider()
                    ForEach(availableAgents) { agent in
                        Button(agent.name) { selectedAgentId = agent.id }
                    }
                } label: {
                    HStack {
                        Text(agentDisplayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: theme.footnoteSize))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                }
                .menuStyle(.borderlessButton)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_agentConfigPromptMerge))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_createMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_createMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Button(i18n.t(.save)) { saveConfig() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 360)
        .onAppear { loadAgents() }
    }

    private var agentDisplayName: String {
        selectedAgentId.flatMap { id in availableAgents.first(where: { $0.id == id })?.name } ?? i18n.t(.proj_createNoAgentShort)
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.projectAgentList()
                if let items = result["agents"] as? [[String: Any]] ?? result["items"] as? [[String: Any]] {
                    await MainActor.run { availableAgents = items.compactMap { AgentMeta.fromDict($0) } }
                }
            } catch {
                projLog.error("AgentConfigSheet loadAgents failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveConfig() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectAgentSet(projectId: projectId, agentId: selectedAgentId,
                                                   mergeMode: promptMergeMode.rawValue)
                projLog.info("AgentConfig saved for project \(projectId)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("AgentConfig save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - FS-3: RAG Config Sheet

