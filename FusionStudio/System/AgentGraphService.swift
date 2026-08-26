// ARCH-1: Graph Operations + parseGraphModel 从 AgentBridge God-object 抽出, facade extension。
// 本批次耦合迁移: parseGraphModel (private static) + 6 调用方 (fetchGraphs/createGraph/graphGet/updateGraph/
//   templateInstantiate/deployImport) 必须同文件, 因 private = Swift 文件作用域, 跨文件 extension 不可达另一文件的 private static。
// templateInstantiate/deployImport 原留 AgentBridge (跨域, 依赖 parseGraphModel), 现随 parseGraphModel 同搬本文件。
// executeGraph/deleteGraph/cancelExecution 留 AgentBridge: executeGraph 依赖 Self.parseEventModel (Event 域 private static 跨文件不可访问),
//   且写共享 events/isExecuting @Published; deleteGraph/cancelExecution 无 parseGraphModel 依赖可独立抽, 但留以保持 Graph Ops MARK 完整语义, 后续按需。
// @Published graphs (L314) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 DAGCanvasView/AgentTaskViews/AgentStudioView)。
//   templates (L338)/deployFormats (L339) 留主类 (各有外部读), extension 仅读 self.templates/deployFormats 无写, 观察链不变。
// anyToJSONValue: 通用 Any→JSONValue 转换器 (非域 parser), 被 parseGraphModel (本文件) + parseEventModel (留 AgentBridge) 共用。
//   解阻方案: anyToJSONValue private→internal (留 AgentBridge), 本文件 parseGraphModel 调 Self.anyToJSONValue (internal 跨文件可达)。
//   域 parser (parseGraphModel 等) 仍 private, "不 widen 域 parser" 约定不变; 仅 widen 通用 helper。

import Foundation
import os.log

private let agentGraphLog = Logger(subsystem: "com.fusion.studio", category: "AgentGraphService")

extension AgentBridge {

    // MARK: - Graph Operations

    func fetchGraphs() async throws -> [AgentGraphModel] {
        guard let client = ipcClient else {
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
            // (parsed 比 graphs 短时 zip 只比到 parsed.count, 尾部多余 graphs.id 不参与比较 -> changed=false)。
            // 改用 id 集合差集, 增删均能检出。
            let parsedIds = Set(parsed.map(\.id))
            let currentIds = Set(self.graphs.map(\.id))
            let changed = parsed.count != self.graphs.count || parsedIds != currentIds
            if changed {
                self.graphs = parsed
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
        guard let client = ipcClient else {
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
        guard let client = ipcClient else {
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
        guard let client = ipcClient else {
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

    // MARK: - Template Operations (cross-domain, 搬此因依赖 parseGraphModel)

    func templateInstantiate(templateId: String, variables: [String: String]? = nil) async throws -> AgentGraphModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
        guard let graphId = dict["graph_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }

        var nodes: [NodeConfigModel] = []
        if let nodesDict = dict["nodes"] as? [String: [String: Any]] {
            for (nodeId, nodeData) in nodesDict {
                var config: [String: JSONValue] = [:]
                for (k, v) in nodeData {
                    if let jv = anyToJSONValue(v) {
                        config[k] = jv
                    }
                }
                nodes.append(NodeConfigModel(
                    id: nodeId,
                    type: nodeData["type"] as? String ?? "llm",
                    config: config,
                    position: nil
                ))
            }
        } else if let nodesArray = dict["nodes"] as? [[String: Any]] {
            for nodeData in nodesArray {
                let nodeId = nodeData["id"] as? String ?? UUID().uuidString
                var config: [String: JSONValue] = [:]
                for (k, v) in nodeData {
                    if k != "id" && k != "type" && k != "label", let jv = anyToJSONValue(v) {
                        config[k] = jv
                    }
                }
                nodes.append(NodeConfigModel(
                    id: nodeId,
                    type: nodeData["type"] as? String ?? "llm",
                    config: config,
                    position: nil
                ))
            }
        }

        var edges: [EdgeModel] = []
        if let edgesArray = dict["edges"] as? [[String: Any]] {
            for edgeData in edgesArray {
                let source = edgeData["source_id"] as? String ?? edgeData["source"] as? String ?? ""
                let target = edgeData["target_id"] as? String ?? edgeData["target"] as? String ?? ""
                let condition = edgeData["label"] as? String ?? edgeData["condition"] as? String
                edges.append(EdgeModel(
                    id: edgeData["id"] as? String ?? UUID().uuidString,
                    source: source,
                    target: target,
                    condition: condition
                ))
            }
        }

        let createdAt: String
        if let ts = dict["created_at"] as? Double {
            let date = Date(timeIntervalSince1970: ts)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            createdAt = formatter.string(from: date)
        } else if let ts = dict["created_at"] as? String {
            createdAt = ts
        } else {
            createdAt = ""
        }

        // node_count/edge_count 优先取后端元数据; graph.get 返回完整 nodes 时退化为实际数组长度
        let nodeCount = dict["node_count"] as? Int ?? nodes.count
        let edgeCount = dict["edge_count"] as? Int ?? edges.count

        return AgentGraphModel(
            id: graphId,
            name: name,
            nodes: nodes,
            edges: edges,
            created_at: createdAt,
            nodeCount: nodeCount,
            edgeCount: edgeCount
        )
    }
}
