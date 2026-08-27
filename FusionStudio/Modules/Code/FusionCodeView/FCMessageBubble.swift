import SwiftUI
import AppKit
import os.log

private let fcLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeView")

// MARK: - Message Bubble

struct FCMessageBubble: View {
    let message: FCChatMessage
    let onApplyCode: (String, String) -> Void
    let onApprove: (UUID) -> Void
    let onDeny: (UUID) -> Void
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        HStack(spacing: theme.spacingS) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                if message.role == "system" {
                    Text(message.content)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingXS)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.separator.opacity(0.3)))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if message.role == "assistant" {
                            FCMessageContentView(content: message.content, isStreaming: message.isStreaming)
                        } else {
                            Text(message.content)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(message.role == "user" ? theme.accent.opacity(0.12) : theme.surfaceElevated)
                    )

                    if message.role == "assistant" {
                        toolCallsView
                        codeApplyButtons
                    }
                }

                Text(message.timestamp, style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }

            if message.role == "assistant" {
                Spacer(minLength: 60)
            }
        }
    }

    private var toolCallsView: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ForEach(message.toolCalls) { tc in
                HStack(spacing: theme.spacingS) {
                    Image(systemName: toolIcon(tc.name))
                        .font(.system(size: 10))
                        .foregroundStyle(toolStatusColor(tc.status))

                    Text(tc.name)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.text)

                    Text(toolDescription(tc))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    toolStatusBadge(tc.status)

                    if tc.status == .pending {
                        Button(i18n.t(.fc_approve)) { onApprove(tc.id) }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.greenDot)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.successBg))

                        Button(i18n.t(.fc_deny)) { onDeny(tc.id) }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.redDot)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.errorBg))
                    }
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.codeBg))
            }
        }
    }

    private var codeApplyButtons: some View {
        let codeBlocks = extractCodeBlocks(message.content)
        return HStack(spacing: theme.spacingS) {
            ForEach(Array(codeBlocks.enumerated()), id: \.offset) { index, block in
                Button {
                    let lang = detectLanguageFromCode(block)
                    onApplyCode(block, lang)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10))
                        Text(codeBlocks.count > 1 ? String(format: i18n.t(.fc_apply_code_n), index + 1) : i18n.t(.fc_apply_code))
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "Edit", "edit", "Write", "write", "MultiEdit": return "pencil"
        case "Bash", "bash": return "terminal"
        case "Read", "read": return "doc.text"
        case "Glob", "glob": return "folder"
        case "Grep", "grep": return "magnifyingglass"
        default: return "wrench"
        }
    }

    private func toolStatusColor(_ status: FCToolStatus) -> Color {
        switch status {
        case .pending: return theme.amberDot
        case .running: return theme.blueDot
        case .approved: return theme.greenDot
        case .denied: return theme.redDot
        case .completed: return theme.greenDot
        case .failed: return theme.redDot
        }
    }

    private func toolStatusBadge(_ status: FCToolStatus) -> some View {
        Text(statusLabel(status))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(toolStatusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(toolStatusColor(status).opacity(0.1)))
    }

    private func statusLabel(_ status: FCToolStatus) -> String {
        switch status {
        case .pending: return I18nManager.shared.t(.fc_status_pending)
        case .running: return I18nManager.shared.t(.fc_status_running)
        case .approved: return I18nManager.shared.t(.fc_status_approved)
        case .denied: return I18nManager.shared.t(.fc_status_denied)
        case .completed: return I18nManager.shared.t(.fc_status_completed)
        case .failed: return I18nManager.shared.t(.fc_status_failed)
        }
    }

    private func toolDescription(_ tc: FCToolCall) -> String {
        switch tc.name {
        case "Edit", "edit":
            return tc.args["file_path"] as? String ?? tc.args["path"] as? String ?? ""
        case "Bash", "bash":
            let cmd = tc.args["command"] as? String ?? ""
            return String(cmd.prefix(40))
        default:
            return tc.args.values.first.map { String("\($0)".prefix(30)) } ?? ""
        }
    }

    private func extractCodeBlocks(_ content: String) -> [String] {
        var blocks: [String] = []
        let pattern = "```[\\w]*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return blocks }
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: range) {
            if let blockRange = Range(match.range(at: 1), in: content) {
                blocks.append(String(content[blockRange]))
            }
        }
        if blocks.isEmpty && (content.contains("func ") || content.contains("class ") || content.contains("import ")) {
            blocks.append(content)
        }
        return blocks
    }

    private func detectLanguageFromCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") { return "html" }
        if trimmed.hasPrefix("<?xml") { return "xml" }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        if trimmed.hasPrefix("#!") {
            if trimmed.contains("python") { return "python" }
            if trimmed.contains("bash") || trimmed.contains("zsh") { return "shell" }
        }
        if trimmed.hasPrefix("import ") {
            if trimmed.contains("SwiftUI") { return "swift" }
            if trimmed.contains("react") { return "javascript" }
        }
        if trimmed.hasPrefix("func ") || trimmed.hasPrefix("struct ") { return "swift" }
        if trimmed.hasPrefix("fn ") || trimmed.hasPrefix("impl ") { return "rust" }
        if trimmed.hasPrefix("def ") { return "python" }
        return "plaintext"
    }
}
