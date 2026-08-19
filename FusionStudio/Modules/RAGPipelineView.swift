// Callers: ModuleDetailView.swift:72 routes .rag -> RAGPipelineView()
// API: RAGAPIClient.shared (HTTP REST to fusion-rag), replaces local RAGEngine
// schema: KBInfo/KBSearchResult/KBAskResult/KBSource from RAGAPIClient
// user instruction: "完成所有待办任务"

import SwiftUI
import os

struct RAGPipelineView: View {
    @State private var selectedTab: RAGTab = .bases

    enum RAGTab: String, CaseIterable {
        case bases
        case chat
        case search
        case config

        var localLabel: String {
            switch self {
            case .bases:  return I18nManager.shared.t(.rag_tab_bases)
            case .chat:   return I18nManager.shared.t(.rag_tab_chat)
            case .search: return I18nManager.shared.t(.rag_tab_search)
            case .config: return I18nManager.shared.t(.rag_tab_config)
            }
        }

        var icon: String {
            switch self {
            case .bases:  return "books.vertical"
            case .chat:   return "bubble.left.and.bubble.right"
            case .search: return "magnifyingglass"
            case .config: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(RAGTab.allCases, id: \.self) { tab in
                    Label(tab.localLabel, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .bases:  KBListView()
            case .chat:   KBChatView()
            case .search: SearchDebugView()
            case .config: KBSettingsView()
            }
        }
    }
}
