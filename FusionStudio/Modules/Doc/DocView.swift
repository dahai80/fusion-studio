// Callers: ModuleDetailView (case .doc: DocView()).
// Affected API: DocBridge REST localhost:11449 — all 82 routes.
// Data schemas: DocPage/DocBook/DocChapter/DocTag/DocSearchResult/DocComment/DocFavorite/DocActivity/DocFileUpload/DocRAGChunk via DocBridge.
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let docViewLog = Logger(subsystem: "com.fusion.studio", category: "DocView")

enum DocSubTab: String, CaseIterable, Identifiable {
    case editor = "编辑器"
    case graph = "知识图谱"
    case versions = "版本历史"
    case office = "Office"
    case workflow = "工作流"
    case template = "模板"
    case search = "搜索"
    case comments = "评论"
    case favorites = "收藏"
    case files = "文件"
    case rag = "RAG"
    case activity = "动态"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .editor:    return "doc.text"
        case .graph:     return "point.3.connected.trianglepath.dotted"
        case .versions:  return "clock.arrow.circlepath"
        case .office:    return "desktopcomputer"
        case .workflow:  return "arrow.triangle.branch"
        case .template:  return "doc.badge.gearshape"
        case .search:    return "magnifyingglass"
        case .comments:  return "bubble.left.and.bubble.right"
        case .favorites: return "star"
        case .files:     return "folder"
        case .rag:       return "brain"
        case .activity:  return "bell"
        }
    }
}

struct DocView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var bridge = DocBridge()
    @State private var selectedPageId: String?
    @State private var showCopilot = true
    @State private var sidebarWidth: CGFloat = 260
    @State private var copilotWidth: CGFloat = 320
    @State private var searchText = ""
    @State private var activeTab: DocSubTab = .editor

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            HSplitView {
                DocSidebar(bridge: bridge, selectedPageId: $selectedPageId, searchText: $searchText)
                    .frame(minWidth: 220, maxWidth: 320)

                mainContent
                    .frame(minWidth: 400)

                if showCopilot {
                    DocAICopilotView(bridge: bridge, selectedPageId: $selectedPageId)
                        .frame(width: copilotWidth)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showCopilot.toggle() }) {
                    Image(systemName: showCopilot ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                }
                .help("AI Copilot")
            }
        }
        .onAppear {
            bridge.checkHealth()
            bridge.fetchBooks()
            bridge.fetchTags()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DocSubTab.allCases) { tab in
                Button(action: { activeTab = tab }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(activeTab == tab ? theme.accentSoft : Color.clear)
                    .foregroundColor(activeTab == tab ? theme.accent : theme.textSecondary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(theme.surfaceSecondary)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch activeTab {
        case .editor:
            DocEditorArea(bridge: bridge, selectedPageId: $selectedPageId)
        case .graph:
            DocGraphView(bridge: bridge)
        case .versions:
            if let pid = selectedPageId {
                DocVersionView(bridge: bridge, pageId: pid)
            } else {
                emptyTab("选择页面查看版本历史", icon: "clock.arrow.circlepath")
            }
        case .office:
            DocOfficeView(bridge: bridge)
        case .workflow:
            DocWorkflowView(bridge: bridge)
        case .template:
            DocTemplateView(bridge: bridge)
        case .search:
            DocSearchView(bridge: bridge)
        case .comments:
            DocCommentsView(bridge: bridge, selectedPageId: $selectedPageId)
        case .favorites:
            DocFavoritesView(bridge: bridge, selectedPageId: $selectedPageId)
        case .files:
            DocFilesPanel(bridge: bridge, selectedPageId: $selectedPageId)
        case .rag:
            DocRAGPanel(bridge: bridge, selectedPageId: $selectedPageId)
        case .activity:
            DocActivityView(bridge: bridge)
        }
    }

    private func emptyTab(_ message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
