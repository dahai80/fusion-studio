// Callers: SectionContentView (case .code).
// Affected API: CodeMainView (Claude-style code main area with greeting + input + plus menu + model selector + quick actions), QuickAction.
// Data schemas: QuickAction struct (icon/title/prompt), PlusMenuItem enum, CodeAgent.CodeMessage, ProjectWorkspace.
// User instruction: "输入框右侧选择模型，对话框下面5个按钮 Write/Learn/Code/Life stuff/Claude's choice，前面有小logo"

import SwiftUI
import AppKit
import os.log

private let codeMainLog = Logger(subsystem: "com.fusion.studio", category: "CodeMainView")

enum PlusMenuItem: String, CaseIterable, Identifiable {
    case addFiles = "Add files or photos"
    case screenshot = "Take a screenshot"
    case addToProject = "Add to project"
    case skills = "Skills"
    case addConnector = "Add connector"
    case addPlugins = "Add plugins"
    case webSearch = "Web search"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .addFiles: return "doc.badge.plus"
        case .screenshot: return "camera"
        case .addToProject: return "folder.badge.plus"
        case .skills: return "sparkles"
        case .addConnector: return "link"
        case .addPlugins: return "puzzlepiece.extension"
        case .webSearch: return "globe"
        }
    }

    var hasSubmenu: Bool {
        switch self {
        case .skills, .addConnector: return true
        default: return false
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}

enum ModelPickerPage {
    case main
    case effort
    case moreModels
}

struct CodeMainView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bridge: AgentBridge
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var inputText = ""
    @State private var isWebSearchEnabled = false
    @State private var selectedModel = ""
    @State private var micVolume: Double = 0.8
    @State private var holdToRecord = true
    @State private var isVoiceMode = false
    @State private var showMicSettings = false
    @State private var showModelPicker = false
    @State private var selectedEffort: String = "Medium"
    @State private var thinkingEnabled = false
    @State private var modelPickerPage: ModelPickerPage = .main

    private let quickActions: [QuickAction] = [
        QuickAction(icon: "pencil.line", title: "Write", prompt: "Help me write something"),
        QuickAction(icon: "book", title: "Learn", prompt: "Help me learn about"),
        QuickAction(icon: "chevron.left.forwardslash.chevron.right", title: "Code", prompt: "Help me code"),
        QuickAction(icon: "heart", title: "Life stuff", prompt: "Help me with life stuff"),
        QuickAction(icon: "star", title: "Claude's choice", prompt: "Surprise me with something creative"),
    ]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: theme.spacingM) {
                        if agent.conversation.isEmpty && !workspace.hasProject {
                            Spacer(minLength: 0)
                            Text("\(greeting), \(NSUserName())")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        }
                        ForEach(agent.conversation) { msg in
                            CodeMainMessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, theme.spacing2XL)
                    .padding(.vertical, theme.spacingL)
                }
                .onChange(of: agent.conversation.count) {
                    if let last = agent.conversation.last {
                        withAnimation(theme.springDefault) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)

            VStack(spacing: theme.spacingS) {
                HStack {
                    Spacer()
                    inputBox
                        .frame(maxWidth: 680)
                    Spacer()
                }

                if agent.conversation.isEmpty {
                    HStack {
                        Spacer()
                        quickActionsBar
                            .frame(maxWidth: 680)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, theme.spacingM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            agent.agentBridge = bridge
            if selectedModel.isEmpty && !bridge.models.isEmpty {
                selectedModel = bridge.models.first?.name ?? ""
                agent.selectedModel = selectedModel
            }
            Task {
                try? await bridge.fetchModels()
                if selectedModel.isEmpty, let first = bridge.models.first?.name {
                    selectedModel = first
                    agent.selectedModel = first
                }
            }
        }
    }

    private var inputBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $inputText)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 48, maxHeight: 200)
                .padding(.horizontal, theme.spacingM)
                .padding(.top, theme.spacingS)
                .onKeyPress(.return) {
                    if NSEvent.modifierFlags.contains(.shift) {
                        return .ignored
                    }
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return .handled }
                    sendMessage()
                    return .handled
                }

            HStack(spacing: 0) {
                plusButtonMenu

                Spacer()

                modelSelector

                Spacer()
                    .frame(width: theme.spacingS)

                micButton

                Spacer()
                    .frame(width: theme.spacingS)

                voiceButton

                Spacer()
                    .frame(width: theme.spacingM)
                    .padding(.bottom, theme.spacingS)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                .fill(theme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                        .stroke(theme.separator, lineWidth: 1)
                )
        )
        .overlay(alignment: .topLeading) {
            if inputText.isEmpty {
                Text("How can I help you today?")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.top, theme.spacingS + 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var modelSelector: some View {
        Button(action: { showModelPicker.toggle() }) {
            HStack(spacing: 4) {
                Text(selectedModel.isEmpty ? "Select model" : selectedModel)
                    .font(.system(size: theme.captionSize, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.separator.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, theme.spacingS)
        .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    if bridge.models.isEmpty {
                        Text("No models available")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.vertical, 4)
                    } else {
                        let displayModels = Array(bridge.models.prefix(4))
                        ForEach(displayModels) { model in
                            Button(action: {
                                selectedModel = model.name
                                agent.selectedModel = model.name
                                Task { try? await bridge.mlxSetModel(model: model.name) }
                                codeMainLog.info("Model selected: \(model.name)")
                                modelPickerPage = .main
                                showModelPicker = false
                            }) {
                                HStack {
                                    Text(model.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.text)
                                    Spacer()
                                    if selectedModel == model.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(selectedModel == model.name ? theme.accent.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 2)

                        HStack {
                            Text("Effort")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.text)
                            Spacer()
                            Text(selectedEffort)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(modelPickerPage == .effort ? theme.accent.opacity(0.08) : Color.clear)
                        )
                        .onHover { hovering in
                            if hovering { modelPickerPage = .effort }
                        }

                        if bridge.models.count > 4 {
                            Divider().padding(.vertical, 2)

                            HStack {
                                Text("More Models")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(modelPickerPage == .moreModels ? theme.accent.opacity(0.08) : Color.clear)
                            )
                            .onHover { hovering in
                                if hovering { modelPickerPage = .moreModels }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .frame(width: 200)

                if modelPickerPage != .main {
                    Divider().padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        switch modelPickerPage {
                        case .effort:
                            ForEach(["Low", "Medium", "High", "Extra", "Max"], id: \.self) { level in
                                Button(action: {
                                    selectedEffort = level
                                    codeMainLog.info("Effort set to: \(level)")
                                    modelPickerPage = .main
                                }) {
                                    HStack {
                                        Text(level)
                                            .font(.system(size: 12))
                                            .foregroundStyle(theme.text)
                                        Spacer()
                                        if selectedEffort == level {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10))
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(selectedEffort == level ? theme.accent.opacity(0.1) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            Divider().padding(.vertical, 2)

                            HStack {
                                Text("Thinking")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Toggle("", isOn: $thinkingEnabled)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                        case .moreModels:
                            let moreModels = Array(bridge.models.dropFirst(4))
                            ForEach(moreModels) { model in
                                Button(action: {
                                    selectedModel = model.name
                                    agent.selectedModel = model.name
                                    Task { try? await bridge.mlxSetModel(model: model.name) }
                                    codeMainLog.info("Model selected: \(model.name)")
                                    showModelPicker = false
                                }) {
                                    HStack {
                                        Text(model.name)
                                            .font(.system(size: 12))
                                            .foregroundStyle(theme.text)
                                            .lineLimit(1)
                                        Spacer()
                                        if selectedModel == model.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10))
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(selectedModel == model.name ? theme.accent.opacity(0.1) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                        default:
                            EmptyView()
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(width: 180)
                }
            }
        }
    }

    private var micButton: some View {
        Button(action: { showMicSettings.toggle() }) {
            Image(systemName: "mic")
                .font(.system(size: 16))
                .foregroundStyle(theme.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, theme.spacingS)
        .popover(isPresented: $showMicSettings, arrowEdge: .top) {
            VStack(spacing: theme.spacingM) {
                Text("Microphone")
                    .font(.system(size: theme.captionSize, weight: .semibold))

                HStack(spacing: theme.spacingS) {
                    Text("Volume")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 48, alignment: .leading)
                    Slider(value: $micVolume, in: 0...1)
                        .frame(width: 120)
                }

                HStack(spacing: theme.spacingS) {
                    Text("Hold to Record")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Toggle("", isOn: $holdToRecord)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .frame(width: 188)
            }
            .padding(theme.spacingM)
        }
    }

    private var voiceButton: some View {
        Button(action: {
            isVoiceMode.toggle()
            codeMainLog.info("Voice mode: \(isVoiceMode)")
        }) {
            Image(systemName: isVoiceMode ? "waveform" : "waveform.path")
                .font(.system(size: 16))
                .foregroundStyle(isVoiceMode ? theme.accent : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, theme.spacingS)
    }

    private var quickActionsBar: some View {
        HStack(spacing: theme.spacingS) {
            ForEach(quickActions) { action in
                Button(action: {
                    inputText = action.prompt
                    codeMainLog.info("Quick action: \(action.title)")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.system(size: 12))
                        Text(action.title)
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                            .fill(theme.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                                    .stroke(theme.separator, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var plusButtonMenu: some View {
        Menu {
            Button(action: { workspace.openLocalFolder() }) {
                Label("Add files or photos", systemImage: "doc.badge.plus")
            }
            Button(action: { takeScreenshot() }) {
                Label("Take a screenshot", systemImage: "camera")
            }
            Button(action: { workspace.openLocalFolder() }) {
                Label("Add to project", systemImage: "folder.badge.plus")
            }

            Menu {
                Button("Morning") { codeMainLog.info("Skill: Morning") }
                Button("Skill-creator") { codeMainLog.info("Skill: Skill-creator") }
                Button("Manage skills") { codeMainLog.info("Skill: Manage skills") }
                Divider()
                Button("+ Browse skills") { codeMainLog.info("Skill: Browse skills") }
            } label: {
                Label("Skills", systemImage: "sparkles")
            }

            Menu {
                Button("Browse connectors") { codeMainLog.info("Connector: Browse") }
                Button("Add custom connector") { codeMainLog.info("Connector: Custom") }
            } label: {
                Label("Add connector", systemImage: "link")
            }

            Button(action: { codeMainLog.info("Add plugins") }) {
                Label("Add plugins", systemImage: "puzzlepiece.extension")
            }

            Button(action: {
                isWebSearchEnabled.toggle()
                codeMainLog.info("Web search: \(isWebSearchEnabled)")
            }) {
                HStack {
                    Label("Web search", systemImage: "globe")
                    if isWebSearchEnabled {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 20))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .padding(.leading, theme.spacingM)
        .padding(.bottom, theme.spacingS)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let effort = selectedEffort.lowercased()
        agent.askAI(prompt: text, effort: effort, thinking: thinkingEnabled)
        inputText = ""
        codeMainLog.info("Message sent: \(text.prefix(50)) effort=\(effort) thinking=\(thinkingEnabled)")
    }

    private func takeScreenshot() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-c"]
        task.launch()
        codeMainLog.info("Screenshot initiated")
    }
}

struct CodeMainMessageBubble: View {
    let message: CodeAgent.CodeMessage
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(message.role == "user" ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
                    )

                Text(message.timestamp, style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }

            if message.role == "assistant" {
                Spacer(minLength: 60)
            }
        }
    }
}
