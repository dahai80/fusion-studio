import Foundation
import Combine
import os.log

private let teamBridgeLog = Logger(subsystem: "com.fusion.studio", category: "TeamBridge")

// M2-1: TeamWorkspace facade. Owns snapshot RPC reads (task.list/team.swarm_agents/budget.status)
// + TeamEventStream (WS consumer). NOT extending AgentBridge (design §7.2: team 域独立走 IPCClient
// 直连, 避免 AgentBridge 再膨胀). GUI 不做本地状态 — daemon SQLite is SSOT, SwiftUI caches render only.
// Write ops (approve/reject/break_in) deferred to M2-3/M2-4 (daemon hard-gate).
@MainActor
final class TeamBridge: ObservableObject {

    @Published var tasks: [TeamTask] = []
    @Published var members: [TeamMember] = []
    @Published var messages: [PlazaMessage] = []
    @Published var budget: TeamBudget?
    @Published var teamHealth: TeamHealth?
    @Published var selectedTeam: String = "default"
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var wsEnabled: Bool = false

    let eventStream = TeamEventStream()

    private var ipcClient: IPCClient?
    private var pollTimer: Timer?
    private var refreshDebounceTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?
    private var isStopped: Bool = false
    private var cancellables = Set<AnyCancellable>()

    private static let pollIntervalSec: TimeInterval = 5.0
    private static let maxTasksCache = 500

    init() {
        teamBridgeLog.info("TeamBridge init")
        // observe event stream — new events trigger debounced task refresh
        eventStream.$events
            .removeDuplicates(by: { $0.count == $1.count })
            .dropFirst()
            .sink { [weak self] events in
                guard let self = self, let last = events.last else { return }
                self.handleEvent(last)
            }
            .store(in: &cancellables)
    }

    // MARK: - Wiring

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        teamBridgeLog.info("TeamBridge IPCClient wired")
        bootstrapTask?.cancel()
        bootstrapTask = Task { [weak self] in
            guard let self = self, !self.isStopped else { return }
            await self.refreshAll()
            guard !Task.isCancelled, !self.isStopped else { return }
            await self.connectStream()
        }
    }

    // MARK: - Event stream discovery (daemon.status → ws_port/ws_enabled/ws_token)

    func connectStream() async {
        guard !isStopped, let ipc = ipcClient else {
            teamBridgeLog.warning("TeamBridge.connectStream: no IPCClient")
            startPolling()
            return
        }
        do {
            let res = try await ipc.daemonStatus()
            let wsPort = (res["ws_port"] as? Int) ?? 0
            // #315 merged: ws_enabled + ws_token from daemon.status (no more ws_port>0 heuristic)
            let wsEnabled = (res["ws_enabled"] as? Bool) ?? false
            let wsToken = (res["ws_token"] as? String) ?? ""
            self.wsEnabled = wsEnabled

            if wsEnabled && wsPort > 0 {
                guard let url = URL(string: "ws://127.0.0.1:\(wsPort)") else {
                    teamBridgeLog.error("TeamBridge: invalid ws URL port=\(wsPort)")
                    startPolling()
                    return
                }
                teamBridgeLog.info("TeamBridge: starting WS stream port=\(wsPort) token=\(wsToken.isEmpty ? "empty" : "set", privacy: .public)")
                eventStream.start(team: selectedTeam, wsURL: url, wsToken: wsToken)
                startPolling()
            } else {
                teamBridgeLog.info("TeamBridge: WS disabled (wsPort=\(wsPort)), polling only")
                startPolling()
            }
        } catch {
            teamBridgeLog.warning("TeamBridge: daemon.status failed: \(error.localizedDescription, privacy: .public) — polling fallback")
            self.lastError = BridgeError.sanitize(error)
            startPolling()
        }
    }

    // MARK: - Polling fallback (runs alongside WS; no-op tick if WS connected)

    func startPolling() {
        guard !isStopped, pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollIntervalSec, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.eventStream.isConnected { return }
                await self.refreshTasks()
                await self.refreshMembers()
            }
        }
        teamBridgeLog.info("TeamBridge polling started (\(Self.pollIntervalSec)s)")
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        teamBridgeLog.info("TeamBridge polling stopped")
    }

    // MARK: - Snapshot RPCs

    func refreshAll() async {
        isLoading = true
        lastError = nil
        async let tasksTask: Void = refreshTasks()
        async let membersTask: Void = refreshMembers()
        async let budgetTask: Void = refreshBudget()
        async let healthTask: Void = refreshTeamHealth()
        _ = await (tasksTask, membersTask, budgetTask, healthTask)
        isLoading = false
        teamBridgeLog.info("TeamBridge refreshAll done: tasks=\(self.tasks.count) members=\(self.members.count)")
    }

    func refreshTasks() async {
        guard let ipc = ipcClient else { return }
        do {
            // #314 merged: server-side team filter (no more client-side filter)
            let res = try await ipc.taskList(team: selectedTeam, limit: 200)
            let taskDicts = (res["tasks"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            var mapped = taskDicts.compactMap { TeamTask(dict: $0) }
            if mapped.count > Self.maxTasksCache {
                mapped = Array(mapped.suffix(Self.maxTasksCache))
            }
            self.tasks = mapped
            teamBridgeLog.info("refreshTasks: \(mapped.count) tasks for team=\(self.selectedTeam, privacy: .public)")
        } catch {
            self.lastError = BridgeError.sanitize(error)
            teamBridgeLog.warning("refreshTasks failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshMembers() async {
        guard let ipc = ipcClient else { return }
        do {
            let res = try await ipc.teamSwarmAgents()
            let agentDicts = (res["agents"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            let mapped = agentDicts.compactMap { TeamMember(dict: $0) }
            self.members = mapped
            teamBridgeLog.info("refreshMembers: \(mapped.count) agents")
        } catch {
            self.lastError = BridgeError.sanitize(error)
            teamBridgeLog.warning("refreshMembers failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshMessages() async {
        guard let ipc = ipcClient else { return }
        do {
            let channel = "team_\(selectedTeam)"
            let res = try await ipc.teamPlazaMessages(channel: channel)
            let msgDicts = (res["messages"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            let mapped = msgDicts.compactMap { PlazaMessage(dict: $0) }
            self.messages = mapped
            teamBridgeLog.info("refreshMessages: \(mapped.count) messages channel=\(channel, privacy: .public)")
        } catch {
            self.lastError = BridgeError.sanitize(error)
            teamBridgeLog.warning("refreshMessages failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshBudget() async {
        guard let ipc = ipcClient else { return }
        do {
            let res = try await ipc.budgetStatus()
            if let budget = TeamBudget(dict: res) {
                self.budget = budget
                teamBridgeLog.info("refreshBudget: max=\(budget.maxTokens) spent=\(budget.spentTokens)")
            }
        } catch {
            teamBridgeLog.warning("refreshBudget failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshTeamHealth() async {
        guard let ipc = ipcClient else { return }
        do {
            // #318 merged: team.health per-team aggregation (was global task.health)
            let res = try await ipc.teamHealthRPC(team: selectedTeam)
            if let health = TeamHealth(dict: res) {
                self.teamHealth = health
                teamBridgeLog.info("refreshTeamHealth: total=\(health.totalTasks) running=\(health.runningTasks)")
            }
        } catch {
            teamBridgeLog.warning("refreshTeamHealth failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Event-driven refresh (debounced)

    private func handleEvent(_ event: TeamEvent) {
        guard event.triggersTaskRefresh else { return }
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self = self, !Task.isCancelled else { return }
            await self.refreshTasks()
        }
    }

    // MARK: - Break-in (M2-4)

    func sendBreakIn(message: String) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            teamBridgeLog.warning("sendBreakIn: no IPCClient")
            throw BridgeError.notConnected
        }
        teamBridgeLog.info("sendBreakIn team=\(self.selectedTeam, privacy: .public)")
        return try await ipc.teamPlazaBreakIn(team: selectedTeam, message: message)
    }

    // MARK: - Review operations (M2-3, upstream #317 merged 625b66e)

    func setReviewState(taskId: String, reviewState: String) async throws -> Bool {
        guard let ipc = ipcClient else {
            teamBridgeLog.warning("setReviewState: no IPCClient")
            throw BridgeError.notConnected
        }
        teamBridgeLog.info("setReviewState task=\(taskId, privacy: .public) state=\(reviewState, privacy: .public)")
        let res = try await ipc.taskSetReviewState(taskId: taskId, reviewState: reviewState)
        let status = (res["status"] as? String) ?? "ok"
        if status == "error" {
            teamBridgeLog.warning("setReviewState error: \(res["message"] as? String ?? "-", privacy: .public)")
            return false
        }
        // refresh tasks to reflect new review_state
        await refreshTasks()
        return true
    }

    // MARK: - Evidence (M2-5, upstream #316 merged 625b66e)

    @Published var evidence: [TeamEvidence] = []

    func refreshEvidence() async {
        guard let ipc = ipcClient else { return }
        do {
            let res = try await ipc.evidenceList(team: selectedTeam, limit: 100)
            let dicts = (res["evidence"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            self.evidence = dicts.compactMap { TeamEvidence(dict: $0) }
            teamBridgeLog.info("refreshEvidence: \(self.evidence.count) entries team=\(self.selectedTeam, privacy: .public)")
        } catch {
            self.lastError = BridgeError.sanitize(error)
            teamBridgeLog.warning("refreshEvidence failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshFailedEvidence() async {
        guard let ipc = ipcClient else { return }
        do {
            let res = try await ipc.evidenceFailure(team: selectedTeam, limit: 50)
            let dicts = (res["evidence"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            self.evidence = dicts.compactMap { TeamEvidence(dict: $0) }
            teamBridgeLog.info("refreshFailedEvidence: \(self.evidence.count) failed entries")
        } catch {
            self.lastError = BridgeError.sanitize(error)
            teamBridgeLog.warning("refreshFailedEvidence failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Team selection

    func selectTeam(_ team: String) {
        let trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != selectedTeam else { return }
        selectedTeam = trimmed
        teamBridgeLog.info("TeamBridge selectTeam: \(trimmed, privacy: .public)")
        // restart stream for new team
        eventStream.stop()
        Task {
            await refreshAll()
            await connectStream()
        }
    }

    // MARK: - Cleanup

    func stop() {
        isStopped = true
        bootstrapTask?.cancel()
        bootstrapTask = nil
        eventStream.stop()
        stopPolling()
        refreshDebounceTask?.cancel()
    }

    deinit {
        // eventStream.stop() is @MainActor — rely on TeamEventStream.deinit to cancel WS task.
        pollTimer?.invalidate()
        refreshDebounceTask?.cancel()
        bootstrapTask?.cancel()
    }
}
