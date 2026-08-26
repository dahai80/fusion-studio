import SwiftUI
import Combine
import os.log

// MARK: - ConfigureAgentSheet

struct ConfigureAgentSheet: View {
    let agent: AgentModel
    @Binding var temperature: Double
    @Binding var maxTokens: Int
    @Binding var safetyLevel: String
    @Binding var model: String
    let onSave: () -> Void
    let toastManager: FusionToastManager

    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var bridge: AgentBridge
    @State private var selectedConfigTab: Int = 0

    private let safetyLevels = ["L1", "L2", "L3"]
    private let safetyExplanations: [String: String] = [
        "L1": "Autonomous - agent acts silently, no approval needed.",
        "L2": "Preview - agent shows a diff/plan and waits for your confirm before executing.",
        "L3": "Gateway - agent must get explicit approval before every action."
    ]

    private var availableModels: [MLXModelInfo] {
        let chat = bridge.mlxState.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.mlxState.models : chat
    }

    var body: some View {
        VStack(spacing: theme.spacingL) {
            HStack {
                Text("Configure Agent")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                Text(agent.name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }

            FusionTabBar(selected: $selectedConfigTab, tabs: [
                FusionTabItem(title: "Basic", icon: "info.circle", badge: nil),
                FusionTabItem(title: "Model", icon: "cpu", badge: nil),
                FusionTabItem(title: "Tools", icon: "wrench", badge: nil),
                FusionTabItem(title: "KB", icon: "doc.text.magnifyingglass", badge: nil),
                FusionTabItem(title: "Connectors", icon: "link", badge: nil),
                FusionTabItem(title: "Style", icon: "paintbrush", badge: nil),
            ])

            Group {
                switch selectedConfigTab {
                case 0: configBasicTab
                case 1: configModelTab
                case 2: configToolsTab
                case 3: configKBTab
                case 4: configConnectorsTab
                case 5: configStyleTab
                default: configBasicTab
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: theme.spacingM) {
                FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                FusionButton("Save", icon: "checkmark", style: .primary, size: .regular) {
                    onSave()
                }
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 520, height: 560)
        .background(theme.windowBg)
    }

    private var configBasicTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Name")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(agent.name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Description")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(agent.system_prompt.prefix(200))
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(3)
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Tags")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(agent.tags, id: \.self) { tag in
                            FusionTag(tag, color: .blue)
                        }
                        if agent.tags.isEmpty {
                            Text("No tags")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Visibility")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(agent.status ?? "draft")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var configModelTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Model")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    if availableModels.isEmpty {
                        TextField(agent.model, text: $model)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                        Text("No models loaded from fusion-mlx. Start the MLX service or enter a model id manually.")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        FusionModelPicker(scene: .agent, selection: $model, models: bridge.mlxState.models)
                    }
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Temperature: \(String(format: "%.1f", temperature))")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Max Tokens")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    TextField("Max tokens", value: $maxTokens, format: .number)
                        .textFieldStyle(.plain)
                        .padding(theme.spacingS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                }
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Safety Level")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Picker("Safety Level", selection: $safetyLevel) {
                        ForEach(safetyLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(safetyExplanations[safetyLevel] ?? "")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var configToolsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("Enabled Tools (\(agent.tools.count))")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                if agent.tools.isEmpty {
                    Text("No tools enabled")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(agent.tools, id: \.self) { tool in
                            FusionTag(tool, color: .green)
                        }
                    }
                }
                Text("Capabilities (\(agent.capabilities.count))")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                if agent.capabilities.isEmpty {
                    Text("No capabilities defined")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(agent.capabilities, id: \.self) { cap in
                            FusionTag(cap, color: .purple)
                        }
                    }
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var configKBTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("Knowledge Base")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                if let kbIds = agent.knowledge_base_ids, !kbIds.isEmpty {
                    ForEach(kbIds, id: \.self) { kbId in
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(theme.accent)
                            Text(kbId)
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                                .foregroundStyle(theme.text)
                            Spacer()
                            FusionTag("Bound", color: .green)
                        }
                        .padding(theme.spacingS)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                    }
                } else {
                    Text("No knowledge base bound")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Text("RAG Strategy")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Text(agent.rag_strategy ?? "default")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                HStack {
                    Text("Web Search")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(agent.web_search_enabled == true ? "On" : "Off")
                        .foregroundStyle(agent.web_search_enabled == true ? .green : .gray)
                }
                HStack {
                    Text("Deep Research")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(agent.deep_research_enabled == true ? "On" : "Off")
                        .foregroundStyle(agent.deep_research_enabled == true ? .green : .gray)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var configConnectorsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("Connectors")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                if bridge.configState.connectors.isEmpty {
                    Text("No connectors configured")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(Array(bridge.configState.connectors.enumerated()), id: \.offset) { idx, conn in
                        let name = conn["name"] as? String ?? "Unknown"
                        let type = conn["type"] as? String ?? ""
                        let status = conn["status"] as? String ?? "unknown"
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(theme.accent)
                            Text(name)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                            Spacer()
                            FusionTag(type, color: .blue)
                            FusionTag(status, color: status == "connected" ? .green : .gray)
                        }
                        .padding(theme.spacingS)
                        .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                    }
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var configStyleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("Output Style")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                if bridge.configState.styles.isEmpty {
                    Text("No styles available")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(Array(bridge.configState.styles.prefix(10).enumerated()), id: \.offset) { idx, style in
                        let name = style["name"] as? String ?? "Style"
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(theme.accent)
                            Text(name)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                            Spacer()
                        }
                        .padding(theme.spacingS)
                        .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                    }
                }
            }
            .padding(theme.spacingM)
        }
    }
}

// MARK: - AgentDetailView

struct AgentDetailView: View {
    let agent: Agent
    let toastManager: FusionToastManager
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @EnvironmentObject var bridge: AgentBridge
    @State private var taskInput = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                headerSection

                FusionCard(style: .inset, header: "Information", headerIcon: "info.circle") {
                    VStack(spacing: 0) {
                        infoRow(label: "Type", value: agent.type.rawValue, isLast: false)
                        infoRow(label: "Model", value: agent.model, isLast: false)
                        infoRow(label: "Status", value: agent.status.rawValue, isLast: false)
                        infoRow(label: "Tasks", value: "\(agent.taskCount)", isLast: false)
                        infoRow(label: "Built-in", value: agent.isBuiltin ? "Yes" : "No", isLast: false)
                        infoRow(label: "Temperature", value: String(format: "%.1f", agent.temperature), isLast: false)
                        infoRow(label: "Safety Level", value: agent.safetyLevel, isLast: true)
                    }
                }

                FusionCard(style: .inset, header: "System Prompt", headerIcon: "text.bubble") {
                    Text(agent.systemPrompt)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                }

                FusionCard(style: .inset, header: "Assign Task", headerIcon: "paperplane") {
                    HStack(spacing: theme.spacingS) {
                        TextField("Describe the task...", text: $taskInput)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }

                        FusionButton("Assign", icon: "paperplane", style: .primary, size: .small, isDisabled: taskInput.isEmpty) {
                            let inputCopy = taskInput
                            Task {
                                do {
                                    let task = try await bridge.taskSubmit(
                                        title: inputCopy,
                                        description: inputCopy,
                                        agentId: agent.id,
                                        graphId: "",
                                        trigger: .immediate,
                                        cronExpression: "",
                                        runAt: nil,
                                        input: inputCopy,
                                        priority: .medium
                                    )
                                    await MainActor.run {
                                        bridge.taskExecuteImmediate(task.id)
                                        toastManager.show(style: .success, title: "Task Assigned", message: "Task sent to \(agent.name)")
                                        taskInput = ""
                                    }
                                } catch {
                                    await MainActor.run {
                                        toastManager.show(style: .error, title: "Assign Failed", message: error.localizedDescription)
                                    }
                                }
                            }
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    if !agent.isBuiltin {
                        FusionButton("Delete Agent", icon: "trash", style: .destructive, size: .small) {
                            orchestrator.deleteAgent(agent.id)
                            toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingS)

                Spacer(minLength: theme.spacing2XL)
            }
            .padding(.vertical, theme.spacingL)
        }
    }

    private var headerSection: some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: agent.type.icon)
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(agent.name)
                    .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                FusionTag(agent.type.rawValue, icon: agent.type.icon, color: agent.type.tagColor)
            }
            Spacer()
            StatusPill(status: agent.status.pillStatus)
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func infoRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
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
}

// MARK: - CreateAgentSheet

struct CreateAgentSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var bridge: AgentBridge
    @State private var name = ""
    @State private var availableGraphs: [AgentGraphModel] = []
    @State private var selectedGraphId: String? = nil
    @State private var type: AgentType = .custom
    @State private var model = ""
    @State private var systemPrompt = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 4096
    @State private var safetyLevel: String = "L1"
    @State private var toolsText: String = ""
    @State private var capabilitiesText: String = ""
    @State private var tagsText: String = ""
    @State private var soulMd: String = ""
    @State private var memoryMd: String = ""
    @State private var agentsMd: String = ""
    let onCreate: (String, AgentType, String, String, Double, Int, [String], [String], String, [String], String, String, String, String?) -> Void

    // Backend SafetyGateway defines a 3-level system (L1/L2/L3); L4 has no backend meaning.
    private let safetyLevels = ["L1", "L2", "L3"]
    private let safetyExplanations: [String: String] = [
        "L1": "Autonomous — agent acts silently, no approval needed.",
        "L2": "Preview — agent shows a diff/plan and waits for your confirm before executing.",
        "L3": "Gateway — agent must get explicit approval before every action."
    ]

    private var availableModels: [MLXModelInfo] {
        let chat = bridge.mlxState.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.mlxState.models : chat
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("Create Agent")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                FusionCard(style: .bordered) {
                    VStack(spacing: theme.spacingM) {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Name *")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("Agent name", text: $name)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Type")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Picker("Type", selection: $type) {
                                ForEach(AgentType.allCases) { t in
                                    Label(t.rawValue, systemImage: t.icon).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Model")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            if availableModels.isEmpty {
                                TextField(type.defaultModel, text: $model)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Text("No models loaded from fusion-mlx. Start the MLX service or enter a model id manually.")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            } else {
                                FusionModelPicker(scene: .agent, selection: $model, models: bridge.mlxState.models, defaultTag: "")
                            }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("System Prompt")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField(type.defaultSystemPrompt, text: $systemPrompt, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Temperature: \(String(format: "%.1f", temperature))")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Slider(value: $temperature, in: 0...2, step: 0.1)
                        }

                        HStack(spacing: theme.spacingM) {
                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                Text("Max Tokens")
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                TextField("4096", value: $maxTokens, format: .number)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                            }

                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                Text("Safety Level")
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                Picker("Safety", selection: $safetyLevel) {
                                    ForEach(safetyLevels, id: \.self) { level in
                                        Text(level).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(safetyExplanations[safetyLevel] ?? "")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Tools (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("web_search, calculator, code_execute", text: $toolsText)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Capabilities (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("code_generation, web_browsing", text: $capabilitiesText)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Tags (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("code, python, review", text: $tagsText)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        }

                        markdownField("SOUL.md (personality & instructions)",
                                      placeholder: "Define the agent's persona, tone, and core instructions...",
                                      text: $soulMd)
                        markdownField("MEMORY.md (persistent memory)",
                                      placeholder: "Facts and context the agent should remember across sessions...",
                                      text: $memoryMd)
                        markdownField("AGENTS.md (metadata & conventions)",
                                      placeholder: "Conventions, sub-agent definitions, and operational notes...",
                                      text: $agentsMd)

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Workflow / Graph")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            if availableGraphs.isEmpty {
                                HStack(spacing: 4) {
                                    Text("No graphs available — create one in Workflow tab")
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                    Button("Refresh") {
                                        Task { try? await bridge.fetchGraphs() }
                                    }
                                    .font(.system(size: theme.captionSize))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.accentColor)
                                }
                            } else {
                                Picker("Select Graph", selection: $selectedGraphId) {
                                    Text("None").tag(String?.none)
                                    ForEach(availableGraphs, id: \.id) { graph in
                                        Text("\(graph.name) (\(graph.nodes.count) nodes)")
                                            .tag(String?.some(graph.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                    FusionButton("Create", icon: "plus", style: .primary, size: .regular, isDisabled: name.isEmpty) {
                        let tools = toolsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let capabilities = capabilitiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        onCreate(name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soulMd, memoryMd, agentsMd, selectedGraphId)
                        dismiss()
                    }
                }
            }
            .padding(theme.spacingXL)
            .frame(width: 440)
            .background(theme.windowBg)
        }
        .onAppear {
            Task {
                if let graphs = try? await bridge.fetchGraphs() {
                    availableGraphs = graphs
                }
            }
        }
    }

    private func markdownField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(title)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            TextEditor(text: text)
                .font(.system(size: theme.footnoteSize))
                .scrollContentBackground(.hidden)
                .padding(theme.spacingS)
                .frame(minHeight: 80, idealHeight: 100)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                            .padding(theme.spacingS)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

// MARK: - EditAgentSheet
// 编辑已有 agent 的核心字段: name/description/model/system_prompt/tools/capabilities/tags/safety_level.
// 对应后端 agent.update (IPCAgentMethods.agentUpdate -> AgentBridge.agentUpdate).

struct EditAgentSheet: View {
    let agent: AgentModel
    let onSave: (String, String, String, String, Double, Int, [String], [String], [String], String) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var bridge: AgentBridge

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var model: String = ""
    @State private var systemPrompt: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 4096
    @State private var safetyLevel: String = "L1"
    @State private var toolsText: String = ""
    @State private var capabilitiesText: String = ""
    @State private var tagsText: String = ""

    private let safetyLevels = ["L1", "L2", "L3"]
    private let safetyExplanations: [String: String] = [
        "L1": "Autonomous — agent acts silently, no approval needed.",
        "L2": "Preview — agent shows a diff/plan and waits for your confirm before executing.",
        "L3": "Gateway — agent must get explicit approval before every action."
    ]

    private var availableModels: [MLXModelInfo] {
        let chat = bridge.mlxState.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.mlxState.models : chat
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                HStack {
                    Text("Edit Agent")
                        .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                    Text(agent.name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }

                FusionCard(style: .bordered) {
                    VStack(spacing: theme.spacingM) {
                        fieldLabel("Name *")
                        TextField("Agent name", text: $name)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }

                        fieldLabel("Description")
                        TextField("Short description", text: $descriptionText, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }

                        fieldLabel("Model")
                        if availableModels.isEmpty {
                            TextField(agent.model, text: $model)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                        } else {
                            FusionModelPicker(scene: .agent, selection: $model, models: bridge.mlxState.models, defaultTag: "")
                        }

                        fieldLabel("System Prompt")
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(theme.spacingS)
                            .frame(minHeight: 100, idealHeight: 140)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }

                        fieldLabel("Temperature: \(String(format: "%.1f", temperature))")
                        Slider(value: $temperature, in: 0...2, step: 0.1)

                        HStack(spacing: theme.spacingM) {
                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                fieldLabel("Max Tokens")
                                TextField("4096", value: $maxTokens, format: .number)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                            }
                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                fieldLabel("Safety Level")
                                Picker("Safety", selection: $safetyLevel) {
                                    ForEach(safetyLevels, id: \.self) { level in
                                        Text(level).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(safetyExplanations[safetyLevel] ?? "")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        commaField("Tools (comma-separated)", placeholder: "web_search, calculator", text: $toolsText)
                        commaField("Capabilities (comma-separated)", placeholder: "code_generation", text: $capabilitiesText)
                        commaField("Tags (comma-separated)", placeholder: "code, python", text: $tagsText)
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                    FusionButton("Save", icon: "checkmark", style: .primary, size: .regular, isDisabled: name.isEmpty) {
                        let tools = toolsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let capabilities = capabilitiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        onSave(name, descriptionText, model, systemPrompt, temperature, maxTokens, tools, capabilities, tags, safetyLevel)
                        dismiss()
                    }
                }
            }
            .padding(theme.spacingXL)
            .frame(width: 460)
            .background(theme.windowBg)
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        name = agent.name
        descriptionText = agent.description
        model = agent.model
        systemPrompt = agent.system_prompt
        temperature = agent.temperature
        maxTokens = agent.max_tokens
        safetyLevel = agent.safety_level.isEmpty ? "L1" : agent.safety_level
        toolsText = agent.tools.joined(separator: ", ")
        capabilitiesText = agent.capabilities.joined(separator: ", ")
        tagsText = agent.tags.joined(separator: ", ")
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: theme.footnoteSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }

    private func commaField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            fieldLabel(title)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
        }
    }
}
