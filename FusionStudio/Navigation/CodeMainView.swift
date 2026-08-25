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
    let skillCommand: String?
}

struct CodeMainView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var navState: NavigationState
    @EnvironmentObject var bridge: AgentBridge
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var fcBridge = FusionCodeBridge.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var inputText = ""
    @State private var isWebSearchEnabled = false
    @State private var selectedModel = ""
    @State private var micVolume: Double = 0.8
    @State private var holdToRecord = true
    @State private var isVoiceMode = false
    @State private var showMicSettings = false
    @State private var selectedEffort: String = "Medium"
    @State private var thinkingEnabled = false

    private let quickActions: [QuickAction] = [
        QuickAction(icon: "pencil.line", title: "Write", prompt: "Help me write something", skillCommand: "/skill writing-plans"),
        QuickAction(icon: "book", title: "Learn", prompt: "Help me learn about", skillCommand: "/skill learn"),
        QuickAction(icon: "chevron.left.forwardslash.chevron.right", title: "Code", prompt: "Help me code", skillCommand: "/skill tdd"),
        QuickAction(icon: "heart", title: "Life stuff", prompt: "Help me with life stuff", skillCommand: nil),
        QuickAction(icon: "star", title: "Claude's choice", prompt: "Surprise me with something creative", skillCommand: nil),
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
                .onChange(of: fcBridge.currentStreamContent) {
                    guard !agent.conversation.isEmpty else { return }
                    let lastIdx = agent.conversation.indices.last!
                    guard agent.conversation[lastIdx].role == "assistant" else { return }
                    let streamContent = fcBridge.currentStreamContent
                    if !streamContent.isEmpty {
                        agent.conversation[lastIdx] = CodeAgent.CodeMessage(
                            role: "assistant",
                            content: streamContent,
                            timestamp: agent.conversation[lastIdx].timestamp,
                            codeBlocks: []
                        )
                    }
                }
                .onChange(of: fcBridge.isStreaming) { streaming in
                    if !streaming, !agent.conversation.isEmpty {
                        let lastIdx = agent.conversation.indices.last!
                        if agent.conversation[lastIdx].role == "assistant", agent.conversation[lastIdx].content.isEmpty {
                            agent.conversation.removeLast()
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
            if selectedModel.isEmpty {
                let dm = FusionConfig.shared.defaultModel(for: .code)
                if !dm.isEmpty {
                    selectedModel = dm
                    agent.selectedModel = selectedModel
                } else if let def = MLXModelInfo.preferredDefault(in: bridge.models) {
                    selectedModel = def.name
                    agent.selectedModel = selectedModel
                }
            }
            Task {
                try? await bridge.fetchModels()
                if selectedModel.isEmpty {
                    let dm = FusionConfig.shared.defaultModel(for: .code)
                    if !dm.isEmpty {
                        selectedModel = dm
                        agent.selectedModel = dm
                    } else if let def = MLXModelInfo.preferredDefault(in: bridge.models) {
                        selectedModel = def.name
                        agent.selectedModel = def.name
                    }
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
        HStack(spacing: theme.spacingS) {
            FusionModelPicker(
                scene: .code,
                selection: $selectedModel,
                models: bridge.models,
                onChange: { id in
                    agent.selectedModel = id
                    Task { try? await bridge.mlxSetModel(model: id) }
                    codeMainLog.info("Model selected: \(id)")
                }
            )
            effortMenu
        }
        .padding(.bottom, theme.spacingS)
    }

    private var effortMenu: some View {
        Menu {
            ForEach(["Low", "Medium", "High", "Extra", "Max"], id: \.self) { level in
                Button {
                    selectedEffort = level
                    codeMainLog.info("Effort set to: \(level)")
                } label: {
                    if selectedEffort == level {
                        Label(level, systemImage: "checkmark")
                    } else {
                        Text(level)
                    }
                }
            }
            Divider()
            Toggle("Thinking", isOn: $thinkingEnabled)
        } label: {
            HStack(spacing: 4) {
                Text("Effort")
                    .font(.system(size: theme.captionSize, weight: .medium))
                Text(selectedEffort)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
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
        .menuStyle(.borderlessButton)
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
                    if let skill = action.skillCommand, fcBridge.isConnected {
                        agent.conversation.append(CodeAgent.CodeMessage(role: "user", content: action.prompt, timestamp: Date(), codeBlocks: []))
                        agent.conversation.append(CodeAgent.CodeMessage(role: "assistant", content: "", timestamp: Date(), codeBlocks: []))
                        fcBridge.chatStream(
                            message: skill,
                            cwd: workspace.projectRoot?.path,
                            model: selectedModel.isEmpty ? nil : selectedModel,
                            executionMode: "ask",
                            webSearch: isWebSearchEnabled,
                            commandMode: true
                        )
                        codeMainLog.info("Quick action skill: \(action.title) → \(skill)")
                    } else {
                        inputText = action.prompt
                        codeMainLog.info("Quick action prompt: \(action.title)")
                    }
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
                Button("Morning") { inputText = "/skill morning " }
                Button("Skill-creator") { inputText = "/skill skill-creator " }
                Button("Manage skills") { browseSkills() }
                Divider()
                Button("+ Browse skills") { browseSkills() }
            } label: {
                Label("Skills", systemImage: "sparkles")
            }

            Menu {
                Button("Browse connectors") { inputText = "/connector list" }
                Button("Add custom connector") { inputText = "/connector add " }
            } label: {
                Label("Add connector", systemImage: "link")
            }

            Button(action: { browsePlugins() }) {
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

    private func browseSkills() {
        if fcBridge.isConnected {
            inputText = "/skill list"
        } else {
            codeMainLog.info("Skills unavailable: fusion-code not connected")
        }
    }

    private func browsePlugins() {
        navState.activeSection = .pluginEcosystem
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if fcBridge.isConnected {
            agent.conversation.append(CodeAgent.CodeMessage(role: "user", content: text, timestamp: Date(), codeBlocks: []))
            agent.conversation.append(CodeAgent.CodeMessage(role: "assistant", content: "", timestamp: Date(), codeBlocks: []))
            fcBridge.chatStream(
                message: text,
                cwd: workspace.projectRoot?.path,
                model: selectedModel.isEmpty ? nil : selectedModel,
                executionMode: "ask",
                webSearch: isWebSearchEnabled
            )
            codeMainLog.info("Message sent via fusion-code WS: \(text.prefix(50))")
        } else {
            let effort = selectedEffort.lowercased()
            agent.askAI(prompt: text, effort: effort, thinking: thinkingEnabled)
            codeMainLog.info("Message sent via MLX fallback: \(text.prefix(50)) effort=\(effort)")
        }
        inputText = ""
    }

    // HIGH-4: 旧实现 Process() 出作用域即被 ARC 回收, 交互式 screencapture 中途被杀变孤儿。
    // 改用 ScreenCapture 单例保活 + try run + terminationHandler, 不阻塞协作线程池。
    private func takeScreenshot() {
        Task {
            let code = await ScreenCapture.shared.captureInteractive()
            if code == 0 {
                codeMainLog.info("Screenshot 完成, 已存入剪贴板")
            } else {
                codeMainLog.warning("Screenshot 取消或失败 code=\(code)")
            }
        }
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
