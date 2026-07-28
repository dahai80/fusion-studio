// Callers: DeskView, DeskTemplateTab, DeskWorkflowTab, DeskAgentTab, etc.
// Affected API: DeskBridge @MainActor ObservableObject (all desk.* IPC methods).
// Data schemas: DeskNodeInfo, DeskWorkflowInfo, DeskAgentTask, DeskSession, DeskPermissionRule, DeskSystemInfo, DeskMLXStatus, DeskTemplateInfo, DeskEventEntry.
// Communication: UDS JSON-RPC 2.0 via IPCClient.
// User instruction: "对功能和api进行全量分析检测，看是否都在fusion-studio都有对应的GUI，如果没有需要立即补充GUI"

import Foundation
import Combine
import os.log

private let deskLog = Logger(subsystem: "com.fusion.studio", category: "DeskBridge")

struct DeskNodeInfo: Identifiable, Hashable {
    let id: String
    var name: String
    var category: String
    var description: String
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskNodeInfo, rhs: DeskNodeInfo) -> Bool { lhs.id == rhs.id }
}

struct DeskWorkflowInfo: Identifiable, Hashable {
    let id: String
    var name: String
    var status: String
    var summary: String
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskWorkflowInfo, rhs: DeskWorkflowInfo) -> Bool { lhs.id == rhs.id }
}

struct DeskAgentTask: Identifiable, Hashable {
    let id: String
    var name: String
    var status: String
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskAgentTask, rhs: DeskAgentTask) -> Bool { lhs.id == rhs.id }
}

struct DeskSession: Identifiable, Hashable {
    let id: String
    var name: String
    var status: String
    var steps: Int
    var createdAt: String?
    var updatedAt: String?
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskSession, rhs: DeskSession) -> Bool { lhs.id == rhs.id }
}

struct DeskPermissionRule: Identifiable, Hashable {
    let id: String
    var toolName: String
    var scope: String
    var allowed: Bool
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskPermissionRule, rhs: DeskPermissionRule) -> Bool { lhs.id == rhs.id }
}

struct DeskSystemInfo: Hashable {
    var platform: String
    var python: String
    var cpuCount: Int
    var memoryTotalGB: Double
    var memoryUsedPct: Double
    var diskFreeGB: Double
}

struct DeskMLXStatus: Hashable {
    var status: String
}

struct DeskMLXModel: Identifiable, Hashable {
    let id: String
    var name: String
    var size: String
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskMLXModel, rhs: DeskMLXModel) -> Bool { lhs.id == rhs.id }
}

struct DeskNodeDetail: Hashable {
    var name: String
    var category: String
    var description: String
    var inputs: [String: String]
    var outputs: [String: String]
}

struct DeskTemplateDetail: Hashable {
    var id: String
    var name: String
    var category: String
    var description: String
    var steps: [[String: String]]
}

struct DeskWorkflowExecStatus: Hashable {
    var executionId: String
    var status: String
    var currentNode: String
    var progress: Double
    var result: String
}

struct DeskTemplateInfo: Identifiable, Hashable {
    let id: String
    var name: String
    var category: String
    var description: String
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskTemplateInfo, rhs: DeskTemplateInfo) -> Bool { lhs.id == rhs.id }
}

struct DeskEventEntry: Identifiable, Hashable {
    let id: String
    var type: String
    var source: String
    var timestamp: Double
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DeskEventEntry, rhs: DeskEventEntry) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class DeskBridge: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var lastError: String?

    @Published var nodes: [DeskNodeInfo] = []
    @Published var nodeCategories: [String: Int] = [:]
    @Published var workflows: [DeskWorkflowInfo] = []
    @Published var templates: [DeskTemplateInfo] = []
    @Published var agents: [DeskAgentTask] = []
    @Published var mlxStatus: DeskMLXStatus?
    @Published var systemInfo: DeskSystemInfo?
    @Published var sessions: [DeskSession] = []
    @Published var permissions: [DeskPermissionRule] = []
    @Published var recentEvents: [DeskEventEntry] = []

    @Published var mlxModels: [DeskMLXModel] = []
    @Published var selectedNodeDetail: DeskNodeDetail?
    @Published var selectedTemplateDetail: DeskTemplateDetail?
    @Published var workflowExecStatuses: [String: DeskWorkflowExecStatus] = [:]
    @Published var eventSubscriptionId: String?
    @Published var permissionCheckResult: [String: Any]?

    private var ipc: IPCClient?

    func setIPCClient(_ client: IPCClient) {
        ipc = client
        deskLog.info("DeskBridge: IPCClient set")
    }

    func checkHealth() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskHealth()
            let status = result["status"] as? String ?? "unknown"
            isConnected = (status == "ok")
            lastError = nil
            deskLog.info("DeskBridge: health = \(status)")
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            deskLog.error("DeskBridge: health check failed: \(error.localizedDescription)")
        }
    }

    func loadNodes() async {
        guard let ipc = ipc else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await ipc.deskNodesList()
            let rawNodes = result["nodes"] as? [[String: Any]] ?? []
            nodes = rawNodes.map { n in
                DeskNodeInfo(
                    id: n["name"] as? String ?? UUID().uuidString,
                    name: n["name"] as? String ?? "",
                    category: n["category"] as? String ?? "unknown",
                    description: n["description"] as? String ?? ""
                )
            }
            deskLog.info("DeskBridge: loaded \(self.nodes.count) nodes")
        } catch {
            lastError = error.localizedDescription
            deskLog.error("DeskBridge: loadNodes failed: \(error.localizedDescription)")
        }
    }

    func loadNodeCategories() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskNodesCategories()
            if let cats = result["categories"] as? [String: Int] {
                nodeCategories = cats
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func executeNode(name: String, params: [String: Any] = [:]) async -> [String: Any]? {
        guard let ipc = ipc else { return nil }
        do {
            return try await ipc.deskNodesExecute(name: name, params: params)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadWorkflows() async {
        guard let ipc = ipc else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await ipc.deskWorkflowList()
            let rawTemplates = result["templates"] as? [[String: Any]] ?? []
            workflows = rawTemplates.enumerated().map { i, t in
                DeskWorkflowInfo(
                    id: t["id"] as? String ?? "wf-\(i)",
                    name: t["name"] as? String ?? "Workflow \(i)",
                    status: "available",
                    summary: t["description"] as? String ?? ""
                )
            }
            deskLog.info("DeskBridge: loaded \(self.workflows.count) workflows")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createWorkflow(prompt: String) async -> [String: Any]? {
        guard let ipc = ipc else { return nil }
        do {
            return try await ipc.deskWorkflowCreate(prompt: prompt)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func runWorkflow(workflow: [String: Any]) async -> [String: Any]? {
        guard let ipc = ipc else { return nil }
        do {
            return try await ipc.deskWorkflowRun(workflow: workflow)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func cancelWorkflow(executionId: String) async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskWorkflowCancel(executionId: executionId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadTemplates() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskTemplateList()
            let rawTemplates = result["templates"] as? [[String: Any]] ?? []
            templates = rawTemplates.enumerated().map { i, t in
                DeskTemplateInfo(
                    id: t["id"] as? String ?? "tpl-\(i)",
                    name: t["name"] as? String ?? "Template \(i)",
                    category: t["category"] as? String ?? "",
                    description: t["description"] as? String ?? ""
                )
            }
            deskLog.info("DeskBridge: loaded \(self.templates.count) templates")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runTemplate(templateId: String, variables: [String: String]? = nil) async -> [String: Any]? {
        guard let ipc = ipc else { return nil }
        do {
            return try await ipc.deskTemplateRun(templateId: templateId, variables: variables)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadAgents() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskAgentList()
            let rawAgents = result["agents"] as? [[String: Any]] ?? []
            agents = rawAgents.map { a in
                DeskAgentTask(
                    id: a["id"] as? String ?? UUID().uuidString,
                    name: a["name"] as? String ?? "",
                    status: a["role"] as? String ?? a["status"] as? String ?? "unknown"
                )
            }
            deskLog.info("DeskBridge: loaded \(self.agents.count) agents")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func submitAgentTask(task: String) async -> String? {
        guard let ipc = ipc else { return nil }
        do {
            let result = try await ipc.deskAgentSubmit(task: task)
            return result["task_id"] as? String
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func getAgentStatus(taskId: String) async -> [String: Any]? {
        guard let ipc = ipc else { return nil }
        do {
            return try await ipc.deskAgentStatus(taskId: taskId)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func cancelAgentTask(taskId: String) async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskAgentCancel(taskId: taskId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadMLXStatus() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskMlxStatus()
            let status = result["status"] as? String ?? "unknown"
            mlxStatus = DeskMLXStatus(status: status)
        } catch {
            mlxStatus = DeskMLXStatus(status: "error")
            lastError = error.localizedDescription
        }
    }

    func startMLX(model: String = "") async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskMlxStart(model: model)
            await loadMLXStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopMLX() async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskMlxStop()
            await loadMLXStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadSystemInfo() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskSystemInfo()
            systemInfo = DeskSystemInfo(
                platform: result["platform"] as? String ?? "",
                python: result["python"] as? String ?? "",
                cpuCount: result["cpu_count"] as? Int ?? 0,
                memoryTotalGB: result["memory_total_gb"] as? Double ?? 0,
                memoryUsedPct: result["memory_used_pct"] as? Double ?? 0,
                diskFreeGB: result["disk_free_gb"] as? Double ?? 0
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadRecentEvents() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskEventsRecent()
            let raw = result["events"] as? [[String: Any]] ?? []
            recentEvents = raw.enumerated().map { i, e in
                DeskEventEntry(
                    id: e["id"] as? String ?? "evt-\(i)",
                    type: e["type"] as? String ?? "",
                    source: e["source"] as? String ?? "",
                    timestamp: e["timestamp"] as? Double ?? 0
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadSessions() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskSessionList()
            let raw = result["sessions"] as? [[String: Any]] ?? []
            sessions = raw.map { s in
                DeskSession(
                    id: s["id"] as? String ?? UUID().uuidString,
                    name: s["name"] as? String ?? "",
                    status: s["status"] as? String ?? "",
                    steps: s["steps"] as? Int ?? 0,
                    createdAt: s["created_at"] as? String,
                    updatedAt: s["updated_at"] as? String
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createSession(name: String, description: String = "") async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskSessionCreate(name: name, description: description)
            await loadSessions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSession(sessionId: String) async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskSessionDelete(sessionId: sessionId)
            await loadSessions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func forkSession(sessionId: String, fromStep: Int = 0) async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskSessionFork(sessionId: sessionId, fromStep: fromStep)
            await loadSessions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadPermissions() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskPermissionList()
            if let rules = result["rules"] as? [[String: Any]] {
                permissions = rules.enumerated().map { i, r in
                    DeskPermissionRule(
                        id: r["id"] as? String ?? "perm-\(i)",
                        toolName: r["tool_name"] as? String ?? "",
                        scope: r["scope"] as? String ?? "*",
                        allowed: r["allowed"] as? Bool ?? false
                    )
                }
            } else {
                permissions = []
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func approvePermission(toolName: String, scope: String = "*") async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskPermissionApprove(toolName: toolName, scope: scope)
            await loadPermissions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func denyPermission(toolName: String, scope: String = "*") async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskPermissionDeny(toolName: toolName, scope: scope)
            await loadPermissions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetPermissions() async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskPermissionReset()
            await loadPermissions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 9 New Bridge Methods

    func getNodeInfo(name: String) async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskNodesInfo(name: name)
            selectedNodeDetail = DeskNodeDetail(
                name: result["name"] as? String ?? name,
                category: result["category"] as? String ?? "",
                description: result["description"] as? String ?? "",
                inputs: result["inputs"] as? [String: String] ?? [:],
                outputs: result["outputs"] as? [String: String] ?? [:]
            )
            deskLog.info("DeskBridge: getNodeInfo name=\(name)")
        } catch {
            lastError = error.localizedDescription
            deskLog.error("DeskBridge: getNodeInfo failed: \(error.localizedDescription)")
        }
    }

    func getWorkflowStatus() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskWorkflowStatus()
            if let execs = result["executions"] as? [[String: Any]] {
                for ex in execs {
                    let eid = ex["execution_id"] as? String ?? UUID().uuidString
                    workflowExecStatuses[eid] = DeskWorkflowExecStatus(
                        executionId: eid,
                        status: ex["status"] as? String ?? "unknown",
                        currentNode: ex["current_node"] as? String ?? "",
                        progress: ex["progress"] as? Double ?? 0,
                        result: ex["result"] as? String ?? ""
                    )
                }
            }
            deskLog.info("DeskBridge: getWorkflowStatus loaded \(self.workflowExecStatuses.count) executions")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadMLXModels() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskMlxModels()
            let raw = result["models"] as? [[String: Any]] ?? []
            mlxModels = raw.enumerated().map { i, m in
                DeskMLXModel(
                    id: m["id"] as? String ?? "model-\(i)",
                    name: m["name"] as? String ?? "",
                    size: m["size"] as? String ?? ""
                )
            }
            deskLog.info("DeskBridge: loaded \(self.mlxModels.count) MLX models")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func subscribeEvents() async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskEventsSubscribe()
            eventSubscriptionId = result["subscription_id"] as? String
            deskLog.info("DeskBridge: subscribed events id=\(self.eventSubscriptionId ?? "nil")")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pollEvents() async {
        guard let ipc = ipc, let subId = eventSubscriptionId else { return }
        do {
            let result = try await ipc.deskEventsPoll(subId: subId)
            let raw = result["events"] as? [[String: Any]] ?? []
            let newEvents = raw.enumerated().map { i, e in
                DeskEventEntry(
                    id: e["id"] as? String ?? "evt-poll-\(i)",
                    type: e["type"] as? String ?? "",
                    source: e["source"] as? String ?? "",
                    timestamp: e["timestamp"] as? Double ?? 0
                )
            }
            if !newEvents.isEmpty {
                recentEvents = newEvents + recentEvents
                if recentEvents.count > 200 {
                    recentEvents = Array(recentEvents.prefix(200))
                }
            }
        } catch {
            deskLog.error("DeskBridge: pollEvents failed: \(error.localizedDescription)")
        }
    }

    func getSession(sessionId: String) async -> DeskSession? {
        guard let ipc = ipc else { return nil }
        do {
            let result = try await ipc.deskSessionGet(sessionId: sessionId)
            return DeskSession(
                id: result["id"] as? String ?? sessionId,
                name: result["name"] as? String ?? "",
                status: result["status"] as? String ?? "",
                steps: result["steps"] as? Int ?? 0,
                createdAt: result["created_at"] as? String,
                updatedAt: result["updated_at"] as? String
            )
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func updateSession(sessionId: String, updates: [String: Any]) async {
        guard let ipc = ipc else { return }
        do {
            _ = try await ipc.deskSessionUpdate(sessionId: sessionId, updates: updates)
            await loadSessions()
            deskLog.info("DeskBridge: updated session \(sessionId)")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func checkPermission(toolName: String, params: [String: Any] = [:]) async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskPermissionCheck(toolName: toolName, params: params)
            permissionCheckResult = result
            deskLog.info("DeskBridge: checkPermission tool=\(toolName)")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func getTemplate(templateId: String) async {
        guard let ipc = ipc else { return }
        do {
            let result = try await ipc.deskTemplateGet(templateId: templateId)
            selectedTemplateDetail = DeskTemplateDetail(
                id: result["id"] as? String ?? templateId,
                name: result["name"] as? String ?? "",
                category: result["category"] as? String ?? "",
                description: result["description"] as? String ?? "",
                steps: result["steps"] as? [[String: String]] ?? []
            )
            deskLog.info("DeskBridge: getTemplate id=\(templateId)")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadAll() async {
        await checkHealth()
        guard isConnected else { return }
        async let n1: Void = loadNodes()
        async let n2: Void = loadNodeCategories()
        async let w1: Void = loadWorkflows()
        async let t1: Void = loadTemplates()
        async let a1: Void = loadAgents()
        async let m1: Void = loadMLXStatus()
        async let m2: Void = loadMLXModels()
        async let s1: Void = loadSystemInfo()
        async let e1: Void = loadRecentEvents()
        async let e2: Void = subscribeEvents()
        async let ss1: Void = loadSessions()
        async let p1: Void = loadPermissions()
        _ = await (n1, n2, w1, t1, a1, m1, m2, s1, e1, e2, ss1, p1)
        deskLog.info("DeskBridge: loadAll completed")
    }
}
