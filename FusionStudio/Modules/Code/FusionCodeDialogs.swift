import SwiftUI
import os.log

private let fcdLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeDialogs")

// MARK: - Slash Command Popup Menu

struct FCSlashCommandMenu: View {
    let filter: String
    let onSelect: (FCSlashCommand) -> Void
    @Environment(\.studioTheme) private var theme

    private var filtered: [FCSlashCommand] {
        guard !filter.isEmpty else { return FC_SLASH_COMMANDS }
        return FC_SLASH_COMMANDS.filter {
            $0.name.localizedCaseInsensitiveContains(filter) ||
            $0.description.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filtered.isEmpty {
                Text("No matching commands")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingM)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { cmd in
                            Button {
                                onSelect(cmd)
                            } label: {
                                HStack(spacing: theme.spacingS) {
                                    Image(systemName: cmd.icon)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.accent)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cmd.shortcut)
                                            .font(.system(size: theme.footnoteSize, weight: .medium))
                                            .foregroundStyle(theme.text)
                                        Text(cmd.description)
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.textSecondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, theme.spacingM)
                                .padding(.vertical, theme.spacingS)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 280)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        )
    }
}

// MARK: - Create Session Dialog

struct FCCreateSessionDialog: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var sessions: [FCSession]
    @Binding var currentSessionId: String?
    let cwd: String?
    let fcBridge: FusionCodeBridge

    @State private var sessionTitle = ""
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text("New Session")
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("Title")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    TextField("Session title", text: $sessionTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize))
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.inputBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                )
                        )
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)

                Button("Create") {
                    createSession()
                }
                .buttonStyle(.plain)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
                .disabled(sessionTitle.isEmpty || isCreating)
                .opacity(sessionTitle.isEmpty ? 0.5 : 1.0)
            }
        }
        .padding(theme.spacing2XL)
        .frame(width: 380)
        .background(theme.contentBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }

    private func createSession() {
        isCreating = true
        Task {
            do {
                let context = try await fcBridge.projectContext(cwd: cwd ?? "")
                let sessionId = context["session_id"] as? String ?? UUID().uuidString
                let session = FCSession(
                    id: sessionId,
                    title: sessionTitle,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    cwd: cwd ?? "",
                    messageCount: 0
                )
                await MainActor.run {
                    sessions.append(session)
                    currentSessionId = sessionId
                    dismiss()
                    fcdLog.info("Session created: \(sessionId)")
                }
            } catch {
                fcdLog.error("Failed to create session: \(error.localizedDescription)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Permission Detail Panel

struct FCPermissionDetailPanel: View {
    let request: FCPermissionRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(request.tier == .tier2 ? theme.amberDot : theme.blueDot)
                Text("Permission Request")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text("Tool:")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(request.tool)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.accent.opacity(0.1)))
                }

                Text(request.description)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)

                if !request.args.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(Array(request.args.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top) {
                                Text(key)
                                    .font(.system(size: theme.captionSize, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                    .frame(width: 100, alignment: .trailing)
                                Text(String(describing: request.args[key] ?? "").prefix(120))
                                    .font(.system(size: theme.captionSize, design: .monospaced))
                                    .foregroundStyle(theme.text)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.codeBg))
                }
            }

            HStack {
                Spacer()
                Button("Deny") { onDeny() }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.redDot)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.errorBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.accentDestructive.opacity(0.3), lineWidth: 1)
                            )
                    )

                Button("Approve") { onApprove() }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent)
                    )
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        )
    }
}
