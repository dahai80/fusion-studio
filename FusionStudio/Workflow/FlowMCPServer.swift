import Foundation
import Network
import os.log

// #433 P3-3: workflow-as-MCP-tool 本地 HTTP server (plan §6.5)。
//   NWListener 仅绑 127.0.0.1:11479 (port-registry fusion-studio-mcp, boot T2);
//   MCP JSON-RPC: initialize / tools/list (flows→tools) / tools/call (LocalExecutor 真跑)。
//   可测: handleJSONRPC 纯逻辑单独暴露, 测试不占端口。

private let mcpLog = Logger(subsystem: "com.fusion.studio", category: "FlowMCPServer")

@MainActor
final class FlowMCPServer {
    static let defaultPort: UInt16 = 11479

    let flowStore: WorkflowFlowStore
    let executor: LocalExecutor
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.fusion.studio.flow-mcp")
    private(set) var isRunning = false

    init(flowStore: WorkflowFlowStore) {
        self.flowStore = flowStore
        self.executor = LocalExecutor(flowStore: flowStore)
    }

    // MARK: - 生命周期

    func start(port: UInt16 = FlowMCPServer.defaultPort) throws {
        guard !isRunning else { return }
        let param = NWParameters.tcp
        // 仅 loopback (#433 安全要求): 显式 IPv4 127.0.0.1, 不落 *:11479
        guard let portNum = NWEndpoint.Port(rawValue: port) else {
            throw WorkflowError.corruptFlowFile("invalid port \(port)")
        }
        param.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: portNum)
        let listener = try NWListener(using: param)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleListenerState(state, port: port)
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in
                self?.handleConnection(conn)
            }
        }
        self.listener = listener
        listener.start(queue: queue)
        mcpLog.info("mcp server starting port=\(port)")
    }

    private func handleListenerState(_ state: NWListener.State, port: UInt16) {
        switch state {
        case .ready:
            isRunning = true
            mcpLog.info("mcp server ready 127.0.0.1:\(port)")
        case .failed(let error):
            mcpLog.error("mcp server failed: \(error.localizedDescription, privacy: .public)")
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        mcpLog.info("mcp server stopped")
    }

    // MARK: - HTTP 面最小实现

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if error != nil || done {
                self.respond(conn, body: buf)
                return
            }
            if let headerEnd = buf.range(of: Data("\r\n\r\n".utf8)) {
                let head = Data(buf[..<headerEnd.lowerBound])
                let header = String(decoding: head, as: UTF8.self)
                let contentLength = header
                    .split(separator: "\r\n")
                    .first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
                let bodyStart = headerEnd.upperBound
                if buf.count - bodyStart >= contentLength {
                    self.respond(conn, body: buf)
                    return
                }
            }
            self.receive(conn, buffer: buf)
        }
    }

    private func respond(_ conn: NWConnection, body raw: Data) {
        let payload = httpPayload(raw)
        let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(payload)
        conn.send(content: out, completion: .contentProcessed { [weak conn] _ in
            conn?.cancel()
        })
    }

    // 请求入口: 解析 body → JSON-RPC (GET /health 供探活)
    func httpPayload(_ raw: Data) -> Data {
        guard let headerEnd = raw.range(of: Data("\r\n\r\n".utf8)) else {
            return Self.jsonRPCError(id: nil, code: -32700, message: "no header")
        }
        let head = String(decoding: Data(raw[..<headerEnd.lowerBound]), as: UTF8.self)
        let requestLine = head.split(separator: "\r\n").first.map(String.init) ?? ""
        let bodyData = Data(raw[headerEnd.upperBound...])
        if requestLine.hasPrefix("GET") && requestLine.contains("/health") {
            return Data("{\"status\":\"ok\",\"server\":\"flow-mcp\"}".utf8)
        }
        return handleJSONRPC(bodyData)
    }

    // MARK: - JSON-RPC 核心 (可测)

    func handleJSONRPC(_ body: Data) -> Data {
        guard let req = try? JSONDecoder().decode([String: JSONValue].self, from: body),
              let method = req["method"]?.stringValue else {
            return Self.jsonRPCError(id: nil, code: -32700, message: "parse error")
        }
        let id = req["id"]
        let params = req["params"]
        mcpLog.info("mcp method=\(method, privacy: .public)")
        do {
            let result: JSONValue
            switch method {
            case "initialize":
                result = .object([
                    "protocolVersion": .string("2024-11-05"),
                    "capabilities": .object(["tools": .object([:])]),
                    "serverInfo": .object([
                        "name": .string("fusion-studio-flow-mcp"),
                        "version": .string("1.0.0"),
                    ]),
                ])
            case "tools/list":
                result = .object(["tools": .array(Self.flowTools(try flowStore.listFlows()))])
            case "tools/call":
                result = try handleToolCall(params)
            default:
                return Self.jsonRPCError(id: id, code: -32601, message: "method not found: \(method)")
            }
            return Self.encode(id: id, result: result)
        } catch {
            mcpLog.error("mcp tool call failed: \(error.localizedDescription, privacy: .public)")
            return Self.jsonRPCError(id: id, code: -32000, message: error.localizedDescription)
        }
    }

    // tools/call: {name: flow名, arguments: inputs}
    private func handleToolCall(_ params: JSONValue?) throws -> JSONValue {
        guard case .object(let p)? = params,
              let name = p["name"]?.stringValue else {
            throw WorkflowError.corruptFlowFile("tools/call missing tool name")
        }
        var inputs: [String: JSONValue] = [:]
        if case .object(let args)? = p["arguments"] {
            inputs = args.filter { $0.key != "name" }
        }
        // 阻塞执行直到 runFinished (MCP 契约: 调用方等最终结果; 无流式)。
        // 调用点在 Network queue 线程 — MainActor 不被阻塞, 可安全等待。
        var summary = ""
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            summary = (try? await runTool(name: name, inputs: inputs)) ?? "error: tool call failed"
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 120)
        return .object([
            "content": .array([.object(["type": .string("text"), "text": .string(summary)])]),
        ])
    }

    // 异步执行入口 (测试直调, 避开信号量)
    func runTool(name: String, inputs: [String: JSONValue]) async throws -> String {
        guard let graph = try flowStore.listFlows().first(where: { $0.name == name }) else {
            throw WorkflowError.corruptFlowFile("flow not found: \(name)")
        }
        var summary = ""
        for try await ev in executor.run(graph, inputs: inputs) {
            if case .runFinished(let s) = ev { summary = s }
        }
        mcpLog.info("mcp tool executed \(name, privacy: .public): \(summary.prefix(120), privacy: .public)")
        return summary
    }

    // MARK: - tools 映射 (flow → MCP tool)

    static func flowTools(_ flows: [WorkflowGraph]) -> [JSONValue] {
        flows.map { flow in
            .object([
                "name": .string(flow.name),
                "description": .string("Run FusionStudio flow '\(flow.name)' (\(flow.nodes.count) nodes)"),
                "inputSchema": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "input": .object(["type": .string("string"), "description": .string("Flow input text")]),
                    ]),
                ]),
            ])
        }
    }

    // MARK: - 编码

    private static func encode(id: JSONValue?, result: JSONValue) -> Data {
        let resp: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "id": id ?? .string("null"),
            "result": result,
        ]
        return (try? JSONEncoder().encode(resp)) ?? Data("{}".utf8)
    }

    private static func jsonRPCError(id: JSONValue?, code: Int, message: String) -> Data {
        let resp: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "id": id ?? .string("null"),
            "error": .object([
                "code": .double(Double(code)),
                "message": .string(message),
            ]),
        ]
        return (try? JSONEncoder().encode(resp)) ?? Data("{}".utf8)
    }
}
