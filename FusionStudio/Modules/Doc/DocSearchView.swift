// Callers: DocView (search tab in DocSubTab).
// Affected API: DocBridge.searchPages / .searchAdvanced → REST /api/search, /api/search/advanced on localhost:11449.
// Data schemas: DocSearchResult (id/title/content/score/type/book_id/tags from DocBridge.swift).
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let searchLog = Logger(subsystem: "com.fusion.studio", category: "DocSearch")

struct DocSearchView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var query = ""
    @State private var results: [DocSearchResult] = []
    @State private var isSearching = false
    @State private var filterTag: String?
    @State private var filterType: String?
    @State private var sortBy: String = "relevance"

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider()
            resultList
        }
        .background(theme.surfacePrimary)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.accent)
            TextField("搜索文档...", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit { performSearch() }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button(action: { performSearch() }) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty || isSearching)
        }
        .padding(12)
        .background(theme.surfaceSecondary)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("类型", selection: $filterType) {
                Text("全部").tag(String?.none)
                Text("页面").tag(String?.some("page"))
                Text("书架").tag(String?.some("book"))
            }
            .frame(width: 100)

            Picker("排序", selection: $sortBy) {
                Text("相关度").tag("relevance")
                Text("时间").tag("date")
                Text("标题").tag("title")
            }
            .frame(width: 80)

            if let tag = filterTag {
                HStack(spacing: 4) {
                    Text(tag)
                        .font(.caption)
                    Button(action: { filterTag = nil }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.accentSoft)
                .cornerRadius(4)
            }

            Spacer()

            Text("\(results.count) 结果")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary.opacity(0.5))
    }

    private var resultList: some View {
        Group {
            if results.isEmpty && !isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(query.isEmpty ? "输入关键词搜索文档" : "无搜索结果")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { item in
                    resultRow(item)
                }
                .listStyle(.plain)
            }
        }
    }

    private func resultRow(_ item: DocSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.type == "book" ? "books.vertical" : "doc.text")
                    .foregroundColor(theme.accent)
                    .font(.caption)
                Text(item.title ?? "无标题")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let score = item.score {
                    Text(String(format: "%.1f", score))
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
            }
            if let content = item.content, !content.isEmpty {
                Text(String(content.prefix(150)))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
            if let tags = item.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.surfaceSecondary)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        searchLog.info("Search: \(q)")

        if filterTag != nil || filterType != nil || sortBy != "relevance" {
            bridge.searchAdvanced(query: q, tag: filterTag, type: filterType, sort: sortBy) { result in
                DispatchQueue.main.async {
                    self.isSearching = false
                    if case .success(let list) = result { self.results = list }
                }
            }
        } else {
            bridge.searchPages(query: q) { result in
                DispatchQueue.main.async {
                    self.isSearching = false
                    if case .success(let list) = result { self.results = list }
                }
            }
        }
    }
}
