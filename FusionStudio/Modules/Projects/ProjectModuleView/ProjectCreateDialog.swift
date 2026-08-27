import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectCreateDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var instructions = ""
    @State private var ragMode = RAGMode.AUTO
    @State private var promptMergeMode = PromptMergeMode.AGENT_FIRST
    @State private var selectedAgentId: String?
    @State private var availableAgents: [AgentMeta] = []
    @State private var isCreating = false
    @State private var editMode: InstructionEditMode = .markdown

    private let maxChars = 10000

    let onCreated: ([String: Any]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.proj_createTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createNameLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_namePh), text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createDescLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_createDescPh), text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(i18n.t(.proj_createInstructions))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    ForEach(InstructionEditMode.allCases, id: \.self) { mode in
                        Button(action: { editMode = mode }) {
                            Text(mode.localLabel)
                                .font(.system(size: 9, weight: editMode == mode ? .bold : .regular))
                                .foregroundStyle(editMode == mode ? theme.accent : theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(String(format: i18n.t(.proj_createCharCountFmt), instructions.count, maxChars))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(instructions.count > maxChars ? .red : theme.textTertiary)
                }
                TextEditor(text: $instructions)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .frame(height: 80)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                Text(i18n.t(.proj_createInstructionsHint))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textQuaternary)
            }

            // Default Agent
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createDefaultAgent))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Menu {
                    Button(i18n.t(.proj_createNoAgent)) { selectedAgentId = nil }
                    Divider()
                    ForEach(availableAgents) { agent in
                        Button(agent.name) { selectedAgentId = agent.id }
                    }
                    Divider()
                    Button(i18n.t(.proj_createGotoAgentStudio)) { }
                } label: {
                    HStack {
                        Image(systemName: "robot")
                        Text(selectedAgentId.flatMap { id in availableAgents.first(where: { $0.id == id })?.name } ?? i18n.t(.proj_createNoAgentShort))
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: theme.footnoteSize))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                }
                .menuStyle(.borderlessButton)
            }

            // Prompt merge mode
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createPromptMerge))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_createMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_createMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            // RAG Mode
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createRagMode))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $ragMode) {
                    Text(i18n.t(.proj_createRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_createRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_createRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.cancel)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(i18n.t(.proj_createBtn)) { createProject() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 520, height: 600)
        .onAppear { loadAgents() }
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

    private func createProject() {
        isCreating = true
        Task {
            do {
                let result = try await ipc.projectCreate(
                    name: name, description: description,
                    defaultAgentId: selectedAgentId,
                    ragMode: ragMode.rawValue,
                    promptMergeMode: promptMergeMode.rawValue
                )
                projLog.info("Project created: \(name)")
                await MainActor.run { onCreated(result); dismiss() }
            } catch {
                projLog.error("project.create failed: \(error.localizedDescription)")
                await MainActor.run { isCreating = false }
            }
        }
    }
}

