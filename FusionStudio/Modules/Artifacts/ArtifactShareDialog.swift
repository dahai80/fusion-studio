import SwiftUI
import os.log

private let shareLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactShare")

struct ArtifactShareDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let artifactId: String
    let artifactName: String

    @State private var shareLink = ""
    @State private var permission: String = "view"
    @State private var expiresIn: String = "7d"
    @State private var isGenerating = false
    @State private var copiedLink = false
    @State private var shares: [[String: Any]] = []
    @State private var isLoadingShares = false

    private var permissionOptions: [(String, String)] {
        [("view", i18n.t(.art_sd_permView)), ("comment", i18n.t(.art_sd_permComment)), ("edit", i18n.t(.art_sd_permEdit))]
    }
    private var expiryOptions: [(String, String)] {
        [("1h", i18n.t(.art_sd_exp1h)), ("1d", i18n.t(.art_sd_exp1d)), ("7d", i18n.t(.art_sd_exp7d)), ("30d", i18n.t(.art_sd_exp30d)), ("never", i18n.t(.art_sd_expNever))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    createSection
                    if !shareLink.isEmpty {
                        linkResult
                    }
                    if !shares.isEmpty {
                        existingShares
                    }
                }
                .padding(theme.spacingL)
            }
        }
        .frame(width: 500)
        .frame(minHeight: 350)
        .onAppear { loadExistingShares() }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t(.art_sd_title))
                    .font(.system(size: theme.textSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(artifactName)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.art_sd_permission))
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                HStack(spacing: theme.spacingS) {
                    ForEach(permissionOptions, id: \.0) { opt in
                        Button(action: { permission = opt.0 }) {
                            Text(opt.1)
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(permission == opt.0 ? theme.accentText : theme.textSecondary)
                                .padding(.horizontal, theme.spacingS)
                                .padding(.vertical, theme.spacingXS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(permission == opt.0 ? theme.accent : theme.surfaceSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.art_sd_expiry))
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingS) {
                        ForEach(expiryOptions, id: \.0) { opt in
                            Button(action: { expiresIn = opt.0 }) {
                                Text(opt.1)
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(expiresIn == opt.0 ? theme.accentText : theme.textSecondary)
                                    .padding(.horizontal, theme.spacingS)
                                    .padding(.vertical, theme.spacingXS)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .fill(expiresIn == opt.0 ? theme.accent : theme.surfaceSecondary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                if shareLink.isEmpty {
                    Button(action: generateShareLink) {
                        HStack(spacing: 4) {
                            if isGenerating { ProgressView().controlSize(.small) }
                            Text(i18n.t(.art_sd_generate))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                } else {
                    Button(i18n.t(.art_sd_done)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var linkResult: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.art_sd_shareLink))
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.art_sd_shareLink), text: .constant(shareLink))
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.inputBorder, lineWidth: 1))
                Button(action: copyLink) {
                    Image(systemName: copiedLink ? "checkmark" : "doc.on.doc")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(copiedLink ? theme.accent : theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var existingShares: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(String(format: i18n.t(.art_sd_existingShares), shares.count))
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            ForEach(shares.indices, id: \.self) { idx in
                shareRow(shares[idx])
            }
        }
    }

    private func shareRow(_ s: [String: Any]) -> some View {
        let shareId = s["share_id"] as? String ?? s["id"] as? String ?? ""
        let perm = s["permission"] as? String ?? "view"
        let expiresAt = s["expires_at"] as? String ?? i18n.t(.art_sd_expNever)
        let createdAt = s["created_at"] as? String ?? ""
        let isActive = s["is_active"] as? Bool ?? true

        return HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Circle()
                        .fill(isActive ? .green : .gray)
                        .frame(width: 6, height: 6)
                    Text(permLabel(perm))
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                HStack(spacing: theme.spacingXS) {
                    if !createdAt.isEmpty {
                        Text(formatTimestamp(createdAt))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    if expiresAt != i18n.t(.art_sd_expNever) {
                        Text(String(format: i18n.t(.art_sd_expires), formatTimestamp(expiresAt)))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            Spacer()
            Button(action: { revokeShare(shareId) }) {
                Text(i18n.t(.art_sd_revoke))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accentDestructive)
            }
            .buttonStyle(.plain)
            .disabled(!isActive)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
    }

    private func permLabel(_ p: String) -> String {
        switch p {
        case "view": return i18n.t(.art_sd_permView)
        case "comment": return i18n.t(.art_sd_permComment)
        case "edit": return i18n.t(.art_sd_permEdit)
        default: return p
        }
    }

    private func formatTimestamp(_ ts: String) -> String {
        guard !ts.isEmpty else { return "" }
        if ts.count > 19 {
            return String(ts.prefix(19)).replacingOccurrences(of: "T", with: " ")
        }
        return ts
    }

    private func loadExistingShares() {
        isLoadingShares = true
        Task {
            do {
                let r = try await ipc.artifactCall(method: "artifact.get_shared", params: [
                    "artifact_id": artifactId
                ])
                let items = r["shares"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                await MainActor.run { shares = items; isLoadingShares = false }
                shareLog.info("shares loaded: \(items.count)")
            } catch {
                shareLog.error("get_shared failed: \(error.localizedDescription)")
                await MainActor.run { isLoadingShares = false }
            }
        }
    }

    private func generateShareLink() {
        isGenerating = true
        Task {
            do {
                let result = try await ipc.artifactCall(method: "artifact.create_share", params: [
                    "artifact_id": artifactId,
                    "permission": permission,
                    "expires_in": expiresIn,
                ])
                if let link = result["share_url"] as? String {
                    await MainActor.run { shareLink = link }
                    shareLog.info("share link created for \(artifactId)")
                }
                loadExistingShares()
            } catch {
                shareLog.error("artifact.create_share failed: \(error.localizedDescription)")
            }
            await MainActor.run { isGenerating = false }
        }
    }

    private func revokeShare(_ shareId: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.revoke_share", params: [
                    "share_id": shareId
                ])
                shareLog.info("share revoked: \(shareId)")
                loadExistingShares()
            } catch {
                shareLog.error("revoke_share failed: \(error.localizedDescription)")
            }
        }
    }

    private func copyLink() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareLink, forType: .string)
        #endif
        copiedLink = true
        shareLog.info("share link copied")
    }
}
