// Callers: DocView (activity tab in DocSubTab).
// Affected API: DocBridge.fetchActivity / .recordActivity → REST /api/activity on localhost:11449.
// Data schemas: DocActivity (id/event/data/created_at from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let actLog = Logger(subsystem: "com.fusion.studio", category: "DocActivity")

struct DocActivityView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            activityTimeline
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.fetchActivity { _ in }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(theme.accent)
            Text("活动日志")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { bridge.fetchActivity { _ in } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var activityTimeline: some View {
        Group {
            if bridge.activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无活动记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(bridge.activities) { activity in
                            activityRow(activity)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func activityRow(_ activity: DocActivity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: eventIcon(activity.event ?? ""))
                    .foregroundColor(theme.accent)
                    .font(.caption)
                Rectangle()
                    .fill(theme.separator)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(eventLabel(activity.event ?? ""))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                if let data = activity.data, !data.isEmpty {
                    Text(String(data.prefix(100)))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
                if let date = activity.created_at {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func eventIcon(_ event: String) -> String {
        if event.contains("create") { return "plus.circle" }
        if event.contains("update") { return "pencil.circle" }
        if event.contains("delete") { return "trash.circle" }
        if event.contains("comment") { return "bubble.left.circle" }
        if event.contains("favorite") { return "star.circle" }
        if event.contains("version") { return "clock.circle" }
        if event.contains("workflow") { return "arrow.triangle.branch" }
        return "circle"
    }

    private func eventLabel(_ event: String) -> String {
        if event.contains("page.create") { return "📄 创建页面" }
        if event.contains("page.update") { return "✏️ 更新页面" }
        if event.contains("page.delete") { return "🗑️ 删除页面" }
        if event.contains("comment.create") { return "💬 添加评论" }
        if event.contains("favorite.add") { return "⭐ 添加收藏" }
        if event.contains("favorite.remove") { return "☆ 取消收藏" }
        if event.contains("version.create") { return "🔖 创建版本" }
        if event.contains("workflow.run") { return "🔄 运行工作流" }
        if event.contains("file.upload") { return "📎 上传附件" }
        return event
    }
}
