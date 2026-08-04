// IMPORTERS/CALLERS: DocView (HSplitView left pane), DocEditorArea (DocView center pane)
// AFFECTED API: DocBridge — fetchBooks, fetchChapters, fetchPages, createBook, createChapter, createPage, deletePage, fetchTags, updatePage, fetchFavorites, searchPages
// DATA SCHEMAS: DocBook, DocChapter, DocPage, DocTag, DocFavorite (from DocBridge.swift)
// USER INSTRUCTION: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let docSidebarLog = Logger(subsystem: "com.fusion.studio", category: "DocSidebar")

struct DocSidebar: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @Binding var searchText: String
    @State private var expandedBooks: Set<String> = []
    @State private var showNewBook = false
    @State private var showNewPage = false
    @State private var newBookTitle = ""
    @State private var newPageTitle = ""
    @State private var targetBookId: String?
    @State private var targetChapterId: String?
    @State private var selectedTag: DocTag?
    @State private var showAuthSheet = false
    @State private var showWorkspacePicker = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            workspaceBar
            Divider()
            searchField
            Divider()
            tagFilter
            Divider()
            bookTree
            favoritesSection
            Spacer()
            connectionBar
        }
        .background(theme.surfacePrimary)
        .onAppear { bridge.restoreAuth() }
    }

    private var headerBar: some View {
        HStack {
            Text("书架")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { showWorkspacePicker = true }) {
                Image(systemName: "square.stack.3d.up")
            }
            .help("工作空间")
            Button(action: { showNewBook = true }) {
                Image(systemName: "books.vertical.badge.plus")
            }
            .help("新建书架")
            .popover(isPresented: $showNewBook) {
                newBookPopover
            }
            Button(action: { showNewPage = true }) {
                Image(systemName: "doc.badge.plus")
            }
            .help("新建页面")
            .popover(isPresented: $showNewPage) {
                newPagePopover
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var workspaceBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up")
                .font(.caption)
                .foregroundColor(.secondary)
            if let ws = bridge.currentWorkspace {
                Text(ws.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            } else {
                Text("未选择工作空间")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary.opacity(0.5))
        .contentShape(Rectangle())
        .onTapGesture { showWorkspacePicker = true }
        .popover(isPresented: $showWorkspacePicker) {
            DocWorkspacePicker(bridge: bridge)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索页面...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary.opacity(0.5))
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "全部", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(bridge.tags) { tag in
                    FilterChip(
                        label: tag.name,
                        isSelected: selectedTag?.id == tag.id,
                        color: tag.color ?? "#007AFF"
                    ) {
                        selectedTag = tag
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 32)
        .background(theme.surfaceSecondary.opacity(0.3))
    }

    private var bookTree: some View {
        List(selection: $selectedPageId) {
            if bridge.books.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                ForEach(filteredBooks) { book in
                    bookSection(book)
                }
                orphanPagesSection
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedTag) { _ in filterPagesByTag() }
    }

    private func bookSection(_ book: DocBook) -> some View {
        Section {
            if expandedBooks.contains(book.id) {
                let bookChapters = bridge.chapters.filter { $0.book_id == book.id }
                if bookChapters.isEmpty {
                    let bookPages = filteredPages.filter { $0.book_id == book.id && $0.chapter_id == nil }
                    ForEach(bookPages) { page in
                        pageRow(page)
                    }
                } else {
                    ForEach(bookChapters) { chapter in
                        DisclosureGroup {
                            let chapterPages = filteredPages.filter { $0.chapter_id == chapter.id }
                            ForEach(chapterPages) { page in
                                pageRow(page)
                            }
                            Button(action: {
                                targetChapterId = chapter.id
                                targetBookId = book.id
                                newPageTitle = ""
                                showNewPage = true
                            }) {
                                Label("添加页面", systemImage: "plus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        } label: {
                            Label(chapter.title, systemImage: "folder")
                                .font(.subheadline)
                        }
                    }
                    let unfiled = filteredPages.filter { $0.book_id == book.id && $0.chapter_id == nil }
                    ForEach(unfiled) { page in
                        pageRow(page)
                    }
                }
                Button(action: {
                    targetBookId = book.id
                    targetChapterId = nil
                    newPageTitle = ""
                    showNewPage = true
                }) {
                    Label("添加页面", systemImage: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Button(action: { toggleBook(book.id) }) {
                HStack {
                    Image(systemName: expandedBooks.contains(book.id) ? "books.vertical.fill" : "books.vertical")
                        .foregroundColor(theme.accent)
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    if let desc = book.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("新建章节") {
                    createChapterInBook(book.id)
                }
                Button("删除书架", role: .destructive) {
                    docSidebarLog.info("Delete book \(book.id) requested")
                }
            }
        }
    }

    private var orphanPagesSection: some View {
        let orphans = filteredPages.filter { $0.book_id == nil }
        if orphans.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            Section {
                ForEach(orphans) { page in
                    pageRow(page)
                }
            } header: {
                Label("未归档", systemImage: "tray")
                    .font(.subheadline.weight(.semibold))
            }
        )
    }

    private func pageRow(_ page: DocPage) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(page.title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if let tags = page.tags, !tags.isEmpty {
                ForEach(tags.prefix(2)) { tag in
                    Circle()
                        .fill(Color(hex: tag.color ?? "#007AFF") ?? Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .tag(page.id)
        .contextMenu {
            Button("删除页面", role: .destructive) {
                bridge.deletePage(id: page.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("暂无书架")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("点击 + 创建第一个书架")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var favoritesSection: some View {
        Group {
            if !bridge.favorites.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("收藏")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 8)
                    ForEach(bridge.favorites) { fav in
                        Button(action: { selectedPageId = fav.page_id ?? "" }) {
                            HStack {
                                Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption2)
                                Text(fav.title ?? "").font(.caption).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var connectionBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(bridge.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            if bridge.isAuthenticated {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.open")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }
            Text(bridge.isConnected ? "已连接" : "未连接")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            if bridge.isAuthenticated {
                Button(action: { bridge.authLogout() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("退出登录")
            } else {
                Button(action: { showAuthSheet = true }) {
                    Text("登录")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("登录认证")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
        .sheet(isPresented: $showAuthSheet) {
            DocAuthSheet(bridge: bridge)
        }
    }

    // MARK: - Popovers

    private var newBookPopover: some View {
        VStack(spacing: 8) {
            Text("新建书架")
                .font(.headline)
            TextField("书架名称", text: $newBookTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showNewBook = false }
                Button("创建") {
                    if !newBookTitle.isEmpty {
                        bridge.createBook(title: newBookTitle, workspaceId: bridge.currentWorkspace?.id)
                        newBookTitle = ""
                        showNewBook = false
                    }
                }
                .disabled(newBookTitle.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 240)
    }

    private var newPagePopover: some View {
        VStack(spacing: 8) {
            Text("新建页面")
                .font(.headline)
            TextField("页面标题", text: $newPageTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showNewPage = false }
                Button("创建") {
                    if !newPageTitle.isEmpty {
                        bridge.createPage(
                            title: newPageTitle,
                            bookId: targetBookId,
                            chapterId: targetChapterId
                        )
                        newPageTitle = ""
                        showNewPage = false
                    }
                }
                .disabled(newPageTitle.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 240)
    }

    // MARK: - Helpers

    private var filteredBooks: [DocBook] {
        if searchText.isEmpty { return bridge.books }
        return bridge.books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            bridge.pages.contains { $0.book_id == book.id && $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var filteredPages: [DocPage] {
        var result = bridge.pages
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        if let tag = selectedTag {
            result = result.filter { page in
                page.tags?.contains(where: { $0.id == tag.id }) ?? false
            }
        }
        return result
    }

    private func toggleBook(_ id: String) {
        if expandedBooks.contains(id) {
            expandedBooks.remove(id)
        } else {
            expandedBooks.insert(id)
            bridge.fetchChapters(bookId: id)
            bridge.fetchPages(bookId: id)
        }
    }

    private func createChapterInBook(_ bookId: String) {
        bridge.createChapter(bookId: bookId, title: "新章节")
    }

    private func filterPagesByTag() {
        if let tag = selectedTag {
            docSidebarLog.info("Filter by tag: \(tag.name)")
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    var isSelected: Bool = false
    var color: String = "#007AFF"
    let action: () -> Void

    @Environment(\.studioTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Circle()
                    .fill(isSelected ? Color.white : (Color(hex: color) ?? Color.blue))
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isSelected ? (Color(hex: color) ?? Color.blue) : theme.surfaceSecondary
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DocEditorArea

struct DocEditorArea: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @State private var editorContent = ""
    @State private var editorTitle = ""
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            if let page = bridge.currentPage, page.id == selectedPageId {
                editorToolbar(page)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("标题", text: $editorTitle)
                            .font(.title2.weight(.bold))
                            .textFieldStyle(.plain)
                            .foregroundColor(.primary)
                            .onChange(of: page.title) { _ in
                                if !isEditing { editorTitle = page.title }
                            }

                        if let tags = page.tags, !tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(tags) { tag in
                                    HStack(spacing: 2) {
                                        Circle()
                                            .fill(Color(hex: tag.color ?? "#007AFF") ?? Color.blue)
                                            .frame(width: 6, height: 6)
                                        Text(tag.name)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.surfaceSecondary)
                                    .cornerRadius(6)
                                }
                            }
                        }

                        TextEditor(text: $editorContent)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.primary)
                            .frame(minHeight: 400)
                            .onChange(of: page.content) { _ in
                                if !isEditing { editorContent = page.content }
                            }
                    }
                    .padding(16)
                }
            } else {
                emptyEditor
            }
        }
        .background(theme.surfacePrimary)
        .onChange(of: selectedPageId) { newId in
            if let id = newId {
                bridge.fetchPage(id: id)
                isEditing = false
            }
        }
    }

    private func editorToolbar(_ page: DocPage) -> some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: { formatBold() }) {
                    Image(systemName: "bold")
                }
                .help("加粗")
                Button(action: { formatItalic() }) {
                    Image(systemName: "italic")
                }
                .help("斜体")
                Button(action: { formatHeading() }) {
                    Image(systemName: "textformat.size")
                }
                .help("标题")
                Divider().frame(height: 16)
                Button(action: { insertLink() }) {
                    Image(systemName: "link")
                }
                .help("链接")
                Button(action: { insertCode() }) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("代码")
                Button(action: { insertList() }) {
                    Image(systemName: "list.bullet")
                }
                .help("列表")
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.textSecondary)

            Spacer()

            Text(page.updated_at ?? "")
                .font(.caption2)
                .foregroundColor(theme.textTertiary)

            Button(action: { savePage(page) }) {
                Image(systemName: "square.and.arrow.down")
            }
            .help("保存")
            .disabled(!isEditing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var emptyEditor: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("选择或创建文档")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("从左侧书架选择页面，或点击 + 创建新页面")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: 280)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editor Actions

    private func savePage(_ page: DocPage) {
        bridge.updatePage(id: page.id, title: editorTitle, content: editorContent)
        isEditing = false
        docSidebarLog.info("Page saved: \(page.id)")
    }

    private func formatBold() {
        editorContent += "****"
        isEditing = true
    }

    private func formatItalic() {
        editorContent += "**"
        isEditing = true
    }

    private func formatHeading() {
        editorContent += "\n## "
        isEditing = true
    }

    private func insertLink() {
        editorContent += "[text](url)"
        isEditing = true
    }

    private func insertCode() {
        editorContent += "```\n\n```"
        isEditing = true
    }

    private func insertList() {
        editorContent += "\n- "
        isEditing = true
    }
}

