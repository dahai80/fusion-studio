import SwiftUI

// MARK: - Legacy compatibility aliases

typealias SpaceMemberView = SpaceMemberPanel
typealias SpaceAgentView = SpaceAgentPanel
// MARK: - Notification Popover

struct SpaceNotificationPopover: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared
    private let spaceManager = CoworkSpaceManager.shared
    @State private var notifications: [SpaceNotification] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_notif_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                let unread = notifications.filter { !$0.isRead }.count
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Spacer()
                Button(i18n.t(.cw_notif_markAll)) { markAllRead() }
                    .font(.system(size: 9))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)

            Divider()

            if notifications.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_notif_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notif in
                            notificationRow(notif)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 360)
        .onAppear { loadNotifications() }
    }

    private func notificationRow(_ notif: SpaceNotification) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: notif.typeIcon)
                .font(.system(size: theme.iconS))
                .foregroundStyle(notif.isRead ? theme.textTertiary : theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(.system(size: theme.captionSize, weight: notif.isRead ? .regular : .semibold))
                    .foregroundStyle(notif.isRead ? theme.textSecondary : theme.text)
                if !notif.content.isEmpty {
                    Text(notif.content)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
                Text(notif.createdAt, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textQuaternary)
            }
            Spacer()
            if !notif.isRead {
                Button(action: { markRead(notif.id) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(notif.isRead ? Color.clear : theme.accent.opacity(0.04))
    }

    private func loadNotifications() {
        Task {
            await spaceManager.loadNotifications()
            await MainActor.run { notifications = spaceManager.activeNotifications }
        }
    }

    private func markRead(_ id: String) {
        Task {
            await spaceManager.markNotificationRead(notificationId: id)
            await MainActor.run {
                notifications = notifications.map { n in
                    var m = n; if n.id == id { m.isRead = true }; return m
                }
            }
        }
    }

    private func markAllRead() {
        for notif in notifications.filter({ !$0.isRead }) {
            Task { await spaceManager.markNotificationRead(notificationId: notif.id) }
        }
        notifications = notifications.map { n in
            var m = n; m.isRead = true; return m
        }
    }
}

// MARK: - Knowledge Base Panel (D4 知识库)
