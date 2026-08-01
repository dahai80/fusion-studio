// Callers: DesignView — left panel of 3-column layout for design chat interaction
// Affected API: DesignChatPanel View, DesignBridge skill methods (skillTextToUI/skillMultiVariants/applyLocalEdit), DesignPrompts.groupedQuickTemplates
// Data schemas: DesignMessage, DesignPage, DesignQuickTemplate (group field), DesignTemplateGroup
// User instruction: "按照GUI草图实现fusion design，和~/fusion/fusion-design配合，端到端完成fusion设计"
// User instruction: "现在开始实施" — Task #16 P3-5 fd-export PNG/SVG/HTML 批量导出

import SwiftUI
import os.log

private let chatPanelLog = Logger(subsystem: "com.fusion.studio", category: "DesignChatPanel")

struct DesignChatPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var agentBridge: AgentBridge

    @State private var inputText: String = ""
    @State private var showQuickTemplates: Bool = false
    @State private var showVersionHistory: Bool = false
    @State private var autoScroll: Bool = true
    @State private var showPageList: Bool = false
    @State private var showSwiftUIExport: Bool = false
    @State private var showCodegenExport: Bool = false
    @State private var showBatchExport: Bool = false

    private var hasDesignMessages: Bool {
        !designBridge.messages.isEmpty || designBridge.isGenerating
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(theme.separator).frame(height: 1)

            if showPageList {
                pageListView
                Rectangle().fill(theme.separator).frame(height: 1)
            }

            if hasDesignMessages {
                messageList

                if designBridge.isPlanPreviewActive {
                    planPreviewBar
                    Rectangle().fill(theme.separator).frame(height: 1)
                }

                Rectangle().fill(theme.separator).frame(height: 1)
                CenteredChatInput(
                    text: $inputText,
                    placeholder: "描述你想设计的界面...",
                    isCentered: false,
                    onSend: sendChat,
                    trailingContent: AnyView(
                        Button(action: { sendChat() }) {
                            Image(systemName: designBridge.isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                                .font(.system(size: theme.iconL))
                                .foregroundStyle(designBridge.isGenerating ? theme.textTertiary : theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty && !designBridge.isGenerating)
                    )
                )
            } else {
                CenteredChatInput(
                    text: $inputText,
                    placeholder: "描述你想设计的界面...",
                    isCentered: true,
                    onSend: sendChat,
                    trailingContent: AnyView(
                        Button(action: { sendChat() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                )
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        .sheet(isPresented: $showSwiftUIExport) {
            swiftUIExportSheet
        }
        .sheet(isPresented: $showCodegenExport) {
            codegenExportSheet
        }
        .sheet(isPresented: $showBatchExport) {
            batchExportSheet
        }
        .onChange(of: designBridge.exportedSwiftUICode) {
            if !designBridge.exportedSwiftUICode.isEmpty && !showSwiftUIExport {
                showSwiftUIExport = true
            }
        }
        .onChange(of: designBridge.exportedCodegenCode) {
            if !designBridge.exportedCodegenCode.isEmpty && !showCodegenExport {
                showCodegenExport = true
            }
        }
        .onAppear {
            // 进入 Design 时复核 MLX 状态：启动竞态可能让 isMLXRunning 滞留 false (bug2)。
            if !appState.isMLXRunning {
                Task {
                    let ok = await agentBridge.probeMLXRunningStatus()
                    await MainActor.run {
                        appState.isMLXRunning = ok
                    }
                }
            }
        }
    }

    private var swiftUIExportSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SwiftUI 导出")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("复制") {
                    designBridge.copyExportedSwiftUI()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                Button("关闭") {
                    showSwiftUIExport = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                Text(designBridge.exportedSwiftUICode)
                    .font(.system(size: theme.captionSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.codeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingM)
            }
        }
        .frame(width: 560, height: 480)
        .background(theme.windowBg)
    }

    private var codegenExportSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("代码导出")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("复制") {
                    designBridge.copyExportedCodegen()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                Button("关闭") {
                    showCodegenExport = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                Text(designBridge.exportedCodegenCode)
                    .font(.system(size: theme.captionSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.codeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingM)
            }
        }
        .frame(width: 560, height: 480)
        .background(theme.windowBg)
    }

    private var chatHeader: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fusion Design")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                if designBridge.isGenerating {
                    HStack(spacing: 4) {
                        inferenceStepIcon
                        Text(inferenceStepLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                        if designBridge.streamTokenCount > 0 {
                            Text("\(designBridge.streamTokenCount) tokens")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                } else if !designBridge.currentArtifactTitle.isEmpty {
                    Text(designBridge.currentArtifactTitle)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { showPageList.toggle() }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(showPageList ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("页面管理")

            if !designBridge.currentArtifactCode.isEmpty {
                Button(action: { designBridge.copyCurrentCode() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("复制代码 (⇧⌘C)")

                Button(action: { showCodegenExport = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .help("导出代码 (⇧⌘E)")
            }

            Button(action: { designBridge.clearConversation() }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("清空对话")
            .disabled(designBridge.messages.isEmpty)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    if designBridge.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(designBridge.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if designBridge.isGenerating {
                            inferenceProgressBubble
                        }
                    }
                }
                .padding(theme.spacingM)
            }
            .onChange(of: designBridge.messages.count) {
                if autoScroll, let last = designBridge.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: designBridge.streamTokenCount) {
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("inference-progress", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()

            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 36))
                .foregroundStyle(theme.textTertiary)

            Text("描述你想设计的界面")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)

            Text("AI 将为你生成可交互的 HTML 代码，右侧实时预览")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            quickTemplateGrid

            Spacer()
        }
    }

    private var quickTemplateGrid: some View {
        VStack(spacing: theme.spacingS) {
            ForEach(DesignTemplateGroup.allCases) { group in
                let templates = DesignPrompts.groupedQuickTemplates.filter { $0.group == group }
                if !templates.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack(spacing: 4) {
                            Image(systemName: group.icon)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                            Text(group.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacingXS), count: 2),
                            spacing: theme.spacingXS
                        ) {
                            ForEach(templates) { tmpl in
                                Button(action: {
                                    if tmpl.prompt.hasPrefix("SKILL:") {
                                        handleSkillTemplate(tmpl)
                                    } else {
                                        inputText = tmpl.prompt
                                        sendChat()
                                    }
                                }) {
                                    HStack(spacing: theme.spacingXS) {
                                        Image(systemName: tmpl.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(group == .skills ? theme.accent : theme.textSecondary)
                                        Text(tmpl.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(theme.text)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, theme.spacingS)
                                    .padding(.vertical, theme.spacingXS)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .fill(group == .skills ? theme.accent.opacity(0.1) : theme.groupBg)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(group == .skills ? theme.accent.opacity(0.3) : theme.groupBorder, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacingS)
    }

    // Callers: DesignChatPanel skill template buttons.
    // Affected API: handleSkillTemplate adds image_to_ui route to skillImageToUI.
    // Data schemas: SKILL: prefix routing, DesignQuickTemplate.prompt.
    // User instruction: "跟fusion-design做集成测试，基于prd文档，测试到菜单，子菜单，数据要素，流程和user case"

    private func handleSkillTemplate(_ tmpl: DesignQuickTemplate) {
        let skillID = tmpl.prompt.replacingOccurrences(of: "SKILL:", with: "")
        switch skillID {
        case "text_to_ui":
            designBridge.skillTextToUI(prompt: inputText.isEmpty ? "设计一个现代深色主题页面" : inputText)
        case "image_to_ui":
            let hint = inputText.isEmpty ? "参考图片生成UI布局" : inputText
            designBridge.skillImageToUI(imagePath: "", hint: hint)
        case "multi_variants":
            let prompt = inputText.isEmpty ? "设计一个数据卡片组件" : inputText
            designBridge.skillMultiVariants(prompt: prompt)
        case "local_edit":
            if !designBridge.marqueeSelectedNodeIDs.isEmpty {
                designBridge.applyLocalEdit(nodesJSON: "[]", instruction: inputText.isEmpty ? "修改选中元素" : inputText)
            } else {
                inputText = "请选中画布上的元素后使用精准修改技能"
            }
        case "partial_edit":
            let instruction = inputText.isEmpty ? "优化选中节点的视觉样式" : inputText
            designBridge.skillPartialEdit(nodesJSON: "[]", instruction: instruction)
        case "sim_panel":
            let prompt = inputText.isEmpty ? "生成风格变体" : inputText
            designBridge.skillSimPanel(prompt: prompt)
        case "spec_doc":
            let prompt = inputText.isEmpty ? "输出完整设计规范" : inputText
            designBridge.skillSpecDoc(prompt: prompt)
        case "page_flow":
            let prompt = inputText.isEmpty ? "首页→列表→详情的导航流程" : inputText
            designBridge.skillPageFlow(prompt: prompt)
        default:
            inputText = "使用\(tmpl.name)技能: \(inputText)"
            sendChat()
        }
    }

    private func messageBubble(_ msg: DesignMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "你" : "设计师")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)

                if isUser {
                    Text(msg.content)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .padding(theme.spacingM)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.accent.opacity(0.15))
                        )
                } else {
                    assistantContent(msg)
                }

                if msg.artifactInfo != nil {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                        Text("已解析: \(msg.artifactInfo!.title)")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func assistantContent(_ msg: DesignMessage) -> some View {
        if msg.artifactInfo != nil {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                    Text(msg.artifactInfo!.title)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text(msg.artifactInfo!.type.uppercased())
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(theme.accent.opacity(0.15))
                        )
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
        } else {
            let displayText = stripArtifactTags(msg.content)
            if !displayText.isEmpty {
                Text(displayText)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.groupBg)
                    )
            }
        }
    }

    private func stripArtifactTags(_ content: String) -> String {
        var result = content
        if let openRange = result.range(of: "<antArtifact") {
            if let closeTag = result.range(of: "</antArtifact>", range: openRange.lowerBound..<result.endIndex) {
                result = String(result[..<openRange.lowerBound]) + String(result[closeTag.upperBound...])
            }
        }
        result = result.replacingOccurrences(of: "```html\n", with: "")
        result = result.replacingOccurrences(of: "```\n", with: "")
        result = result.replacingOccurrences(of: "```", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inputArea: some View {
        VStack(spacing: theme.spacingS) {
            if !designBridge.marqueeSelectedNodeIDs.isEmpty {
                marqueeEditBanner
            }

            if let error = designBridge.errorMessage {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, theme.spacingM)
            }

            HStack(spacing: theme.spacingS) {
                TextField("描述你想设计的界面...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .lineLimit(1...5)
                    .onSubmit { sendChat() }

                Button(action: { sendChat() }) {
                    Image(systemName: designBridge.isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(designBridge.isGenerating ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty && !designBridge.isGenerating)
                .help(designBridge.isGenerating ? "停止" : "发送")
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)

            if !designBridge.currentArtifactCode.isEmpty && !designBridge.isGenerating {
                actionBar
            }
        }
        .padding(.bottom, theme.spacingS)
    }

    private var actionBar: some View {
        VStack(spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingS) {
                Button(action: { saveArtifact() }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: theme.iconS))
                        Text(designBridge.artifactSaved ? "已保存" : "保存")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                    }
                    .foregroundStyle(designBridge.artifactSaved ? .green : theme.accent)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(designBridge.artifactSaved ? Color.green : theme.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(designBridge.artifactSaved)

                Button(action: { designBridge.copyCurrentCode() }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: theme.iconS))
                        Text("复制代码")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.groupBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if !designBridge.artifactId.isEmpty {
                    Button(action: {
                        showVersionHistory.toggle()
                        if showVersionHistory {
                            Task { await designBridge.loadVersionHistory() }
                        }
                    }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: theme.iconS))
                            Text("历史")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(showVersionHistory ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(showVersionHistory ? theme.accent : theme.groupBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !designBridge.currentArtifactCode.isEmpty {
                    Button(action: { exportSwiftUI() }) {
                        HStack(spacing: theme.spacingXS) {
                            if designBridge.isExportingSwiftUI {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "swift")
                                    .font(.system(size: theme.iconS))
                            }
                            Text(designBridge.isExportingSwiftUI ? "导出中" : "SwiftUI")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.groupBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(designBridge.isExportingSwiftUI)

                    Menu {
                        Button("HTML") {
                            Task { await exportCodegen(target: "html") }
                        }
                        Button("React + Tailwind") {
                            Task { await exportCodegen(target: "react-tailwind") }
                        }
                        Button("Tailwind only") {
                            Task { await exportCodegen(target: "tailwind-only") }
                        }
                    } label: {
                        HStack(spacing: theme.spacingXS) {
                            if designBridge.isExportingCodegen {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: theme.iconS))
                            }
                            Text(designBridge.isExportingCodegen ? "导出中" : "Code")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.groupBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(designBridge.isExportingCodegen)

                    Menu {
                        Button("SVG") {
                            Task { await batchExport(format: "svg") }
                        }
                        Button("HTML") {
                            Task { await batchExport(format: "html") }
                        }
                        Button("JSON") {
                            Task { await batchExport(format: "json") }
                        }
                    } label: {
                        HStack(spacing: theme.spacingXS) {
                            if designBridge.isBatchExporting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: theme.iconS))
                            }
                            Text(designBridge.isBatchExporting ? "导出中" : "导出")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.groupBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(designBridge.isBatchExporting)
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)

            if showVersionHistory && !designBridge.artifactId.isEmpty {
                versionHistoryList
            }
        }
    }

    private var versionHistoryList: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if designBridge.isLoadingHistory {
                ProgressView()
                    .controlSize(.small)
            } else if designBridge.versionHistory.isEmpty {
                Text("暂无版本记录")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingS)
            } else {
                ForEach(Array(designBridge.versionHistory.enumerated()), id: \.offset) { idx, ver in
                    HStack(spacing: theme.spacingXS) {
                        Text("v\(ver["version"] as? Int ?? idx + 1)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                        if let ts = ver["created_at"] as? String {
                            Text(ts)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("回退") {
                            let v = ver["version"] as? Int ?? (idx + 1)
                            Task { await designBridge.rollbackToVersion(v) }
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.groupBg)
                    )
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
    }

    private func sendChat() {
        guard !inputText.isEmpty || designBridge.isGenerating else { return }
        if designBridge.isGenerating {
            chatPanelLog.info("DesignChatPanel: stop requested (not supported in current streaming)")
            return
        }

        if !appState.isMLXRunning {
            designBridge.errorMessage = "MLX 服务未运行，请先在 MLX 面板启动服务后再发送"
            chatPanelLog.warning("DesignChatPanel: send blocked - MLX not running")
            return
        }

        // 如果有框选节点，走 local-edit 流程
        if !designBridge.marqueeSelectedNodeIDs.isEmpty {
            let nodeIDs = designBridge.marqueeSelectedNodeIDs
            let instruction = inputText
            inputText = ""
            let nodesJSON = buildNodesJSON(from: nodeIDs)
            designBridge.applyLocalEdit(nodesJSON: nodesJSON, instruction: instruction)
            designBridge.marqueeSelectedNodeIDs = []
            return
        }

        let message = inputText
        inputText = ""
        Task {
            await designBridge.sendDesignChat(message)
        }
    }

    private func buildNodesJSON(from nodeIDs: [String]) -> String {
        guard let penDocJSON = designBridge.lastRenderedDocumentJSON,
              let data = penDocJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pages = json["pages"] as? [[String: Any]] else {
            return "[]"
        }
        var nodes: [[String: Any]] = []
        let pageIndex = designBridge.currentPageIndex
        if pageIndex >= 0 && pageIndex < pages.count,
           let pageDict = pages[pageIndex] as? [String: Any],
           let allNodes = pageDict["nodes"] as? [[String: Any]] {
            for node in allNodes {
                if let id = node["id"] as? String, nodeIDs.contains(id) {
                    nodes.append(node)
                }
            }
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: nodes, options: []),
           let str = String(data: jsonData, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    private func saveArtifact() {
        Task {
            await designBridge.saveAsArtifact()
        }
    }

    private func exportSwiftUI() {
        Task {
            await designBridge.exportAsSwiftUI()
        }
    }

    private func exportCodegen(target: String) async {
        let name = designBridge.currentArtifactTitle.isEmpty ? "MyComponent" : designBridge.currentArtifactTitle
        await designBridge.exportAsCodegen(target: target, componentName: name)
    }

    // MARK: - Page List

    private var marqueeEditBanner: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "selection.pin.in.out")
                .font(.system(size: theme.iconS))
                .foregroundColor(theme.accent)
            Text("已框选 \(designBridge.marqueeSelectedNodeIDs.count) 个节点")
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.text)
            Spacer()
            Button(action: {
                designBridge.marqueeSelectedNodeIDs = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.accentSoft)
        )
        .padding(.horizontal, theme.spacingM)
    }

    private var planPreviewBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "eye")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("预览: \(designBridge.pendingPlanTitle)")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text("AI 建议的更改，确认后写入画布")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button("拒绝") {
                designBridge.rejectPlan()
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(theme.groupBorder, lineWidth: 1)
            )
            Button("确认") {
                designBridge.acceptPlan()
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentText)
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.accent)
            )
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.accentSoft)
    }

    private var pageListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("页面")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button(action: { designBridge.addPage() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help("新建页面")
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)

            if designBridge.pages.isEmpty {
                Text("暂无页面，生成设计后自动创建")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textQuaternary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingM)
            } else {
                ForEach(designBridge.pages.indices, id: \.self) { index in
                    let page = designBridge.pages[index]
                    let isCurrent = index == designBridge.currentPageIndex
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 10))
                            .foregroundStyle(isCurrent ? theme.accent : theme.textTertiary)
                        Text(page.title)
                            .font(.system(size: theme.footnoteSize, weight: isCurrent ? .medium : .regular))
                            .foregroundStyle(isCurrent ? theme.text : theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        if page.artifactId.isEmpty {
                            Circle().fill(theme.amberDot).frame(width: 6, height: 6)
                        }
                        Button(action: { designBridge.deletePage(at: index) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("删除页面")
                        .opacity(isCurrent ? 1 : 0.5)
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(isCurrent ? theme.selBg : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { designBridge.switchToPage(at: index) }
                }
            }
        }
        .padding(.vertical, theme.spacingXS)
    }

    private var batchExportSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("批量导出")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("关闭") {
                    showBatchExport = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            if designBridge.isBatchExporting {
                VStack(spacing: theme.spacingM) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("正在导出...")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !designBridge.batchExportResult.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                        Text(designBridge.batchExportResult)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                    }
                    .padding(theme.spacingM)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 36))
                        .foregroundStyle(theme.textTertiary)
                    Text("选择导出格式")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    HStack(spacing: theme.spacingM) {
                        Button("SVG") { Task { await batchExport(format: "svg") } }
                            .buttonStyle(.plain)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingS)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.accent, lineWidth: 1))
                            .foregroundStyle(theme.accent)
                        Button("HTML") { Task { await batchExport(format: "html") } }
                            .buttonStyle(.plain)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingS)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.accent, lineWidth: 1))
                            .foregroundStyle(theme.accent)
                        Button("JSON") { Task { await batchExport(format: "json") } }
                            .buttonStyle(.plain)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingS)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.accent, lineWidth: 1))
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 420, height: 320)
        .background(theme.windowBg)
    }

    private func batchExport(format: String) async {
        let downloadsDir = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "/tmp"
        let outDir = (downloadsDir as NSString).appendingPathComponent("fusion-design-export")
        await designBridge.batchExportPages(format: format, to: outDir)
        if !designBridge.batchExportResult.isEmpty {
            showBatchExport = true
        }
    }

    // MARK: - Inference Progress Views

    private var inferenceStepLabel: String {
        switch designBridge.inferenceStep {
        case "connecting": return "连接中..."
        case "generating": return "推理中..."
        case "streaming": return "生成中..."
        case "rendering": return "渲染画布..."
        default: return "生成中..."
        }
    }

    private var inferenceStepIcon: some View {
        Group {
            switch designBridge.inferenceStep {
            case "connecting":
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
            case "generating":
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            case "streaming":
                Image(systemName: "text.cursor")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            case "rendering":
                Image(systemName: "paintbrush.pointed")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            default:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var inferenceProgressBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingXS) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text(inferenceStepLabel)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if designBridge.streamTokenCount > 0 {
                        Text("\(designBridge.streamTokenCount) tokens")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                if !designBridge.streamPreviewText.isEmpty {
                    Text(designBridge.streamPreviewText)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                inferenceStepBar
            }
            Spacer(minLength: 40)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.groupBg)
        )
        .id("inference-progress")
    }

    private var inferenceStepBar: some View {
        let steps = [
            ("connecting", "连接"),
            ("generating", "推理"),
            ("streaming", "生成"),
            ("rendering", "渲染"),
        ]
        let stepOrder = ["connecting", "generating", "streaming", "rendering"]
        let currentIdx = stepOrder.firstIndex(of: designBridge.inferenceStep) ?? 0

        return HStack(spacing: theme.spacingXS) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(spacing: 2) {
                    if idx < currentIdx {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    } else if idx == currentIdx {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(theme.textQuaternary)
                            .frame(width: 6, height: 6)
                    }
                    Text(step.1)
                        .font(.system(size: 8))
                        .foregroundStyle(idx <= currentIdx ? theme.text : theme.textTertiary)
                }
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(idx < currentIdx ? theme.accent : theme.groupBorder)
                        .frame(width: 12, height: 1)
                }
            }
        }
    }
}
