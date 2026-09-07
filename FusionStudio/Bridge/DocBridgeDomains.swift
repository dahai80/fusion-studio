// ARCH-1 facade-delegate split (audit-product-0907 P2-2).
// 13 @MainActor final class Doc<Domain>State: ObservableObject — owns @Published + stored props.
// Behavior lives in Doc<Domain>Service.swift extensions (per-domain).
// DocBridge holds `let <domain>State` (stable identity) + objectWillChange.sink forwarding
// (P0-1 fix: SwiftUI doesn't auto-track nested ObservableObject) + computed-property forwards
// (zero view churn). HTTP infra (get/post/put/delete + handleError + authToken + session/baseURL)
// stays on DocBridge; domains reach through `bridge?.get(...)` / `bridge?.handleError(...)`.

import Combine
import Foundation
import os.log

// MARK: - 1. DocLibraryState

@MainActor
final class DocLibraryState: ObservableObject {
    @Published var books: [DocBook] = []
    @Published var chapters: [DocChapter] = []
    @Published var pages: [DocPage] = []
    @Published var currentPage: DocPage?
    @Published var tags: [DocTag] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 2. DocHealthState

@MainActor
final class DocHealthState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?

    // nonisolated(unsafe): deinit(nonisolated) on DocBridge invalidates timer — mirror AgentBridge F-R9.
    nonisolated(unsafe) var reconnectTimer: Timer?
    var reconnectAttempt: Int = 0

    weak var bridge: DocBridge?

    init() {}

    // nonisolated: deinit(nonisolated) 同步调用; reconnectTimer 为 nonisolated(unsafe), Timer.invalidate 线程安全。
    nonisolated func cleanup() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - 3. DocAuthState

@MainActor
final class DocAuthState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 4. DocWorkspaceState

@MainActor
final class DocWorkspaceState: ObservableObject {
    @Published var workspaces: [DocWorkspace] = []
    @Published var currentWorkspace: DocWorkspace?

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 5. DocVersionState

@MainActor
final class DocVersionState: ObservableObject {
    @Published var versions: [DocVersion] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 6. DocWorkflowDomainState
// 名字避开 DocDataModels.swift 的 model struct `DocWorkflowState: Codable` (page-workflow 响应)。

@MainActor
final class DocWorkflowDomainState: ObservableObject {
    @Published var workflows: [DocWorkflow] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 7. DocTemplateState

@MainActor
final class DocTemplateState: ObservableObject {
    @Published var templates: [DocTemplate] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 8. DocOfficeState

@MainActor
final class DocOfficeState: ObservableObject {
    @Published var officeStatus: DocOfficeStatus?

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 9. DocGraphState

@MainActor
final class DocGraphState: ObservableObject {
    @Published var graph: DocGraph?

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 10. DocRAGState

@MainActor
final class DocRAGState: ObservableObject {
    @Published var chunks: [DocRAGChunk] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 11. DocCollabState

@MainActor
final class DocCollabState: ObservableObject {
    @Published var collabConnected: Bool = false
    @Published var collabUsers: [String] = []

    // nonisolated(unsafe): deinit(nonisolated) on DocBridge cancels the WS task — mirror AgentBridge F-R9.
    nonisolated(unsafe) var collabTask: URLSessionWebSocketTask?

    weak var bridge: DocBridge?

    init() {}

    // nonisolated: deinit(nonisolated) 同步调用; collabTask 为 nonisolated(unsafe), cancel 线程安全。
    nonisolated func cleanup() {
        collabTask?.cancel(with: .goingAway, reason: nil)
        collabTask = nil
    }
}

// MARK: - 12. DocAdminState

@MainActor
final class DocAdminState: ObservableObject {
    @Published var users: [DocUser] = []
    @Published var branding: DocBranding?
    @Published var themes: [DocTheme] = []
    @Published var vocabulary: [DocVocabulary] = []
    @Published var webhooks: [DocWebhook] = []
    @Published var systemInfo: DocSystemInfo?
    @Published var systemConfig: [DocSystemConfig] = []
    @Published var exportJobs: [DocExportJob] = []
    @Published var notifications: [DocNotification] = []

    weak var bridge: DocBridge?

    init() {}
}

// MARK: - 13. DocSocialState

@MainActor
final class DocSocialState: ObservableObject {
    @Published var activities: [DocActivity] = []
    @Published var files: [DocFileUpload] = []
    @Published var comments: [DocComment] = []
    @Published var favorites: [DocFavorite] = []

    weak var bridge: DocBridge?

    init() {}
}
