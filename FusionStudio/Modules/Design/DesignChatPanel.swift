// Callers: DesignView — left panel of 3-column layout for design chat interaction
// Affected API: DesignChatPanel View (reads DesignBridge via @EnvironmentObject), DesignBridge.addPage/switchToPage
// Data schemas: DesignMessage, DesignPage (id/artifactId/title/type/code/createdAt), DesignBridge.pages
// User instruction: "continue" — Phase 3 Task #34 multi-page design

import SwiftUI
import os.log

private let chatPanelLog = Logger(subsystem: "com.fusion.studio", category: "DesignChatPanel")

struct DesignChatPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var inputText: String = ""
    @State private var showQuickTemplates: Bool = false
    @State private var showVersionHistory: Bool = false
    @State private var autoScroll: Bool = true
    @State private var showPageList: Bool = false
    @State private var showSwiftUIExport: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(theme.separator).frame(height: 1)

            if showPageList {
                pageListView
                Rectangle().fill(theme.separator).frame(height: 1)
            }

            messageList

            Rectangle().fill(theme.separator).frame(height: 1)
            inputArea
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        .sheet(isPresented: $showSwiftUIExport) {
            swiftUIExportSheet
        }
        .onChange(of: designBridge.exportedSwiftUICode) {
            if !designBridge.exportedSwiftUICode.isEmpty && !showSwiftUIExport {
                showSwiftUIExport = true
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
                    Text("生成中...")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.accent)
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
                .help("复制代码")
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
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacingXS), count: 2),
            spacing: theme.spacingXS
        ) {
            ForEach(DesignPrompts.quickTemplates) { tmpl in
                Button(action: {
                    inputText = tmpl.prompt
                    sendChat()
                }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: tmpl.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                        Text(tmpl.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.groupBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.groupBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingS)
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
        let message = inputText
        inputText = ""
        Task {
            await designBridge.sendDesignChat(message)
        }
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

    // MARK: - Page List

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
}
