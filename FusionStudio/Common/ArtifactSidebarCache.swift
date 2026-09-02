import SwiftUI
import os.log

private let cacheLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactSidebarCache")

class ArtifactSidebarCache: ObservableObject {
    static let shared = ArtifactSidebarCache()

    @Published var artifacts: [ArtifactModel] = []

    private weak var ipcClient: IPCClient?
    private var refreshTimer: Timer?

    private init() {
        startTimer()
    }

    // F-perf-5: singleton deinit 永不触发, 30s Timer 后台仍跑 = 耗电 + 无谓 UDS 调用。
    // 改 scenePhase 驱动 startTimer/stopTimer, 后台停, 前台恢复。
    private func startTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        cacheLog.info("F-perf-5: artifact refresh timer started")
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        cacheLog.info("F-perf-5: artifact refresh timer stopped (background)")
    }

    // scenePhase 调用入口 (FusionStudioApp.onChange scenePhase)。
    func pauseForBackground() { stopTimer() }
    func resumeForForeground() { startTimer(); refresh() }

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
