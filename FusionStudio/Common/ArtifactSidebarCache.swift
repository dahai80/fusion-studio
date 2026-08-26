import SwiftUI
import os.log

private let cacheLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactSidebarCache")

class ArtifactSidebarCache: ObservableObject {
    static let shared = ArtifactSidebarCache()

    @Published var artifacts: [ArtifactModel] = []

    private weak var ipcClient: IPCClient?
    private var refreshTimer: Timer?

    private init() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func configure(ipcClient: IPCClient) {
        self.ipcClient = ipcClient
        refresh()
    }

    func refresh() {
        guard let client = ipcClient else {
            cacheLog.warning("Sidebar cache: no IPCClient configured")
            return
        }
        Task { @MainActor in
            do {
                let projectId = FusionProjectManager.shared.activeProject?.id
                let result = try await client.artifactList(sessionId: "default", projectId: projectId)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                // F-I4: 复用 ArtifactModel.init(from:) 强类型解码 (kindFallback + updated_at Double), 去重手写解析。
                let parsed = items.compactMap { AgentBridge.decodeCodable(ArtifactModel.self, from: $0, context: "artifact-cache") }
                artifacts = parsed
                cacheLog.info("Sidebar cache refreshed: \(parsed.count) artifacts")
            } catch {
                cacheLog.error("Sidebar cache refresh failed: \(error)")
            }
        }
    }
}
