import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 8: 批注子线程

struct SpaceCommentThread: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    let messageId: String

    @State private var comments: [SpaceComment] = []
    @State private var newComment = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_comment_title))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingL)

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(comments) { comment in
                            commentRow(comment)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                }
            }

            Divider()
            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.cw_comment_addPh), text: $newComment)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addComment() }
                Button(i18n.t(.cw_comment_send)) { addComment() }
                    .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(theme.spacingL)
        }
        .frame(width: 400, height: 400)
        .onAppear { loadComments() }
    }

    private func commentRow(_ comment: SpaceComment) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: "person.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(comment.authorName.isEmpty ? comment.authorId : comment.authorName)
                        .font(.system(size: theme.captionSize, weight: .semibold))
                    Text(comment.createdAt, style: .time)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(comment.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
            }
        }
        .padding(theme.spacingS)
    }

    private func addComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        newComment = ""
        Task {
            do {
                _ = try await ipc.spaceCommentCreate(
                    spaceId: spaceId, messageId: messageId,
                    authorId: "local_user", content: text
                )
                loadComments()
            } catch {
                spaceLog.error("comment.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadComments() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceCommentList(spaceId: spaceId, messageId: messageId)
                let items = result["comments"] as? [[String: Any]] ?? []
                await MainActor.run { comments = items.map { SpaceComment.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("comment.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

