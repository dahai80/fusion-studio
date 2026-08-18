// Callers: DocView (activity tab in DocSubTab).
// Affected API: DocBridge.fetchActivity / .recordActivity → REST /api/activity on localhost:11449.
// Data schemas: DocActivity (id/event/data/created_at from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let actLog = Logger(subsystem: "com.fusion.studio", category: "DocActivity")

struct DocActivityView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
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
            Text(i18n.t(.doc_act_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { bridge.fetchActivity { _ in } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help(i18n.t(.refresh))
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
                    Text(i18n.t(.doc_act_empty))
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
        if event.contains("page.create") { return i18n.t(.doc_act_evPageCreate) }
        if event.contains("page.update") { return i18n.t(.doc_act_evPageUpdate) }
        if event.contains("page.delete") { return i18n.t(.doc_act_evPageDelete) }
        if event.contains("comment.create") { return i18n.t(.doc_act_evCommentCreate) }
        if event.contains("favorite.add") { return i18n.t(.doc_act_evFavAdd) }
        if event.contains("favorite.remove") { return i18n.t(.doc_act_evFavRemove) }
        if event.contains("version.create") { return i18n.t(.doc_act_evVerCreate) }
        if event.contains("workflow.run") { return i18n.t(.doc_act_evWorkflowRun) }
        if event.contains("file.upload") { return i18n.t(.doc_act_evFileUpload) }
        return event
    }
}
