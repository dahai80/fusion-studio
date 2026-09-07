import Foundation
import os.log

// ARCH-1 Phase 2 (audit-product-0907 P2-2): DocLibrary 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   DocView + 16 兄弟视图 call site 0 改)。@Published (books/chapters/pages/currentPage/tags) 现属
//   DocLibraryState (self.X = 域自身 @Published); HTTP 经 bridge?.get/post/put/delete reach-through;
//   错误经 bridge?.handleError 汇入中央错漏斗; LRU cap 经 DocBridge.cap (internal static)。
//   跨域读 (workspace 等) 经 self.bridge?.workspaceState.X; 本域纯 self.X。

private let docLibraryLog = Logger(subsystem: "com.fusion.studio", category: "DocLibraryService")

extension DocLibraryState {

    // MARK: - Books

    func fetchBooks() {
        bridge?.get("/api/books") { [weak self] (result: Result<[DocBook], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.books = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "books")
            }
        }
    }

    func createBook(title: String, description: String? = nil, workspaceId: String? = nil) {
        var body: [String: Any] = ["title": title]
        if let desc = description { body["description"] = desc }
        if let wsId = workspaceId { body["workspace_id"] = wsId }
        bridge?.post("/api/books", body: body) { [weak self] (result: Result<DocBook, Error>) in
            switch result {
            case .success(let book):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.books.append(book)
                    DocBridge.cap(&self.books, 200)
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createBook")
            }
        }
    }

    // MARK: - Chapters

    func fetchChapters(bookId: String) {
        bridge?.get("/api/chapters?bookId=\(bookId)") { [weak self] (result: Result<[DocChapter], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.chapters = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "chapters")
            }
        }
    }

    func createChapter(bookId: String, title: String) {
        bridge?.post("/api/chapters", body: ["book_id": bookId, "title": title]) { [weak self] (result: Result<DocChapter, Error>) in
            switch result {
            case .success(let ch):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.chapters.append(ch)
                    DocBridge.cap(&self.chapters, 500)
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createChapter")
            }
        }
    }

    // MARK: - Pages

    func fetchPages(bookId: String? = nil, chapterId: String? = nil) {
        var path = "/api/pages"
        var params: [String] = []
        if let bid = bookId { params.append("bookId=\(bid)") }
        if let cid = chapterId { params.append("chapterId=\(cid)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }

        bridge?.get(path) { [weak self] (result: Result<[DocPage], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.pages = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "pages")
            }
        }
    }

    func fetchPage(id: String) {
        bridge?.get("/api/pages/\(id)") { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.currentPage = page }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "page")
            }
        }
    }

    func createPage(title: String, bookId: String? = nil, chapterId: String? = nil, content: String = "") {
        var body: [String: Any] = ["title": title, "content": content]
        if let bid = bookId { body["book_id"] = bid }
        if let cid = chapterId { body["chapter_id"] = cid }
        bridge?.post("/api/pages", body: body) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.pages.append(page)
                    DocBridge.cap(&self.pages, 1000)
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createPage")
            }
        }
    }

    func updatePage(id: String, title: String, content: String, markdown: String? = nil) {
        var body: [String: Any] = ["title": title, "content": content]
        if let md = markdown { body["markdown"] = md }
        bridge?.put("/api/pages/\(id)", body: body) { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if let idx = self?.pages.firstIndex(where: { $0.id == id }) {
                        self?.pages[idx].title = title
                        self?.pages[idx].content = content
                    }
                    if self?.currentPage?.id == id {
                        self?.currentPage?.title = title
                        self?.currentPage?.content = content
                    }
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "updatePage")
            }
        }
    }

    func deletePage(id: String) {
        struct DeleteResp: Decodable { var deleted: Bool? }
        bridge?.delete("/api/pages/\(id)") { [weak self] (result: Result<DeleteResp, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.pages.removeAll { $0.id == id }
                    if self?.currentPage?.id == id { self?.currentPage = nil }
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "deletePage")
            }
        }
    }

    // MARK: - Tags

    func fetchTags() {
        bridge?.get("/api/tags") { [weak self] (result: Result<[DocTag], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.tags = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "tags")
            }
        }
    }
}

extension DocBridge {

    func fetchBooks() { libraryState.fetchBooks() }

    func createBook(title: String, description: String? = nil, workspaceId: String? = nil) {
        libraryState.createBook(title: title, description: description, workspaceId: workspaceId)
    }

    func fetchChapters(bookId: String) { libraryState.fetchChapters(bookId: bookId) }

    func createChapter(bookId: String, title: String) {
        libraryState.createChapter(bookId: bookId, title: title)
    }

    func fetchPages(bookId: String? = nil, chapterId: String? = nil) {
        libraryState.fetchPages(bookId: bookId, chapterId: chapterId)
    }

    func fetchPage(id: String) { libraryState.fetchPage(id: id) }

    func createPage(title: String, bookId: String? = nil, chapterId: String? = nil, content: String = "") {
        libraryState.createPage(title: title, bookId: bookId, chapterId: chapterId, content: content)
    }

    func updatePage(id: String, title: String, content: String, markdown: String? = nil) {
        libraryState.updatePage(id: id, title: title, content: content, markdown: markdown)
    }

    func deletePage(id: String) { libraryState.deletePage(id: id) }

    func fetchTags() { libraryState.fetchTags() }
}
