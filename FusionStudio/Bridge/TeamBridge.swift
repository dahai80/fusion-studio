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
        Task {
            await refreshAll()
            await connectStream()
        }
    }

    // MARK: - Event stream discovery (daemon.status → ws_port/ws_enabled/ws_token)

    func connectStream() async {
        guard let ipc = ipcClient else {
            teamBridgeLog.warning("TeamBridge.connectStream: no IPCClient")
            startPolling()
            return
        }
        do {
            let res = try await ipc.daemonStatus()
            let wsPort = (res["ws_port"] as? Int) ?? 0
            let wsEnabled = (res["ws_enabled"] as? Bool) ?? (wsPort > 0)
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
        guard pollTimer == nil else { return }
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
            let res = try await ipc.taskList(team: selectedTeam, limit: 200)
            let taskDicts = (res["tasks"] as? [[String: Any]]) ?? (res["result"] as? [[String: Any]]) ?? []
            var mapped = taskDicts.compactMap { TeamTask(dict: $0) }
            // client-side team filter (until upstream issue #314 adds server-side filter)
            if !self.selectedTeam.isEmpty && self.selectedTeam != "default" {
                mapped = mapped.filter { $0.team == self.selectedTeam }
            }
            // cap
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
            let res = try await ipc.taskHealth()
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
        eventStream.stop()
        stopPolling()
        refreshDebounceTask?.cancel()
    }

    deinit {
        // eventStream.stop() is @MainActor — rely on TeamEventStream.deinit to cancel WS task.
        pollTimer?.invalidate()
        refreshDebounceTask?.cancel()
    }
}
