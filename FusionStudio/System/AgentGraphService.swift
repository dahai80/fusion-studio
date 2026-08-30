// ARCH-1 PR5 (#359 facade-delegate): Graph Operations + parseGraphModel 从 AgentBridge God-object 迁入 AgentState 域。
//   本文件含 2 extension:
//     1) extension AgentState — 7 真实方法体 (fetchGraphs/createGraph/graphGet/updateGraph/templateInstantiate/deployImport/deleteGraph, 自持 ipcClient) + parseGraphModel。
//     2) extension AgentBridge — 7 个 1 行 facade stub 委托到 agentState.X(), 保外部 call site 签名零变。
//   本批次耦合迁移: parseGraphModel (private static) + 7 调用方 (fetchGraphs/createGraph/graphGet/updateGraph/
//     templateInstantiate/deployImport/deleteGraph) 必须同文件, 因 private = Swift 文件作用域, 跨文件 extension 不可达另一文件的 private static。
//   templateInstantiate/deployImport 原留 AgentBridge (跨域, 依赖 parseGraphModel), 现随 parseGraphModel 同搬本文件 (PR4 ModuleState 域时这两法依赖 cross-file parseGraphModel 留主类, PR5 AgentState 域整批抽后入域)。
//   deleteGraph 原留 AgentBridge (保 Graph Ops MARK 完整语义), PR5 随 Graph 域整批抽入域 (纯叶: 无 parseGraphModel 依赖, 仅 client.call graphDelete)。
//   executeGraph 留 AgentBridge: 依赖 Self.parseEventModel (Event 域 private static 跨文件不可访问) + guard 鉴权 +
//     写共享 runtimeState.events/isExecuting (跨域协调器)。cancelExecution 已迁 RuntimeState 域 (PR2)。
//   @Published graphs 在 AgentState 域 (外部 SwiftUI 读 DAGCanvasView/AgentTaskViews/AgentStudioView), 经 bridge.agentState.graphs 不变。
//   Logger: 本文件自有 agentGraphLog 替代主类 private logger (跨文件不可达)。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3/PR4 坑)。

import Foundation
import os.log

private let agentGraphLog = Logger(subsystem: "com.fusion.studio", category: "AgentGraphService")

// MARK: - Graph Operations (行为落地 AgentState 域)
extension AgentState {

    // MARK: - Graph Operations

    func fetchGraphs() async throws -> [AgentGraphModel] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        do {
            let result = try await client.call(method: RPCMethod.graphList)
            let graphsData = result["graphs"] as? [[String: Any]] ?? []
            var parsed: [AgentGraphModel] = []
            for g in graphsData {
                if let model = Self.parseGraphModel(from: g) {
                    parsed.append(model)
                }
            }
            // 仅在 id 集合或数量变化时更新 @Published, 避免 .task 反复触发 AgentStudioView body 重算导致 Workflows 转圈
            // BUG-6: 旧实现 zip(parsed, self.graphs) 按较短序列截断, 删除项不被检测
            // (parsed 比 self.graphs 短时 zip 只比到 parsed.count, 尾部多余 self.graphs.id 不参与比较 -> changed=false)。
            // 改用 id 集合差集, 增删均能检出。
            let parsedIds = Set(parsed.map(\.id))
            let currentIds = Set(self.graphs.map(\.id))
            let changed = parsed.count != self.graphs.count || parsedIds != currentIds
            if changed {
                // 审计0830 P1: 后端 graphs 无限增长则 @Published 数组无界膨胀 → 内存涨 + SwiftUI diff 全量重算。
                //   LRU cap 200 保最新 (复用 capChatMessages 范式)。
                self.graphs = Array(parsed.suffix(200))
            }
            agentGraphLog.info("fetchGraphs: received \(parsed.count) graphs (changed=\(changed))")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentGraphLog.error("fetchGraphs: \(error)")
            throw bridgeErr
        }
    }

    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentGraphLog.info("createGraph: name=\(name) nodes=\(nodes.count) edges=\(edges.count)")

        var nodesParam: [[String: Any]] = []
        for n in nodes {
            nodesParam.append([
                "id": n.id,
                "type": n.type,
                "label": n.type,
            ])
        }

        var edgesParam: [[String: Any]] = []
        for e in edges {
            var edgeDict: [String: Any] = [
                "source_id": e.source,
                "target_id": e.target,
            ]
            if let cond = e.condition {
                edgeDict["label"] = cond
            }
            edgesParam.append(edgeDict)
        }

        do {
            let result = try await client.call(method: RPCMethod.graphCreate, params: [
                "name": name,
                "nodes": nodesParam,
                "edges": edgesParam,
            ])

            guard let model = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse graph.create response")
            }
            agentGraphLog.info("createGraph: created id=\(model.id)")
            return model
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentGraphLog.error("createGraph: \(error)")
            throw bridgeErr
        }
    }

    func graphGet(graphId: String) async throws -> AgentGraphModel? {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentGraphLog.info("graphGet: graphId=\(graphId)")
        do {
            let result = try await client.graphGet(graphId: graphId)
            // daemon graph.get 的 result 顶层即 graph 数据 (含 nodes/edges/name), 不包在 graph key 里
            let graphData = (result["graph"] as? [String: Any]) ?? result
            return Self.parseGraphModel(from: graphData)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentGraphLog.error("graphGet: \(error)")
            throw bridgeErr
        }
    }

    func updateGraph(id: String, name: String? = nil, nodes: [NodeConfigModel]? = nil, edges: [EdgeModel]? = nil) async throws -> AgentGraphModel? {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentGraphLog.info("updateGraph: id=\(id)")
        var params: [String: Any] = ["graph_id": id]
        if let name { params["name"] = name }
        if let nodes {
            params["nodes"] = nodes.map { node -> [String: Any] in
                let label: String
                if case .string(let v) = node.config["label"] { label = v } else { label = "" }
                return ["id": node.id, "type": node.type, "label": label]
            }
        }
        if let edges {
            params["edges"] = edges.map { ["source_id": $0.source, "target_id": $0.target, "label": $0.condition ?? ""] }
        }
        do {
            let result = try await client.call(method: RPCMethod.graphUpdate, params: params)
            return Self.parseGraphModel(from: result)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentGraphLog.error("updateGraph: \(error)")
            throw bridgeErr
        }
    }

    func deleteGraph(id: String) async throws {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentGraphLog.info("deleteGraph: id=\(id)")
        do {
            _ = try await client.call(method: RPCMethod.graphDelete, params: ["graph_id": id])
            agentGraphLog.info("deleteGraph: deleted id=\(id, privacy: .public)")
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentGraphLog.error("deleteGraph id=\(id, privacy: .public) failed: \(error.errorDescription ?? "unknown", privacy: .public)")
            throw bridgeErr
        }
    }

    // MARK: - Template Operations (cross-domain, 搬此因依赖 parseGraphModel)

    func templateInstantiate(templateId: String, variables: [String: String]? = nil) async throws -> AgentGraphModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentGraphLog.info("templateInstantiate: templateId=\(templateId)")
        do {
            let result = try await client.templateInstantiate(templateId: templateId, variables: variables)
            guard let graph = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse template.instantiate response")
            }
            return graph
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Deploy Operations (cross-domain, 搬此因依赖 parseGraphModel)

    func deployImport(filepath: String) async throws -> AgentGraphModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentGraphLog.info("deployImport: filepath=\(filepath)")
        do {
            let result = try await client.deployImport(filepath: filepath)
            guard let graph = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse deploy.import response")
            }
            return graph
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Graph Parsing Helper (domain parser, file-private, 仅本 extension 调用)

    private static func parseGraphModel(from dict: [String: Any]) -> AgentGraphModel? {
        // F-I4: Codable 强类型解码 (AgentGraphModel.init(from:) 保 graph_id/id dual-key + nodes dict/array
        // catch-all config + created_at Double-or-String + node_count/edge_count fallback)。
        // 保留原 guard 语义: id 或 name 缺失 → 返 nil (caller throw "Failed to parse")。
        guard let graph = AgentBridge.decodeCodable(AgentGraphModel.self, from: dict, context: "graph") else {
            return nil
        }
        if graph.id.isEmpty || graph.name.isEmpty {
            agentGraphLog.warning("parseGraphModel: id or name empty after decode, dropping — id=\(graph.id, privacy: .public)")
            return nil
        }
        return graph
    }
}

// MARK: - Graph Operations (facade-delegate stubs — 行为已迁 AgentState 域)
// ARCH-1 PR5: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchGraphs() async throws -> [AgentGraphModel] {
        try await agentState.fetchGraphs()
    }

    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel {
        try await agentState.createGraph(name: name, nodes: nodes, edges: edges)
    }

    func graphGet(graphId: String) async throws -> AgentGraphModel? {
        try await agentState.graphGet(graphId: graphId)
    }

    func updateGraph(id: String, name: String? = nil, nodes: [NodeConfigModel]? = nil, edges: [EdgeModel]? = nil) async throws -> AgentGraphModel? {
        try await agentState.updateGraph(id: id, name: name, nodes: nodes, edges: edges)
    }

    func deleteGraph(id: String) async throws {
        try await agentState.deleteGraph(id: id)
    }

    func templateInstantiate(templateId: String, variables: [String: String]? = nil) async throws -> AgentGraphModel {
        try await agentState.templateInstantiate(templateId: templateId, variables: variables)
    }

    func deployImport(filepath: String) async throws -> AgentGraphModel {
        try await agentState.deployImport(filepath: filepath)
    }
}
