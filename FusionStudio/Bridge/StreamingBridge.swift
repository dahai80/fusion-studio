// Callers: UnifiedChatView, AgentStudioView — real-time streaming event bridge
// Affected API: StreamingBridge (streamEvents auto-trim at 500, trimStreamEvents, memoryCheckMB)
// Data schemas: StreamChatEvent (type/sessionId/event), published as @Published streamEvents
// User instruction: "按照P1~P6顺序实施所有未完成的任务" — Task #37 P6-3 内存泄漏检测+长时间运行稳定性

import Combine
import Foundation
import MachO
import Network
import os.log

private let bridgeLog = Logger(subsystem: "com.fusion.studio", category: "AgentBridge")

struct StreamChatEvent: Identifiable {
    let id = UUID()
    let sessionId: String
    let eventType: String
    let content: String
    let name: String
    let args: [String: Any]
    let timestamp: Double

    init(sessionId: String, eventType: String, content: String = "", name: String = "", args: [String: Any] = [:], timestamp: Double = 0) {
        self.sessionId = sessionId
        self.eventType = eventType
        self.content = content
        self.name = name
        self.args = args
        self.timestamp = timestamp
    }

    var isToken: Bool { eventType == "token" }
    var isDone: Bool { eventType == "done" }
    var isToolCall: Bool { eventType == "tool_call" }
    var isToolResult: Bool { eventType == "tool_result" }
    var isThinking: Bool { eventType == "thinking" }
    var isError: Bool { eventType == "error" }
}

@MainActor
class StreamingBridge: ObservableObject {
    @Published var streamEvents: [StreamChatEvent] = []
    @Published var isStreaming: Bool = false
    @Published var isConnected: Bool = false

    private static let maxStreamEvents = 500

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.fusion-studio.ws", qos: .userInitiated)
    private let wsHost: String
    private let wsPort: UInt16
    private var reconnectTimer: Timer?
    private var activeSessionId: String = ""
    private var accumulatedContent: String = ""

    init(host: String = "127.0.0.1", port: UInt16 = 11435) {
        self.wsHost = host
        self.wsPort = port
    }

    func connect() {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(wsHost), port: NWEndpoint.Port(rawValue: wsPort)!)
        let parameters = NWParameters.tcp
        let conn = NWConnection(to: endpoint, using: parameters)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.reconnectTimer?.invalidate()
                    self.reconnectTimer = nil
                    bridgeLog.info("AgentBridge connected to WS")
                case .failed, .cancelled:
                    self.isConnected = false
                    self.scheduleReconnect()
                    bridgeLog.warning("AgentBridge disconnected, scheduling reconnect")
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
        receiveLoop()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    func streamChat(sessionId: String, message: String, mode: String = "") {
        guard let conn = connection else { return }

        activeSessionId = sessionId
        accumulatedContent = ""
        isStreaming = true
        streamEvents = []

        var msg: [String: Any] = [
            "action": "chat.stream",
            "session_id": sessionId,
            "message": message,
        ]
        if !mode.isEmpty {
            msg["mode"] = mode
        }

        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let str = String(data: data, encoding: .utf8) else { return }

        let payload = (str + "\n").data(using: .utf8)!
        conn.send(content: payload, completion: .contentProcessed { error in
            if let error = error {
                bridgeLog.error("WS send failed: \(error.localizedDescription)")
            }
        })
    }

    private func receiveLoop() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.processIncoming(data)
            }
            if error == nil {
                self?.receiveLoop()
            }
        }
    }

    private func processIncoming(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let msg = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let type = msg["type"] as? String ?? ""

            if type == "chat_event", let eventDict = msg["event"] as? [String: Any] {
                let sessionId = msg["session_id"] as? String ?? ""
                let eventType = eventDict["type"] as? String ?? ""
                let content = eventDict["content"] as? String ?? ""
                let name = eventDict["name"] as? String ?? ""
                let args = eventDict["args"] as? [String: Any] ?? [:]
                let timestamp = eventDict["timestamp"] as? Double ?? 0

                let event = StreamChatEvent(
                    sessionId: sessionId,
                    eventType: eventType,
                    content: content,
                    name: name,
                    args: args,
                    timestamp: timestamp
                )

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.streamEvents.append(event)
                    self.trimStreamEvents()
                    if event.isToken {
                        self.accumulatedContent += event.content
                    }
                }
            } else if type == "chat_done" {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isStreaming = false
                    bridgeLog.info("Stream done for session, content length: \(self.accumulatedContent.count)")
                }
            }
        }
    }

    private func trimStreamEvents() {
        if streamEvents.count > Self.maxStreamEvents {
            let dropCount = streamEvents.count - Self.maxStreamEvents
            streamEvents.removeFirst(dropCount)
            let kept = streamEvents.count
            bridgeLog.info("StreamingBridge: trimmed \(dropCount) old events, keeping \(kept)")
        }
    }

    func memoryCheckMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                self?.connect()
            }
        }
    }
}
