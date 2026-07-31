import SwiftUI
import os.log

private let shareLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactShare")

struct ArtifactShareDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let artifactId: String
    let artifactName: String

    @State private var shareLink = ""
    @State private var permission: String = "view"
    @State private var expiresIn: String = "7d"
    @State private var isGenerating = false
    @State private var copiedLink = false

    private let permissionOptions = [("view", "仅查看"), ("comment", "可评论"), ("edit", "可编辑")]
    private let expiryOptions = [("1h", "1 小时"), ("1d", "1 天"), ("7d", "7 天"), ("30d", "30 天"), ("never", "永不过期")]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("分享 Artifact")
                    .font(.system(size: theme.textSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(artifactName)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("权限")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
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
                Text("有效期")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
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

            if !shareLink.isEmpty {
                HStack(spacing: theme.spacingS) {
                    TextField("分享链接", text: .constant(shareLink))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                    Button(action: copyLink) {
                        Image(systemName: copiedLink ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                if shareLink.isEmpty {
                    Button(action: generateShareLink) {
                        HStack(spacing: 4) {
                            if isGenerating { ProgressView().controlSize(.small) }
                            Text("生成分享链接")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                } else {
                    Button("完成") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(theme.spacingM)
        .frame(width: 460)
    }

    private func generateShareLink() {
        isGenerating = true
        Task {
            do {
                let result = try await ipc.artifactCall(method: "artifact.share_create", params: [
                    "artifact_id": artifactId,
                    "permission": permission,
                    "expires_in": expiresIn,
                ])
                if let link = result["share_url"] as? String {
                    await MainActor.run { shareLink = link }
                    shareLog.info("share link created for \(artifactId)")
                }
            } catch {
                shareLog.error("artifact.share_create failed: \(error.localizedDescription)")
            }
            await MainActor.run { isGenerating = false }
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
