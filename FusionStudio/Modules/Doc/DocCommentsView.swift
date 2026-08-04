// Callers: DocView (comments tab in DocSubTab).
// Affected API: DocBridge.fetchComments / .createComment / .deleteComment → REST /api/pages/:id/comments, /api/comments/:id on localhost:11449.
// Data schemas: DocComment (id/page_id/content/parent_id/created_at from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let commentsLog = Logger(subsystem: "com.fusion.studio", category: "DocComments")

struct DocCommentsView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @State private var newComment = ""
    @State private var replyTo: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let pid = selectedPageId {
                commentList
                Divider()
                inputBar(pid)
            } else {
                emptyState
            }
        }
        .background(theme.surfacePrimary)
        .onChange(of: selectedPageId) { newId in
            if let id = newId {
                bridge.fetchComments(pageId: id) { _ in }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(theme.accent)
            Text("评论")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(bridge.comments.count)")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var commentList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(bridge.comments) { comment in
                    commentCard(comment)
                }
                if bridge.comments.isEmpty {
                    Text("暂无评论")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(12)
        }
    }

    private func commentCard(_ comment: DocComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(theme.accent)
                    .font(.caption)
                Text(comment.created_at ?? "")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                if comment.parent_id != nil {
                    Text("回复")
                        .font(.caption2)
                        .foregroundColor(theme.accent)
                }
                Button(action: { deleteComment(comment) }) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            Text(comment.content ?? "")
                .font(.subheadline)
                .foregroundColor(.primary)

            Button(action: { replyTo = comment.id }) {
                Text("回复")
                    .font(.caption)
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }

    private func inputBar(_ pageId: String) -> some View {
        VStack(spacing: 4) {
            if let parentId = replyTo {
                HStack {
                    Text("回复评论")
                        .font(.caption)
                        .foregroundColor(theme.accent)
                    Spacer()
                    Button(action: { replyTo = nil }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(replyTo != nil ? "回复评论..." : "添加评论...", text: $newComment, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                Button(action: { submitComment(pageId) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(newComment.isEmpty ? .secondary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newComment.isEmpty)
            }
        }
        .padding(10)
        .background(theme.surfaceSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("选择页面查看评论")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submitComment(_ pageId: String) {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        bridge.createComment(pageId: pageId, content: text, parentId: replyTo) { _ in }
        newComment = ""
        replyTo = nil
        commentsLog.info("Comment added to page \(pageId)")
    }

    private func deleteComment(_ comment: DocComment) {
        bridge.deleteComment(id: comment.id) { _ in }
        commentsLog.info("Comment deleted: \(comment.id)")
    }
}
