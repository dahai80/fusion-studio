// Callers: ModuleDetailView routing (case .code → CodeView).
// Affected API: CodeView, ProjectWorkspace, ProjectLoader, FileTreeView, OpenProjectSheet.
// Data schemas: CodeFile (added children/isExpanded/relativePath/fileSize), RecentProject, ProjectWorkspace.
//
// F-I7: 原 CodeEditorView.swift (76K, 1956 行, 19 类型) 拆为 8 功能区文件 (本批 batch 17c)。
// 拆分清单见同目录: CodeModels / ProjectWorkspace / CodeView / CodeProjectSheet /
//   CodeFileTreeViews / CodeGitSidebar / CodeChatViews / CodeTerminalView。
// 零行为改 — 纯代码搬运; 唯一改动 = codeEditLog 的 private 去掉 (跨文件 module-internal 共享, 匹配 ARCH-1 AgentModels.swift 先例)。

import SwiftUI
import AppKit
import os.log

let codeEditLog = Logger(subsystem: "com.fusion.studio", category: "FusionCode")

// MARK: - CodeView

struct CodeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var showSidebar = true
    @State private var sidebarTab: SidebarTab = .chat
    @State private var inputText = ""
    @State private var showOpenProject = false
    @State private var detectedGitURL: String?

    enum SidebarTab: String, CaseIterable {
        case chat = "Chat"
        case files = "Files"
        case git = "Git"
        case preview = "Design"

        var localLabel: String {
            switch self {
            case .chat: return I18nManager.shared.t(.fc_sidebar_chat)
            case .files: return I18nManager.shared.t(.fc_sidebar_files)
            case .git: return I18nManager.shared.t(.fc_sidebar_git)
            case .preview: return I18nManager.shared.t(.fc_sidebar_design)
            }
        }
    }

    var body: some View {
        HSplitView {
            if showSidebar {
                VStack(spacing: 0) {
                    sidebarTabBar
                    Divider()
                    switch sidebarTab {
                    case .chat:  ChatHistoryView()
                    case .files: FileTreeView()
                    case .git:   GitStatusView()
                    case .preview: CodeDesignPreviewPanel()
                    }
                }
                .frame(minWidth: 220, maxWidth: 300)
            }

            VStack(spacing: 0) {
                ChatContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                inputBar
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .sheet(isPresented: $showOpenProject) {
            OpenProjectSheet(workspace: workspace)
        }
        .onAppear {
            if workspace.hasProject {
                sidebarTab = .files
            }
        }
    }

    private var sidebarTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Button(action: { sidebarTab = tab }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 12))
                        Text(tab.localLabel).font(.system(size: 9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(sidebarTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
    }

    private func tabIcon(_ tab: SidebarTab) -> String {
        switch tab {
        case .chat: return "message"
        case .files: return workspace.hasProject ? "folder.fill" : "folder"
        case .git: return "arrow.triangle.branch"
        case .preview: return "paintbrush"
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let gitURL = detectedGitURL {
                GitURLDetectionBar(url: gitURL) {
                    detectedGitURL = nil
                } onSendAsText: {
                    inputText = detectedGitURL ?? ""
                    detectedGitURL = nil
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help(i18n.t(.fc_toggle_sidebar))

                TextField(i18n.t(.fc_input_ask_anything), text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...6)
                    .onSubmit { sendMessage() }
                    .onChange(of: inputText) { _, newValue in
                        detectGitURL(newValue)
                    }

                Button(action: { showAttachMenu() }) {
                    Image(systemName: "paperclip")
                }
                .buttonStyle(.borderless)
                .help(i18n.t(.fc_attach_file))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || agent.isThinking)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let context = agent.buildContextString()
        agent.askAI(prompt: text, context: context)
        inputText = ""
        detectedGitURL = nil
    }

    private func detectGitURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("https://github.com/") || trimmed.hasPrefix("https://gitlab.com/") || trimmed.hasPrefix("https://bitbucket.org/") {
            if trimmed.hasSuffix(".git") || trimmed.split(separator: "/").count >= 5 {
                detectedGitURL = trimmed
            }
        } else {
            detectedGitURL = nil
        }
    }

    private func showAttachMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: I18nManager.shared.t(.fc_menu_add_folder), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: I18nManager.shared.t(.fc_menu_add_file), action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: I18nManager.shared.t(.fc_menu_add_github), action: nil, keyEquivalent: "")

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

// MARK: - Git URL Detection Bar

struct GitURLDetectionBar: View {
    let url: String
    let onClone: () -> Void
    let onSendAsText: () -> Void
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "link")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t(.fc_git_url_detected))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(url)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            FusionButton(i18n.t(.fc_clone), icon: "arrow.down.circle", style: .tinted, size: .small, action: onClone)
            FusionButton(i18n.t(.fc_send), icon: "paperplane", style: .ghost, size: .small, action: onSendAsText)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.accentSoft)
        .transition(theme.transitionScale)
    }
}
