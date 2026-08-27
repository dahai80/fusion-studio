// F-I7: CodeEditorView.swift 拆分 — 聊天内容渲染组件群。
// 迁自 CodeEditorView.swift: ChatContentView / WelcomeCard / RecentProjectRow / SuggestionCard / MessageBubble。
// MessageBubble 引用 CodeAgent.CodeMessage (嵌套类型, 随 CodeAgent 迁在 ProjectWorkspace.swift)。

import SwiftUI

// MARK: - Chat Content View

struct ChatContentView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if agent.conversation.isEmpty {
                        welcomeContent
                    }

                    ForEach(agent.conversation) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }

                    if agent.isThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text(i18n.t(.fc_thinking)).font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    Spacer().frame(height: 8)
                }
            }
            .onChange(of: agent.conversation.count) { _, _ in
                withAnimation { proxy.scrollTo(agent.conversation.last?.id, anchor: .bottom) }
            }
            .onChange(of: agent.scrollToMessageId) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { agent.scrollToMessageId = nil }
            }
        }
        .background(theme.inputBg)
    }

    private var welcomeContent: some View {
        VStack(spacing: theme.spacingL) {
            Spacer().frame(height: 40)
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent)
            Text(i18n.t(.fc_welcome_title))
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(i18n.t(.fc_welcome_tagline))
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingM) {
                WelcomeCard(icon: "folder.badge.plus", title: i18n.t(.fc_wc_open_title), desc: i18n.t(.fc_wc_open_desc), accent: true) {
                    workspace.openLocalFolder()
                }
                WelcomeCard(icon: "questionmark.circle", title: i18n.t(.fc_wc_explain_title), desc: i18n.t(.fc_wc_explain_desc)) {
                    agent.askAI(prompt: "Explain the code in the current file")
                }
                WelcomeCard(icon: "ant", title: i18n.t(.fc_wc_review_title), desc: i18n.t(.fc_wc_review_desc)) {
                    agent.askAI(prompt: "Review the code for bugs and issues")
                }
                WelcomeCard(icon: "testtube.2", title: i18n.t(.fc_wc_test_title), desc: i18n.t(.fc_wc_test_desc)) {
                    agent.askAI(prompt: "Write unit tests for the code")
                }
            }
            .padding(.horizontal, theme.spacingXL)

            if !workspace.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.fc_recent))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .padding(.horizontal, theme.spacingXL)

                    ForEach(workspace.recentProjects.prefix(5)) { recent in
                        RecentProjectRow(project: recent) {
                            workspace.openRecent(recent)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Welcome Card

struct WelcomeCard: View {
    let icon: String
    let title: String
    let desc: String
    var accent: Bool = false
    let action: () -> Void
    @Environment(\.studioTheme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(accent ? theme.accent : theme.textSecondary)
                Text(title)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingM)
            .background(accent ? theme.accentSoft : theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(accent ? theme.accent.opacity(0.3) : theme.inputBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Project Row

struct RecentProjectRow: View {
    let project: RecentProject
    let action: () -> Void
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeTime(project.lastOpened))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return String(format: i18n.t(.fc_min_ago), Int(interval / 60)) }
        if interval < 86400 { return String(format: i18n.t(.fc_hour_ago), Int(interval / 3600)) }
        if interval < 604800 { return String(format: i18n.t(.fc_day_ago), Int(interval / 86400)) }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Suggestion Card (backward compat)

struct SuggestionCard: View {
    @Environment(\.studioTheme) private var theme
    let icon: String; let title: String; let desc: String; let prompt: String
    @StateObject private var agent = CodeAgent.shared

    var body: some View {
        Button(action: { agent.askAI(prompt: prompt) }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11, weight: .medium))
                Text(desc).font(.system(size: 9)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(theme.surfaceSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: CodeAgent.CodeMessage
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if message.role == "user" {
                    Spacer()
                    Text(i18n.t(.fc_you)).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                } else {
                    Text("Fusion Code").font(.system(size: 11, weight: .medium)).foregroundColor(.accentColor)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text(message.content)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(message.role == "user" ? Color.accentColor.opacity(0.05) : Color.clear)
    }
}
