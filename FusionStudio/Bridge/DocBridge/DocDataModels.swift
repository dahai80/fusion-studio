import Foundation
// MARK: - Data Models

struct DocPage: Codable, Identifiable, Hashable {
    let id: String
    var workspace_id: String?
    var book_id: String?
    var chapter_id: String?
    var title: String
    var slug: String?
    var content: String
    var markdown: String?
    var editor_mode: String?
    var parent_id: String?
    var sort_order: Int?
    var is_published: Int?
    var created_at: String?
    var updated_at: String?
    var tags: [DocTag]?
    var links: [DocPageRef]?
    var backlinks: [DocPageRef]?
    var files: [DocFileRef]?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocPage, rhs: DocPage) -> Bool { lhs.id == rhs.id }
}

struct DocPageRef: Codable, Hashable {
    let id: String
    let title: String
}

struct DocBook: Codable, Identifiable, Hashable {
    let id: String
    var workspace_id: String?
    var title: String
    var slug: String?
    var description: String?
    var cover: String?
    var sort_order: Int?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocBook, rhs: DocBook) -> Bool { lhs.id == rhs.id }
}

struct DocChapter: Codable, Identifiable, Hashable {
    let id: String
    var book_id: String?
    var title: String
    var slug: String?
    var description: String?
    var sort_order: Int?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocChapter, rhs: DocChapter) -> Bool { lhs.id == rhs.id }
}

struct DocTag: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var slug: String?
    var color: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocTag, rhs: DocTag) -> Bool { lhs.id == rhs.id }
}

struct DocFileRef: Codable, Hashable {
    let id: String
    var name: String?
    var mime: String?
    var size: Int?
    var created_at: String?
}

struct DocGraphNode: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: String?
    var tags: [String]?
    var linkCount: Int?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocGraphNode, rhs: DocGraphNode) -> Bool { lhs.id == rhs.id }
}

struct DocGraphEdge: Codable, Hashable {
    let source: String
    let target: String
    var link_type: String?
}

struct DocGraph: Codable {
    var nodes: [DocGraphNode]
    var edges: [DocGraphEdge]
}

struct DocVersion: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var title: String?
    var content: String?
    var version: Int?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocVersion, rhs: DocVersion) -> Bool { lhs.id == rhs.id }
}

struct DocDiffLine: Codable, Hashable {
    var type: String
    var line: String
}

struct DocDiffResult: Codable {
    var page_id: String?
    var v1: Int?
    var v2: Int?
    var diff: [DocDiffLine]?
}

struct DocWorkflow: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var yaml_def: String?
    var status: String?
    var last_run: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocWorkflow, rhs: DocWorkflow) -> Bool { lhs.id == rhs.id }
}

struct DocWorkflowRun: Codable, Identifiable {
    let id: String
    var workflow_id: String?
    var status: String?
    var input: String?
    var output: String?
    var steps: String?
    var started_at: String?
    var completed_at: String?
}

struct DocTemplate: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: String?
    var content: String?
    var variables: String?
    var category: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocTemplate, rhs: DocTemplate) -> Bool { lhs.id == rhs.id }
}

struct DocOfficeStatus: Codable {
    var available: Bool?
    var version: String?
    var formats: [String]?
}

struct DocRAGChunk: Codable, Identifiable {
    let id: String
    var page_id: String?
    var chunk_index: Int?
    var chunk_text: String?
    var chunk_type: String?
}

struct DocSearchResult: Codable, Identifiable {
    let id: String
    var title: String?
    var content: String?
    var score: Double?
    var type: String?
    var book_id: String?
    var tags: [DocTag]?
}

struct DocComment: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var content: String?
    var parent_id: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocComment, rhs: DocComment) -> Bool { lhs.id == rhs.id }
}

struct DocFavorite: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var title: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocFavorite, rhs: DocFavorite) -> Bool { lhs.id == rhs.id }
}

struct DocActivity: Codable, Identifiable {
    let id: String
    var event: String?
    var data: String?
    var created_at: String?
}

struct DocFileUpload: Codable, Identifiable {
    let id: String
    var name: String?
    var mime: String?
    var size: Int?
    var created_at: String?
}

struct DocWorkflowState: Codable {
    var page_id: String?
    var workflow_id: String?
    var current_state: String?
    var transitions: [DocWorkflowTransition]?
}

struct DocWorkflowTransition: Codable {
    var name: String?
    var target_state: String?
}

struct DocAuthSetup: Codable {
    var username: String
    var password: String
}

struct DocAuthLogin: Codable {
    var username: String
    var password: String
}

struct DocAuthResponse: Codable {
    var token: String?
    var expiresIn: Int?
    var message: String?
}

struct DocWorkspace: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocWorkspace, rhs: DocWorkspace) -> Bool { lhs.id == rhs.id }
}

struct DocUser: Codable, Identifiable, Hashable {
    let id: String
    var username: String?
    var email: String?
    var role: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocUser, rhs: DocUser) -> Bool { lhs.id == rhs.id }
}

struct DocBranding: Codable {
    var logo_url: String?
    var primary_color: String?
    var secondary_color: String?
    var font: String?
    var custom_css: String?
}

struct DocTheme: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var css: String?
    var is_dark: Bool?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocTheme, rhs: DocTheme) -> Bool { lhs.id == rhs.id }
}

struct DocVocabulary: Codable, Identifiable, Hashable {
    let id: String
    var term: String
    var definition: String?
    var category: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocVocabulary, rhs: DocVocabulary) -> Bool { lhs.id == rhs.id }
}

struct DocWebhook: Codable, Identifiable, Hashable {
    let id: String
    var url: String
    var events: [String]?
    var secret: String?
    var is_active: Bool?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocWebhook, rhs: DocWebhook) -> Bool { lhs.id == rhs.id }
}

struct DocMetadataEntry: Codable, Identifiable {
    let id: String
    var key: String
    var value: String?
}

struct DocSystemInfo: Codable {
    var version: String?
    var uptime: Double?
    var total_books: Int?
    var total_pages: Int?
    var total_users: Int?
}

struct DocSystemConfig: Codable {
    var key: String
    var value: String?
}

struct DocExportJob: Codable, Identifiable {
    let id: String
    var status: String?
    var progress: Double?
    var download_url: String?
    var created_at: String?
}

struct DocNotification: Codable, Identifiable, Hashable {
    let id: String
    var type: String?
    var message: String?
    var is_read: Bool?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocNotification, rhs: DocNotification) -> Bool { lhs.id == rhs.id }
}
