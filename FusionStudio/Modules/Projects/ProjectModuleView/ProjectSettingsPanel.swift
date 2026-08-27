import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectSettingsPanel: View {
    let project: FusionProject
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var desc: String
    @State private var selectedAgentId: String?
    @State private var promptMergeMode: PromptMergeMode
    @State private var ragMode: RAGMode
    @State private var ragTopK: Int
    @State private var ragThreshold: Double
    @State private var availableAgents: [AgentMeta] = []
    @State private var isSaving = false

    init(project: FusionProject) {
        self.project = project
        _name = State(initialValue: project.name)
        _desc = State(initialValue: project.description)
        _selectedAgentId = State(initialValue: project.defaultAgentId)
        _promptMergeMode = State(initialValue: project.promptMergeMode)
        _ragMode = State(initialValue: project.ragMode)
        _ragTopK = State(initialValue: project.ragTopK)
        _ragThreshold = State(initialValue: project.ragThreshold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(String(format: i18n.t(.proj_settingsTitleFmt), project.name))
                .font(.system(size: theme.headlineSize, weight: .bold))

            // Basic info
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsBasicInfo))
                    .font(.system(size: theme.textSize, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_settingsNameLabel))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.proj_namePh), text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_settingsDescLabel))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.proj_settingsDescPh), text: $desc)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            // Agent config
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsAgentConfig))
                    .font(.system(size: theme.textSize, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_agentConfigDefault))
                        .font(.system(size: theme.captionSize))
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

                Text(i18n.t(.proj_settingsPromptMerge))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_settingsMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_settingsMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Divider()

            // RAG config
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsRagConfig))
                    .font(.system(size: theme.textSize, weight: .semibold))

                Picker(i18n.t(.proj_ragConfigMode), selection: $ragMode) {
                    Text(i18n.t(.proj_settingsRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_settingsRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_createRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))

                HStack(spacing: theme.spacingM) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_settingsTopK))
                        Picker("", selection: $ragTopK) {
                            ForEach(1...20, id: \.self) { k in
                                Text("\(k)").tag(k)
                            }
                        }
                        .frame(width: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_settingsThreshold))
                        Picker("", selection: $ragThreshold) {
                            ForEach(Array(stride(from: 0.1, through: 0.99, by: 0.05)), id: \.self) { v in
                                Text(String(format: "%.2f", v)).tag(v)
                            }
                        }
                        .frame(width: 80)
                    }
                }
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_settingsSaveBtn)) { saveSettings() }
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 560, height: 620)
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
                    await MainActor.run {
                        availableAgents = items.compactMap { AgentMeta.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadAgents failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectUpdate(projectId: project.id, fields: ["name": name, "description": desc])
                _ = try await ipc.projectAgentSet(projectId: project.id, agentId: selectedAgentId,
                                                    mergeMode: promptMergeMode.rawValue)
                _ = try await ipc.projectRagConfigSet(projectId: project.id, ragMode: ragMode.rawValue,
                                                        ragTopK: ragTopK, ragThreshold: ragThreshold)
                projLog.info("Settings saved for project \(project.id)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("saveSettings failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - GUI-11: Agent Preview Card

