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
    @EnvironmentObject var healthState: HealthState
    @EnvironmentObject var agentBridge: AgentBridge

    @State private var inputText: String = ""
    @State private var showQuickTemplates: Bool = false
    @State private var showVersionHistory: Bool = false
    @State private var autoScroll: Bool = true
    @State private var showPageList: Bool = false
    @State private var showSwiftUIExport: Bool = false
    @State private var showCodegenExport: Bool = false
    @State private var showBatchExport: Bool = false
    @State private var refocusTrigger: Int = 0
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()
    @StateObject private var i18n = I18nManager.shared

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

                if let error = designBridge.errorMessage {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.top, theme.spacingS)
                }

                Rectangle().fill(theme.separator).frame(height: 1)
                designInputCard
            } else {
                welcomeContent
                Rectangle().fill(theme.separator).frame(height: 1)
                designInputCard
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
            if !healthState.isMLXRunning {
                Task {
                    let ok = await agentBridge.probeMLXRunningStatus()
                    await MainActor.run {
                        healthState.isMLXRunning = ok
                    }
                }
            }
        }
    }

    private var swiftUIExportSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.design_swiftUITitle))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(i18n.t(.design_copy)) {
                    designBridge.copyExportedSwiftUI()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                Button(i18n.t(.design_close)) {
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
                Text(i18n.t(.design_codegenTitle))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(i18n.t(.design_copy)) {
                    designBridge.copyExportedCodegen()
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                Button(i18n.t(.design_close)) {
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
            .help(i18n.t(.design_helpPageMgmt))

            if !designBridge.currentArtifactCode.isEmpty {
                Button(action: { designBridge.copyCurrentCode() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help(i18n.t(.design_helpCopyCode))

                Button(action: { showCodegenExport = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .help(i18n.t(.design_helpExportCode))
            }

            Button(action: { designBridge.clearConversation() }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.design_helpClear))
            .disabled(designBridge.messages.isEmpty)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var welcomeContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 40))
                .foregroundStyle(theme.textQuaternary)

            Text("Fusion Design")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.text)
                .padding(.top, theme.spacingM)

            Text(i18n.t(.design_welcomeDesc))
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, theme.spacingS)

            quickTemplateGrid
                .padding(.top, theme.spacingL)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var designInputCard: some View {
        VStack(spacing: 0) {
            if !designBridge.marqueeSelectedNodeIDs.isEmpty {
                marqueeEditBanner
                    .padding(.horizontal, theme.spacingM)
                    .padding(.top, theme.spacingS)
            }

            VStack(spacing: 0) {
                SendableTextEditor(
                    text: $inputText,
                    placeholder: i18n.t(.design_inputPh),
                    font: .systemFont(ofSize: CGFloat(theme.textSize)),
                    textColor: NSColor(theme.text),
                    placeholderColor: NSColor(theme.textTertiary),
                    maxHeight: 88,
                    onSend: { sendChat() },
                    refocusTrigger: $refocusTrigger
                )
                .frame(minHeight: 36, idealHeight: 44, maxHeight: 88)
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingM)

                Rectangle().fill(theme.separator.opacity(0.5)).frame(height: 1)

                inputToolbarRow
            }
            .frame(maxWidth: 680)
            .background(theme.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(theme.inputBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.contentBg)
    }

    private var inputToolbarRow: some View {
        HStack(spacing: theme.spacingS) {
            Menu {
                Button(action: { inputText = "" }) {
                    Label(i18n.t(.design_clearInput), systemImage: "xmark.circle")
                }
                Divider()
                Button(action: { designBridge.clearConversation() }) {
                    Label(i18n.t(.design_clearConv), systemImage: "trash")
                }
                .disabled(designBridge.messages.isEmpty)
                Divider()
                Button(action: { designBridge.copyCurrentCode() }) {
                    Label(i18n.t(.design_copyCurrentCode), systemImage: "doc.on.doc")
                }
                .disabled(designBridge.currentArtifactCode.isEmpty)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            if !designBridge.currentArtifactCode.isEmpty && !designBridge.isGenerating {
                Button(action: { saveArtifact() }) {
                    Image(systemName: designBridge.artifactSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(designBridge.artifactSaved ? .green : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(designBridge.artifactSaved)
                .help(i18n.t(.design_helpSave))

                Button(action: { designBridge.copyCurrentCode() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.design_helpCopy))

                if !designBridge.artifactId.isEmpty {
                    Button(action: {
                        showVersionHistory.toggle()
                        if showVersionHistory {
                            Task { await designBridge.loadVersionHistory() }
                        }
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(showVersionHistory ? theme.accent : theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(i18n.t(.design_helpHistory))
                }

                Button(action: { exportSwiftUI() }) {
                    if designBridge.isExportingSwiftUI {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "swift")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(designBridge.isExportingSwiftUI)
                .help(i18n.t(.design_helpSwiftUI))
            }

            Spacer()

            FusionModelPicker(scene: .artifacts, selection: $selectedModel, models: agentBridge.models, onChange: { id in
                designBridge.selectedModel = id
                chatPanelLog.info("Design model selected: \(id)")
            })

            VoiceInputButton(voice: voiceInput, text: $inputText, onSend: { sendChat() })

            if designBridge.isGenerating {
                Button(action: { sendChat() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.accentDestructive)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.design_helpStop))
            } else {
                Button(action: { sendChat() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(i18n.t(.design_helpSend))
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingM) {
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
                .padding(theme.spacingL)
            }
            .background(theme.contentBg)
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

            Text(i18n.t(.design_emptyTitle))
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)

            Text(i18n.t(.design_emptyDesc))
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
                            Text(group.localLabel)
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
                                        sendChat(explicitMessage: tmpl.prompt)
                                    }
                                }) {
                                    HStack(spacing: theme.spacingXS) {
                                        Image(systemName: tmpl.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(group == .skills ? theme.accent : theme.textSecondary)
                                        Text(tmpl.localName)
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
            let skillMsg = String(format: i18n.t(.design_skillUseFmt), tmpl.localName, inputText)
            inputText = skillMsg
            sendChat(explicitMessage: skillMsg)
        }
    }

    private func messageBubble(_ msg: DesignMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: theme.spacingS) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? i18n.t(.design_roleUser) : i18n.t(.design_roleDesigner))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(isUser ? theme.textTertiary : theme.accent)

                if isUser {
                    Text(msg.content)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .fill(theme.accent.opacity(0.12))
                        )
                } else {
                    assistantContent(msg)
                }

                if msg.artifactInfo != nil {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(.green)
                        Text(String(format: i18n.t(.design_parsedFmt), msg.artifactInfo!.title))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            if !isUser { Spacer(minLength: 60) }
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
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
        } else {
            let displayText = stripArtifactTags(msg.content)
            if !displayText.isEmpty {
                Text((try? AttributedString(markdown: displayText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(displayText))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                    .tint(theme.accent)
                    .textSelection(.enabled)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.surfaceSecondary)
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


    private var versionHistoryList: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if designBridge.isLoadingHistory {
                ProgressView()
                    .controlSize(.small)
            } else if designBridge.versionHistory.isEmpty {
                Text(i18n.t(.design_noVersions))
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
                        Button(i18n.t(.design_rollback)) {
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

    private func sendChat(explicitMessage: String? = nil) {
        let message = explicitMessage ?? inputText
        DesignPreviewTrace.log("sendChat: called explicitNil=\(explicitMessage == nil) msgLen=\(message.count) isGenerating=\(designBridge.isGenerating) isMLXRunning=\(healthState.isMLXRunning)")
        guard !message.isEmpty || designBridge.isGenerating else { return }
        if designBridge.isGenerating {
            chatPanelLog.info("DesignChatPanel: stop requested (not supported in current streaming)")
            return
        }

        if !healthState.isMLXRunning {
            Task {
                let ok = await agentBridge.probeMLXRunningStatus()
                await MainActor.run { healthState.isMLXRunning = ok }
                DesignPreviewTrace.log("sendChat: live probe isMLXRunning=\(healthState.isMLXRunning)")
                if ok {
                    await MainActor.run { proceedToSend(message: message) }
                } else {
                    await MainActor.run {
                        designBridge.errorMessage = i18n.t(.design_errMLXNotRunning)
                        chatPanelLog.warning("DesignChatPanel: send blocked - MLX not running (live probe failed)")
                    }
                }
            }
            return
        }

        proceedToSend(message: message)
    }

    private func proceedToSend(message: String) {
        // 如果有框选节点，走 local-edit 流程
        if !designBridge.marqueeSelectedNodeIDs.isEmpty {
            let nodeIDs = designBridge.marqueeSelectedNodeIDs
            let instruction = message
            inputText = ""
            let nodesJSON = buildNodesJSON(from: nodeIDs)
            designBridge.applyLocalEdit(nodesJSON: nodesJSON, instruction: instruction)
            designBridge.marqueeSelectedNodeIDs = []
            return
        }

        // 发送前校验模型：空则提示且保留输入内容，避免清空后用户无法重试
        let cfg = FusionConfig.shared
        let resolvedModel = selectedModel.isEmpty ? cfg.defaultModel(for: .code) : selectedModel
        if resolvedModel.isEmpty {
            designBridge.errorMessage = i18n.t(.design_errNoModel)
            chatPanelLog.warning("DesignChatPanel: send aborted - no model selected")
            return
        }
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
            Text(String(format: i18n.t(.design_marqueeFmt), designBridge.marqueeSelectedNodeIDs.count))
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
                Text(String(format: i18n.t(.design_previewFmt), designBridge.pendingPlanTitle))
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.design_previewHint))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button(i18n.t(.design_reject)) {
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
            Button(i18n.t(.design_accept)) {
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
                Text(i18n.t(.design_pages))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button(action: { designBridge.addPage() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.design_newPage))
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)

            if designBridge.pages.isEmpty {
                Text(i18n.t(.design_noPages))
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
                        .help(i18n.t(.design_deletePage))
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
                Text(i18n.t(.design_batchExport))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(i18n.t(.design_close)) {
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
                    Text(i18n.t(.design_exporting))
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
                    Text(i18n.t(.design_selectFormat))
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
        case "connecting": return i18n.t(.design_stepConnecting)
        case "generating": return i18n.t(.design_stepGenerating)
        case "streaming": return i18n.t(.design_stepStreaming)
        case "rendering": return i18n.t(.design_stepRendering)
        default: return i18n.t(.design_stepStreaming)
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
            Spacer(minLength: 60)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
        .id("inference-progress")
    }

    private var inferenceStepBar: some View {
        let steps = [
            ("connecting", i18n.t(.design_stepConnShort)),
            ("generating", i18n.t(.design_stepGenShort)),
            ("streaming", i18n.t(.design_stepStreamShort)),
            ("rendering", i18n.t(.design_stepRenderShort)),
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
