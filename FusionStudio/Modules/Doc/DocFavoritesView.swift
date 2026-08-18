// Callers: DocView (favorites tab in DocSubTab).
// Affected API: DocBridge.fetchFavorites / .addFavorite / .removeFavorite → REST /api/favorites on localhost:11449.
// Data schemas: DocFavorite (id/page_id/title/created_at from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let favLog = Logger(subsystem: "com.fusion.studio", category: "DocFavorites")

struct DocFavoritesView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            favoriteList
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.fetchFavorites { _ in }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            Text(i18n.t(.doc_fav_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(bridge.favorites.count)")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var favoriteList: some View {
        Group {
            if bridge.favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(i18n.t(.doc_fav_empty))
                        .foregroundColor(.secondary)
                    Text(i18n.t(.doc_fav_addHint))
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(bridge.favorites) { fav in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(fav.title ?? i18n.t(.doc_fav_noTitle))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let date = fav.created_at {
                            Text(date)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                        Button(action: { removeFavorite(fav) }) {
                            Image(systemName: "star.slash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let pid = fav.page_id {
                            selectedPageId = pid
                            bridge.fetchPage(id: pid)
                            favLog.info("Navigate to favorite page: \(pid)")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func removeFavorite(_ fav: DocFavorite) {
        if let pid = fav.page_id {
            bridge.removeFavorite(pageId: pid) { _ in }
            favLog.info("Favorite removed: \(pid)")
        }
    }
}
