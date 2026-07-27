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
                let result = try await client.artifactList(sessionId: "default")
                let items = result["artifacts"] as? [[String: Any]] ?? []
                var parsed: [ArtifactModel] = []
                for item in items {
                    guard let id = item["id"] as? String,
                          let name = item["name"] as? String,
                          let type = item["type"] as? String else { continue }
                    let version = item["current_version"] as? Int ?? 1
                    let tokens = item["token_count"] as? Int ?? 0
                    let summary = item["summary"] as? String
                    let updatedAt: Date
                    if let ts = item["updated_at"] as? Double {
                        updatedAt = Date(timeIntervalSince1970: ts)
                    } else {
                        updatedAt = Date()
                    }
                    parsed.append(ArtifactModel(id: id, name: name, type: type,
                                                currentVersion: version, tokenCount: tokens,
                                                summary: summary, updatedAt: updatedAt))
                }
                artifacts = parsed
                cacheLog.info("Sidebar cache refreshed: \(parsed.count) artifacts")
            } catch {
                cacheLog.error("Sidebar cache refresh failed: \(error)")
            }
        }
    }
}
