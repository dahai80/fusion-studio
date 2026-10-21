import Foundation
import os.log

// N9 (#348) GUI parity: per-token SSE from fusion-agent-studio api_server.
// Routes: GET /v1/graphs/{graph_id}/execute/stream and /v1/agents/{agent_id}/execute/stream.
// `thinking=0|1` controls reasoning frames; frames with type == "thinking_token" are
// surfaced separately so the UI renders them outside the answer bubble.
private let agentSSELog = Logger(subsystem: "com.fusion.studio", category: "AgentSSEClient")

enum AgentStreamEventKind: String {
    case token
    case thinkingToken = "thinking_token"
    case toolCall = "tool_call"
    case toolCallStart = "tool_call_start"
    case toolCallEnd = "tool_call_end"
    case toolResult = "tool_result"
    case result
    case done
    case error
    case verify
    case checkPoint = "checkpoint"
    case other

    init(rawType: String) {
        switch rawType {
        case "token": self = .token
        case "thinking_token": self = .thinkingToken
        case "tool_call": self = .toolCall
        case "tool_call_start": self = .toolCallStart
        case "tool_call_end": self = .toolCallEnd
        case "tool_result": self = .toolResult
        case "result": self = .result
        case "done", "end": self = .done
        case "error": self = .error
        case "verify": self = .verify
        case "checkpoint": self = .checkPoint
        default: self = .other
        }
    }
}

struct AgentStreamEvent: Identifiable {
    let id = UUID()
    let kind: AgentStreamEventKind
    let content: String
    let name: String
    let nodeId: String
    let timestamp: Double
    let runArtifactId: String

    var isAnswerToken: Bool { kind == .token || kind == .result }
    var isThinkingToken: Bool { kind == .thinkingToken }
}

struct AgentSSEClient {
    let host: String
    let port: Int
    let apiKey: String

    init(host: String = FusionConfig.shared.agentStudioHost,
         port: Int = FusionConfig.shared.agentStudioHttpPort,
         apiKey: String = ProcessInfo.processInfo.environment["FUSION_AGENT_STUDIO_API_KEY"] ?? "") {
        self.host = host
        self.port = port
        self.apiKey = apiKey
    }

    func streamAgent(agentId: String, input: String, thinking: Bool = true) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        let path = "/v1/agents/\(escaped(agentId))/execute/stream"
        return stream(path: path, query: [
            URLQueryItem(name: "input", value: input),
            URLQueryItem(name: "thinking", value: thinking ? "1" : "0"),
        ])
    }

    func streamGraph(graphId: String, input: String, thinking: Bool = true, fromNode: String = "", stopAfter: String = "", onlyNode: String = "") -> AsyncThrowingStream<AgentStreamEvent, Error> {
        let path = "/v1/graphs/\(escaped(graphId))/execute/stream"
        var query: [URLQueryItem] = [
            URLQueryItem(name: "input", value: input),
            URLQueryItem(name: "thinking", value: thinking ? "1" : "0"),
        ]
        if !fromNode.isEmpty { query.append(URLQueryItem(name: "from_node", value: fromNode)) }
        if !stopAfter.isEmpty { query.append(URLQueryItem(name: "stop_after", value: stopAfter)) }
        if !onlyNode.isEmpty { query.append(URLQueryItem(name: "only_node", value: onlyNode)) }
        return stream(path: path, query: query)
    }

    private func escaped(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    }

    private func stream(path: String, query: [URLQueryItem]) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var components = URLComponents()
                    components.scheme = FusionConfig.shared.schemeForHost(host)
                    components.host = host
                    components.port = port
                    components.path = path
                    var items = query
                    if !apiKey.isEmpty {
                        items.append(URLQueryItem(name: "api_key", value: apiKey))
                    }
                    components.queryItems = items
                    guard let url = components.url else {
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 600
                    if !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    agentSSELog.info("stream open path=\(path, privacy: .public) host=\(self.host, privacy: .public):\(self.port)")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        agentSSELog.error("stream HTTP \(status) path=\(path, privacy: .public)")
                        throw IPCError.rpcError(code: status, message: "SSE HTTP \(status)")
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        guard let data = payload.data(using: .utf8),
                              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            agentSSELog.warning("stream dropped malformed frame")
                            continue
                        }
                        let event = Self.parse(object)
                        continuation.yield(event)
                        if event.kind == .done {
                            break
                        }
                    }
                    continuation.finish()
                    agentSSELog.info("stream closed path=\(path, privacy: .public)")
                } catch {
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        agentSSELog.error("stream failed: \(error.localizedDescription, privacy: .public)")
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func parse(_ object: [String: Any]) -> AgentStreamEvent {
        let rawType = object["type"] as? String ?? "other"
        let kind = AgentStreamEventKind(rawType: rawType)
        var content = ""
        for key in ["content", "token", "delta", "text"] {
            if let value = object[key] as? String, !value.isEmpty {
                content = value
                break
            }
        }
        if content.isEmpty, kind == .error {
            content = object["message"] as? String ?? ""
        }
        if content.isEmpty, let metadata = object["metadata"] as? [String: Any] {
            for key in ["reasoning_content", "reasoning", "thinking"] {
                if let value = metadata[key] as? String, !value.isEmpty {
                    content = value
                    break
                }
            }
        }
        let metadata = object["metadata"] as? [String: Any]
        let runArtifactId = object["run_artifact_id"] as? String
            ?? metadata?["run_artifact_id"] as? String
            ?? ""
        return AgentStreamEvent(
            kind: kind,
            content: content,
            name: object["name"] as? String ?? "",
            nodeId: object["node_id"] as? String ?? "",
            timestamp: object["timestamp"] as? Double ?? 0,
            runArtifactId: runArtifactId
        )
    }
}
