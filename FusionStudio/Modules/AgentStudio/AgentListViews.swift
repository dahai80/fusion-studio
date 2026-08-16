import SwiftUI
import Combine
import os.log

// MARK: - AgentListView

struct AgentListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @EnvironmentObject private var bridge: AgentBridge
    @State private var selectedAgent: Agent?
    @State private var selectedBackendAgent: AgentModel?
    @State private var showCreateAgent = false
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        GeometryReader { geo in
            HSplitView {
                agentListPanel
                    .frame(minWidth: 200, idealWidth: max(200, geo.size.width * 0.2), maxWidth: 360)

                Group {
                    if let backendAgent = selectedBackendAgent {
                        BackendAgentDetailView(agent: backendAgent, toastManager: toastManager)
                            .onAppear { bridge.currentAgent = backendAgent }
                    } else if let agent = selectedAgent {
                        AgentDetailView(agent: agent, toastManager: toastManager)
                            .onAppear { bridge.currentAgent = nil }
                    } else {
                        emptyDetailPlaceholder
                    }
                }
                .frame(minWidth: 400, idealWidth: geo.size.width * 0.8)
            }
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Create Agent", icon: "plus", style: .primary, size: .small) {
                    showCreateAgent = true
                }
            }
        }
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soul, memory, agentsMd, graphId in
                createAndSync(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, soul: soul, memory: memory, agentsMd: agentsMd)
            }
        }
    }

    private func createAndSync(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String], soul: String, memory: String, agentsMd: String) {
        orchestrator.createAgent(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
        toastManager.show(style: .success, title: "Agent Created", message: "\(name) is ready")
        Task {
            do {
                let _ = try await bridge.agentCreate(
                    name: name,
                    model: model.isEmpty ? type.defaultModel : model,
                    systemPrompt: systemPrompt.isEmpty ? type.defaultSystemPrompt : systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    tools: tools,
                    capabilities: capabilities,
                    safetyLevel: safetyLevel,
                    tags: tags,
                    soul: soul,
                    memory: memory,
                    agentsMd: agentsMd
                )
                try await bridge.fetchAgents()
            } catch {
                agentStudioLog.error("Backend sync failed for agent \(name): \(error)")
            }
        }
    }

    private var agentListPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                StudioSectionHeader(title: "Backend Agents")
                if bridge.agents.isEmpty {
                    Text("No backend agents — create one")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                } else {
                    ListGroup {
                        ForEach(Array(bridge.agents.enumerated()), id: \.element.id) { index, agent in
                            StudioRow(label: agent.name, sublabel: agent.model, isLast: index == bridge.agents.count - 1) {
                                HStack(spacing: theme.spacingS) {
                                    if let status = agent.status {
                                        FusionTag(status, color: statusColor(for: status))
                                    }
                                    FusionTag(agent.safety_level, color: .blue)
                                    if agent.has_soul {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: theme.iconXS))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedBackendAgent = agent
                                selectedAgent = nil
                                agentStudioLog.info("Selected backend agent: \(agent.name)")
                            }
                            .contextMenu {
                                if agent.status != "published" {
                                    Button {
                                        Task { await publishBackendAgent(agent) }
                                    } label: {
                                        Label("Publish", systemImage: "arrow.up.circle")
                                    }
                                }
                                if agent.status == "published" {
                                    Button {
                                        Task { await archiveBackendAgent(agent) }
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                                Button {
                                    Task { await cloneBackendAgent(agent) }
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    deleteBackendAgent(agent)
                                }
                            }
                        }
                    }
                }

                StudioSectionHeader(title: "Built-in Agents")
                ListGroup {
                    ForEach(Array(orchestrator.agents.filter { $0.isBuiltin }.enumerated()), id: \.element.id) { index, agent in
                        StudioRow(label: agent.name, sublabel: agent.model, isLast: index == orchestrator.agents.filter { $0.isBuiltin }.count - 1) {
                            agentRowTrailing(agent: agent)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAgent = agent
                            selectedBackendAgent = nil
                            agentStudioLog.info("Selected built-in agent: \(agent.name)")
                        }
                    }
                }

                StudioSectionHeader(title: "Custom Agents (local)")
                let customAgents = orchestrator.agents.filter { !$0.isBuiltin }
                if customAgents.isEmpty {
                    Text("No custom agents yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                } else {
                    ListGroup {
                        ForEach(Array(customAgents.enumerated()), id: \.element.id) { index, agent in
                            StudioRow(label: agent.name, sublabel: agent.model, isLast: index == customAgents.count - 1) {
                                agentRowTrailing(agent: agent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAgent = agent
                                selectedBackendAgent = nil
                                agentStudioLog.info("Selected custom agent: \(agent.name)")
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    orchestrator.deleteAgent(agent.id)
                                    if selectedAgent?.id == agent.id { selectedAgent = nil }
                                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func deleteBackendAgent(_ agent: AgentModel) {
        Task {
            do {
                let deleted = try await bridge.agentDelete(agentId: agent.id)
                if deleted {
                    if selectedBackendAgent?.id == agent.id { selectedBackendAgent = nil }
                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed from backend")
                }
            } catch {
                toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
            }
        }
    }

    private func publishBackendAgent(_ agent: AgentModel) async {
        do {
            let updated = try await bridge.agentPublish(agentId: agent.id)
            toastManager.show(style: .success, title: "Published", message: "\(updated.name) is now live")
        } catch {
            toastManager.show(style: .error, title: "Publish Failed", message: error.localizedDescription)
        }
    }

    private func archiveBackendAgent(_ agent: AgentModel) async {
        do {
            let updated = try await bridge.agentArchive(agentId: agent.id)
            toastManager.show(style: .info, title: "Archived", message: "\(updated.name) archived")
        } catch {
            toastManager.show(style: .error, title: "Archive Failed", message: error.localizedDescription)
        }
    }

    private func cloneBackendAgent(_ agent: AgentModel) async {
        do {
            let cloned = try await bridge.agentClone(agentId: agent.id)
            toastManager.show(style: .success, title: "Cloned", message: "\(cloned.name) created")
        } catch {
            toastManager.show(style: .error, title: "Clone Failed", message: error.localizedDescription)
        }
    }

    private func statusColor(for status: String) -> TagColor {
        switch status {
        case "draft": return .gray
        case "published": return .green
        case "archived": return .orange
        default: return .gray
        }
    }

    private func agentRowTrailing(agent: Agent) -> some View {
        HStack(spacing: theme.spacingS) {
            FusionTag(agent.type.rawValue, icon: agent.type.icon, color: agent.type.tagColor)
            StatusPill(status: agent.status.pillStatus, compact: true)
            Text("\(agent.taskCount)")
                .font(.system(size: theme.captionSize, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Select an agent to view details")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BackendAgentDetailView

struct BackendAgentDetailView: View {
    let agent: AgentModel
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @State private var taskInput = ""
    @State private var isExecuting = false
    @State private var executionResult: String = ""
    @State private var showConfigure = false
    @State private var editTemperature: Double = 0.7
    @State private var editMaxTokens: Int = 4096
    @State private var editSafetyLevel: String = "L1"
    @State private var editModel: String = ""
    @State private var newSkillName = ""
    @State private var showSoulEditor = false
    @State private var editSoulContent = ""
    @State private var showEditAgent = false
    @State private var versions: [[String: Any]] = []
    @State private var isLoadingVersions = false

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                headerSection

                FusionCard(style: .inset, header: "Configuration", headerIcon: "gearshape") {
                    VStack(spacing: 0) {
                        infoRow(label: "Model", value: agent.model, isLast: false)
                        infoRow(label: "Temperature", value: String(format: "%.1f", agent.temperature), isLast: false)
                        infoRow(label: "Max Tokens", value: "\(agent.max_tokens)", isLast: false)
                        infoRow(label: "Safety Level", value: agent.safety_level, isLast: false)
                        infoRow(label: "Tools", value: agent.tools.joined(separator: ", "), isLast: false)
                        infoRow(label: "Capabilities", value: agent.capabilities.joined(separator: ", "), isLast: false)
                        infoRow(label: "Tags", value: agent.tags.joined(separator: ", "), isLast: true)
                    }
                }

                skillsSection

                soulSection

                versionHistorySection

                FusionCard(style: .inset, header: "System Prompt", headerIcon: "text.bubble") {
                    Text(agent.system_prompt)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                }

                FusionCard(style: .inset, header: "Execute", headerIcon: "play.fill") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        HStack(spacing: theme.spacingS) {
                            TextField("Enter task for this agent...", text: $taskInput)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }

                            FusionButton("Run", icon: "play.fill", style: .primary, size: .small, isDisabled: taskInput.isEmpty || isExecuting) {
                                executeAgent()
                            }
                            if isExecuting {
                                FusionButton("Cancel", icon: "stop.fill", style: .destructive, size: .small) {
                                    bridge.cancelExecution()
                                    isExecuting = false
                                }
                            }
                        }

                        if !executionResult.isEmpty {
                            Text(executionResult)
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .padding(theme.spacingS)
                                .background(theme.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Snapshot", icon: "camera", style: .secondary, size: .small) {
                        takeSnapshot()
                    }
                    FusionButton("Duplicate", icon: "doc.on.doc", style: .secondary, size: .small) {
                        duplicateAgent()
                    }
                    FusionButton("Configure", icon: "slider.horizontal.3", style: .secondary, size: .small) {
                        editTemperature = agent.temperature
                        editMaxTokens = agent.max_tokens
                        editSafetyLevel = agent.safety_level
                        editModel = agent.model
                        showConfigure = true
                    }
                    FusionButton("Edit", icon: "pencil.line", style: .primary, size: .small) {
                        showEditAgent = true
                    }
                    FusionButton("Delete Agent", icon: "trash", style: .destructive, size: .small) {
                        deleteAgent()
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingS)

                Spacer(minLength: theme.spacing2XL)
            }
            .padding(.vertical, theme.spacingL)
        }
        .sheet(isPresented: $showConfigure) {
            ConfigureAgentSheet(
                agent: agent,
                temperature: $editTemperature,
                maxTokens: $editMaxTokens,
                safetyLevel: $editSafetyLevel,
                model: $editModel,
                onSave: { saveConfig() },
                toastManager: toastManager
            )
        }
        .sheet(isPresented: $showSoulEditor) {
            SoulEditorSheet(soulContent: $editSoulContent, onSave: {
                saveSoul()
            }, toastManager: toastManager)
        }
        .sheet(isPresented: $showEditAgent) {
            EditAgentSheet(agent: agent) { name, desc, model, prompt, temp, maxTok, tools, caps, tags, safety in
                editAgent(name: name, description: desc, model: model, systemPrompt: prompt, temperature: temp, maxTokens: maxTok, tools: tools, capabilities: caps, tags: tags, safetyLevel: safety)
            }
        }
        .onAppear {
            loadSkillsAndSoul()
        }
    }

    private var skillsSection: some View {
        FusionCard(style: .inset, header: "Skills (\(bridge.agentSkills.count))", headerIcon: "sparkles") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                if bridge.agentSkills.isEmpty {
                    Text("No skills assigned")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(bridge.agentSkills, id: \.self) { skill in
                            HStack(spacing: theme.spacingXS) {
                                Text(skill)
                                    .font(.system(size: theme.captionSize, weight: .medium))
                                    .foregroundStyle(theme.text)
                                Button(action: { deleteSkill(skill) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, theme.spacingS)
                            .padding(.vertical, theme.spacingXS)
                            .background(theme.accentSoft)
                            .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: theme.spacingS) {
                    TextField("New skill name", text: $newSkillName)
                        .textFieldStyle(.plain)
                        .padding(theme.spacingXS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                    FusionButton("Add", icon: "plus", style: .secondary, size: .small, isDisabled: newSkillName.isEmpty) {
                        addSkill()
                    }
                }
            }
        }
    }

    private var soulSection: some View {
        FusionCard(style: .inset, header: "Soul", headerIcon: "heart.fill") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                if bridge.agentSoul.isEmpty {
                    Text("No soul defined")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    Text(bridge.agentSoul)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
                FusionButton("Edit Soul", icon: "pencil", style: .secondary, size: .small) {
                    editSoulContent = bridge.agentSoul
                    showSoulEditor = true
                }
            }
        }
    }

    private var versionHistorySection: some View {
        FusionCard(style: .inset, header: "Version History", headerIcon: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                if isLoadingVersions {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if versions.isEmpty {
                    Text("No snapshots yet. Click Snapshot to create one.")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(Array(versions.prefix(10).enumerated()), id: \.offset) { idx, ver in
                        let verId = ver["version_id"] as? String ?? ver["id"] as? String ?? ""
                        let createdAt = ver["created_at"] as? String ?? "Unknown"
                        let label = ver["label"] as? String ?? "v\(versions.count - idx)"
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(theme.textTertiary)
                            Text(label)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            Text(createdAt)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                            Spacer()
                            FusionButton("Restore", icon: "arrow.uturn.backward", style: .secondary, size: .small) {
                                restoreVersion(verId)
                            }
                        }
                        .padding(theme.spacingS)
                        .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                    }
                }
                FusionButton("Refresh", icon: "arrow.clockwise", style: .secondary, size: .small) {
                    loadVersions()
                }
            }
        }
    }

    private func loadSkillsAndSoul() {
        Task {
            do {
                _ = try await bridge.fetchAgentSkills(agentId: agent.id)
                _ = try await bridge.fetchAgentSoul(agentId: agent.id)
            } catch {
                agentStudioLog.warning("Failed to load skills/soul: \(error)")
            }
        }
    }

    private func addSkill() {
        guard !newSkillName.isEmpty else { return }
        let name = newSkillName
        newSkillName = ""
        Task {
            do {
                let ok = try await bridge.agentAddSkill(agentId: agent.id, skillName: name)
                if ok {
                    toastManager.show(style: .success, title: "Skill Added", message: name)
                }
            } catch {
                toastManager.show(style: .error, title: "Add Skill Failed", message: error.localizedDescription)
            }
        }
    }

    private func deleteSkill(_ skill: String) {
        Task {
            do {
                let ok = try await bridge.agentDeleteSkill(agentId: agent.id, skillName: skill)
                if ok {
                    toastManager.show(style: .info, title: "Skill Removed", message: skill)
                }
            } catch {
                toastManager.show(style: .error, title: "Remove Skill Failed", message: error.localizedDescription)
            }
        }
    }

    private func saveSoul() {
        Task {
            do {
                let ok = try await bridge.agentUpdateSoul(agentId: agent.id, soul: editSoulContent)
                if ok {
                    showSoulEditor = false
                    toastManager.show(style: .success, title: "Soul Updated", message: "Agent soul saved")
                }
            } catch {
                toastManager.show(style: .error, title: "Soul Update Failed", message: error.localizedDescription)
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "brain")
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(agent.name)
                    .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                FusionTag(agent.safety_level, color: .blue)
            }
            Spacer()
            if isExecuting {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func infoRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.text)
            Spacer()
        }
        .padding(.vertical, theme.spacingXS)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(theme.rowSep)
                    .frame(height: 0.5)
            }
        }
    }

    private func executeAgent() {
        guard !taskInput.isEmpty else { return }
        isExecuting = true
        executionResult = ""
        Task {
            do {
                let result = try await bridge.agentExecute(agentId: agent.id, input: taskInput)
                isExecuting = false
                if let status = result["status"] as? String, status == "error" {
                    executionResult = "Error: \(result["message"] as? String ?? "unknown")"
                } else {
                    let output = result["output"] as? String ?? result["content"] as? String ?? "Completed"
                    executionResult = output
                }
                toastManager.show(style: .success, title: "Execution Complete", message: "Agent \(agent.name) finished")
            } catch {
                isExecuting = false
                executionResult = "Error: \(error.localizedDescription)"
                toastManager.show(style: .error, title: "Execution Failed", message: error.localizedDescription)
            }
        }
    }

    private func deleteAgent() {
        Task {
            do {
                let deleted = try await bridge.agentDelete(agentId: agent.id)
                if deleted {
                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                }
            } catch {
                toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
            }
        }
    }

    private func duplicateAgent() {
        Task {
            do {
                let cloned = try await bridge.agentClone(agentId: agent.id)
                toastManager.show(style: .success, title: "Duplicated", message: "\(cloned.name) created from \(agent.name)")
                try await bridge.fetchAgents()
            } catch {
                toastManager.show(style: .error, title: "Duplicate Failed", message: error.localizedDescription)
            }
        }
    }

    private func takeSnapshot() {
        Task {
            do {
                _ = try await bridge.agentSnapshot(agentId: agent.id)
                toastManager.show(style: .success, title: "Snapshot Created", message: "\(agent.name) version saved")
                loadVersions()
            } catch {
                toastManager.show(style: .error, title: "Snapshot Failed", message: error.localizedDescription)
            }
        }
    }

    private func loadVersions() {
        isLoadingVersions = true
        Task {
            do {
                versions = try await bridge.agentVersions(agentId: agent.id)
            } catch {
                agentStudioLog.warning("Failed to load versions: \(error)")
            }
            isLoadingVersions = false
        }
    }

    private func restoreVersion(_ versionId: String) {
        Task {
            do {
                _ = try await bridge.agentRestoreVersion(agentId: agent.id, versionId: versionId)
                toastManager.show(style: .success, title: "Restored", message: "\(agent.name) restored to selected version")
                try await bridge.fetchAgents()
            } catch {
                toastManager.show(style: .error, title: "Restore Failed", message: error.localizedDescription)
            }
        }
    }

    private func saveConfig() {
        Task {
            do {
                let _ = try await bridge.agentConfigure(agentId: agent.id, config: [
                    "temperature": editTemperature,
                    "max_tokens": editMaxTokens,
                    "safety_level": editSafetyLevel,
                    "model": editModel,
                ])
                try await bridge.fetchAgents()
                showConfigure = false
                toastManager.show(style: .success, title: "Configuration Saved", message: "\(agent.name) updated")
            } catch {
                toastManager.show(style: .error, title: "Save Failed", message: error.localizedDescription)
            }
        }
    }

    private func editAgent(name: String, description: String, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], tags: [String], safetyLevel: String) {
        agentStudioLog.info("editAgent: id=\(agent.id) name=\(name) model=\(model) tools=\(tools.count)")
        Task {
            do {
                _ = try await bridge.agentUpdate(
                    agentId: agent.id,
                    name: name,
                    model: model,
                    systemPrompt: systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    tools: tools,
                    capabilities: capabilities,
                    safetyLevel: safetyLevel,
                    tags: tags,
                    description: description
                )
                try await bridge.fetchAgents()
                toastManager.show(style: .success, title: "Agent Updated", message: "\(name) saved")
            } catch {
                agentStudioLog.error("editAgent id=\(agent.id) failed: \(error.localizedDescription)")
                toastManager.show(style: .error, title: "Update Failed", message: error.localizedDescription)
            }
        }
    }
}
