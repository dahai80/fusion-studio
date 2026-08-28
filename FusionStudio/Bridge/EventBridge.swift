import Foundation
import Combine
import os.log

private let eventBridgeLog = Logger(subsystem: "com.fusion.studio", category: "EventBridge")

// #346: fusion-event 感知层守护 (UDS NDJSON JSON-RPC 2.0, /tmp/fusion-event.sock)。
// FSEvents → fusion-event → event.notification push → studio 消费 → 触发 Agent Swarm。
// 长连接 readLoop: 订阅 event.subscribe, 收 event.notification 解析 SystemEvent,
// 收 event.heartbeat 回 event.pong (15s 心跳, 45s 无 pong 被守护踢), 断线 5s 重连。
// 规则管理 rule.add/remove/list 走短连接 udsCall。守护缺席 fail-open (FileWatcher 兜底)。

enum EventError: Error, LocalizedError {
    case daemonDown
    case rpcError(code: Int, message: String)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .daemonDown: return "fusion-event 守护未运行"
        case .rpcError(let c, let m): return "event RPC 错误 (\(c)): \(m)"
        case .invalidResponse: return "event 响应无效"
        }
    }
}

// SystemEventType mirror upstream (fusion-event SystemEvent.type, 未知值兜底 .unknown)
enum SystemEventType: String, Codable {
    case fileModified
    case processTerminated
    case clipboardChanged
    case networkStatusChanged
    case unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SystemEventType(rawValue: raw) ?? .unknown
    }
}

// SystemEvent DTO mirror upstream {eventId,type,targetPath,timestamp,payload,nodeId}
struct SystemEvent: Codable, Identifiable {
    let eventId: String
    let type: SystemEventType
    let targetPath: String?
    let timestamp: UInt64
    let payload: [String: String]
    let nodeId: String?
    var id: String { eventId }
}

struct EventDaemonHealth: Codable {
    let ok: Bool
    let version: String?
    let schemaVersion: Int?
    let uptimeSec: Int?
    let sources: [String]?
    let triggers: Int?
    let sock: String?
    let nodeId: String?
    enum CodingKeys: String, CodingKey {
        case ok, version, sock, sources, triggers
        case schemaVersion = "schema_version"
        case uptimeSec = "uptime_sec"
        case nodeId = "node_id"
    }
}

struct EventRule: Codable, Identifiable {
    let ruleName: String
    let eventType: String
    let targetAgent: String
    let pathPattern: String?
    let debounceMs: Int?
    let enabled: Bool?
    var id: String { ruleName }
}

// MARK: - EventBridge

final class EventBridge: ObservableObject {

    // 跨非-View 对象的便捷路径: app 注入后设 shared (mirror GuardBridge.shared)。
    static var shared: EventBridge?

    @Published var isDaemonReady: Bool = false
    @Published var events: [SystemEvent] = []          // 活跃事件流 (LRU 上限 500)
    @Published var health: EventDaemonHealth?
    @Published var rules: [EventRule] = []
    @Published var lastError: String?

    private static let maxEvents = 500
    private let socketPath: String
    private var ipc: IPCClient?
    private var streamTask: Task<Void, Never>?
    private var streamSock: Int32 = -1
    private var reconnectTask: Task<Void, Never>?
    private var nextReqId: Int = 1
    // 审计0827 P0-3: 重连退避计数。连接成功清零, 失败递增 → 指数退避 (5s→10s→20s... cap 60s) + jitter,
    // 防零抖动惊群 + 长时间守护缺席时的 fd/Task 堆积。
    private var reconnectAttempt: Int = 0
    // readLoop SO_RCVTIMEO: 非 0 使 read 周期性返回 EAGAIN/EWOULDBLOCK, 给 Task.isCancelled 检查点;
    // 旧 {0,0} 阻塞读 → Task.cancel 无法中断 syscall → stopStream 不生效 → fd/Task 泄漏 (审计0827 P0-3)。
    // 15s 对齐守护心跳间隔 (event.heartbeat 15s), 期间必有一次唤醒。
    private static let readTimeoutSec: Int = 15

    init() {
        self.socketPath = FusionConfig.shared.expandedUpstreamPath(
            FusionConfig.shared.fusionEventSocketPath
        )
        eventBridgeLog.info("EventBridge init socket=\(self.socketPath, privacy: .public)")
    }

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
        eventBridgeLog.info("EventBridge IPCClient wired")
    }

    // MARK: - 守护状态 (短连接 udsCall)

    func checkDaemonStatus() async {
        do {
            let res = try await rpc(method: RPCMethod.eventHealth)
            guard let data = try? JSONSerialization.data(withJSONObject: res),
                  let h = try? JSONDecoder().decode(EventDaemonHealth.self, from: data) else {
                throw EventError.invalidResponse
            }
            await MainActor.run {
                self.isDaemonReady = h.ok
                self.health = h
                self.lastError = nil
            }
            eventBridgeLog.info("event.health ok=\(h.ok) version=\(h.version ?? "-", privacy: .public) uptime=\(h.uptimeSec ?? -1)s triggers=\(h.triggers ?? -1)")
        } catch {
            await MainActor.run {
                self.isDaemonReady = false
                self.lastError = BridgeError.sanitize(error)
            }
            eventBridgeLog.warning("event.health failed (daemon down?): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 长连接流 (raw POSIX UDS + NDJSON, mirror spaceChatStreamEvents 但持久 + 心跳 + 重连)

    func startStream() {
        guard streamTask == nil else { return }
        eventBridgeLog.info("EventBridge startStream socket=\(self.socketPath, privacy: .public)")
        streamTask = Task { await self.runStream() }
    }

    func stopStream() {
        reconnectTask?.cancel()
        reconnectTask = nil
        streamTask?.cancel()
        streamTask = nil
        if streamSock >= 0 {
            close(streamSock)
            streamSock = -1
        }
        eventBridgeLog.info("EventBridge stopStream")
    }

    private func runStream() async {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            eventBridgeLog.error("event stream socket() failed")
            await markDisconnected()
            scheduleReconnect()
            return
        }
        // P0-3: 非 0 SO_RCVTIMEO 使 readLoop 周期性唤醒, 可被 Task.cancel 中断 (旧 {0,0} 阻塞死)。
        var tv = timeval(tv_sec: Self.readTimeoutSec, tv_usec: 0)
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathC = socketPath.utf8CString
        let pathLen = min(pathC.count, MemoryLayout.size(ofValue: addr.sun_path))
        _ = pathC.withUnsafeBufferPointer { src in
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst.copyMemory(from: UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(src.baseAddress!),
                    count: pathLen
                ))
            }
        }
        let conn = Darwin.connect(sock, withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, socklen_t(MemoryLayout<sockaddr_un>.size))
        guard conn >= 0 else {
            eventBridgeLog.warning("event stream connect failed (daemon down?)")
            close(sock)
            await markDisconnected()
            scheduleReconnect()
            return
        }
        streamSock = sock
        let reqId = nextReqId
        nextReqId += 1
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": reqId,
            "method": RPCMethod.eventSubscribe,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: request) else {
            close(sock); streamSock = -1
            await markDisconnected()
            scheduleReconnect()
            return
        }
        var writeBuf = data
        writeBuf.append(0x0A)
        writeBuf.withUnsafeBytes { ptr in
            _ = Darwin.write(sock, ptr.baseAddress, writeBuf.count)
        }
        eventBridgeLog.info("event stream event.subscribe sent")
        await MainActor.run {
            self.isDaemonReady = true
            // 连接成功 → 重置退避计数, 下次断线从 5s 起算 (审计0827 P0-3)。
            self.reconnectAttempt = 0
        }

        var lineBuf = Data()
        var readBuf = [UInt8](repeating: 0, count: 16384)
        while !Task.isCancelled {
            let n = readBuf.withUnsafeMutableBufferPointer { Darwin.read(sock, $0.baseAddress!, $0.count) }
            if n > 0 {
                lineBuf.append(contentsOf: readBuf[0..<n])
                while let nlIdx = lineBuf.firstIndex(of: 0x0A) {
                    let lineData = lineBuf.subdata(in: 0..<nlIdx)
                    lineBuf.removeSubrange(0...nlIdx)
                    guard !lineData.isEmpty,
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
                    handleLine(json, sock: sock)
                }
            } else if n == 0 {
                // EOF = 对端关闭, 退出重连。
                break
            } else {
                // n < 0: SO_RCVTIMEO 超时返 EAGAIN/EWOULDBLOCK → 非真断, 回到 while 顶查 Task.isCancelled 后续读;
                // 其他 errno (EINTR 等) 同样续读。真错误才 break。旧实现无超时, n<0 恒 break →
                // 设非 0 timeout 后会误把每次超时当断线 → 无限重连风暴, 此处区分修复 (审计0827 P0-3)。
                let e = errno
                if e == EAGAIN || e == EWOULDBLOCK || e == EINTR {
                    continue
                }
                eventBridgeLog.warning("event stream read errno=\(e) (\(String(cString: strerror(e)), privacy: .public))")
                break
            }
        }
        close(sock)
        streamSock = -1
        eventBridgeLog.warning("event stream readLoop ended (disconnected)")
        await markDisconnected()
        scheduleReconnect()
    }

    private func handleLine(_ json: [String: Any], sock: Int32) {
        let method = json["method"] as? String ?? ""
        if method == "event.notification" {
            guard let params = json["params"] as? [String: Any],
                  let evDict = params["event"] as? [String: Any] else {
                eventBridgeLog.warning("event.notification missing params.event")
                return
            }
            guard let data = try? JSONSerialization.data(withJSONObject: evDict),
                  let ev = try? JSONDecoder().decode(SystemEvent.self, from: data) else {
                eventBridgeLog.warning("event.notification parse failed: \(evDict)")
                return
            }
            eventBridgeLog.info("event.notification type=\(ev.type.rawValue, privacy: .public) path=\(ev.targetPath ?? "-", privacy: .public)")
            Task { @MainActor in
                self.events.append(ev)
                self.trimEvents()
            }
        } else if method == "event.heartbeat" {
            let pong = #"{"jsonrpc":"2.0","method":"event.pong"}"# + "\n"
            if let pData = pong.data(using: .utf8) {
                _ = pData.withUnsafeBytes { ptr in
                    Darwin.write(sock, ptr.baseAddress, pData.count)
                }
                eventBridgeLog.info("event.pong sent (heartbeat reply)")
            }
        } else if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "event stream error"
            let code = error["code"] as? Int ?? -1
            eventBridgeLog.error("event stream rpc error code=\(code) msg=\(msg, privacy: .public)")
        } else if method == "event.subscribe" {
            let subscribed = (json["result"] as? [String: Any])?["subscribed"] as? Bool
                ?? (json["result"] as? Bool) ?? false
            eventBridgeLog.info("event.subscribe ACK subscribed=\(subscribed)")
        }
    }

    @MainActor
    private func markDisconnected() async {
        self.isDaemonReady = false
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectAttempt += 1
        // 审计0827 P0-3: 指数退避 (5s base ×2^attempt) cap 60s + 0~1s jitter, 防零抖动惊群 + 守护长缺席时
        // fd/Task 堆积。Math.random 不可用, 用 attempt 派生确定性偏移 (非安全随机, 仅抖动够用)。
        let baseSec = min(5 * (1 << min(reconnectAttempt - 1, 4)), 60)
        let jitterMs = (reconnectAttempt * 137) % 1000
        let delayNs = UInt64(baseSec) * 1_000_000_000 + UInt64(jitterMs) * 1_000_000
        eventBridgeLog.info("event stream reconnect in \(baseSec)s+\(jitterMs)ms (attempt #\(self.reconnectAttempt))")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard let self = self, !Task.isCancelled else { return }
            eventBridgeLog.info("event stream reconnecting...")
            self.streamTask = nil
            self.startStream()
        }
    }

    @MainActor
    private func trimEvents() {
        while events.count > Self.maxEvents {
            events.removeFirst()
        }
    }

    // MARK: - 规则管理 (短连接 udsCall, 请求/响应非流)

    func listRules() async {
        do {
            let res = try await rpc(method: RPCMethod.ruleList)
            // daemon 返回 rules 为 JSON 字符串 (stringified array), 非 native array。
            // 兼容两种: 字符串 → 先解 JSON 再 decode; 数组 → 直接 decode。
            let rulesData: Data
            if let raw = res["rules"] as? String, let d = raw.data(using: .utf8) {
                rulesData = d
            } else if let arr = res["rules"] as? [[String: Any]],
                      let d = try? JSONSerialization.data(withJSONObject: arr) {
                rulesData = d
            } else {
                rulesData = Data("[]".utf8)
            }
            let decoded = (try? JSONDecoder().decode([EventRule].self, from: rulesData)) ?? []
            await MainActor.run {
                self.rules = decoded
                self.lastError = nil
            }
            eventBridgeLog.info("rule.list ok count=\(decoded.count)")
        } catch {
            await MainActor.run { self.lastError = BridgeError.sanitize(error) }
            eventBridgeLog.warning("rule.list failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func addRule(name: String, eventType: String, targetAgent: String,
                 pathPattern: String?, debounceMs: Int?) async throws {
        var params: [String: Any] = [
            "rule_name": name,
            "event_type": eventType,
            "target_agent": targetAgent,
        ]
        if let pp = pathPattern, !pp.isEmpty { params["path_pattern"] = pp }
        if let d = debounceMs { params["debounce_ms"] = d }
        _ = try await rpc(method: RPCMethod.ruleAdd, params: params)
        eventBridgeLog.info("rule.add ok name=\(name, privacy: .public) type=\(eventType, privacy: .public) agent=\(targetAgent, privacy: .public)")
        await listRules()
    }

    func removeRule(name: String) async throws {
        _ = try await rpc(method: RPCMethod.ruleRemove, params: ["rule_name": name])
        eventBridgeLog.info("rule.remove ok name=\(name, privacy: .public)")
        await listRules()
    }

    // MARK: - UDS JSON-RPC 传输 (复用 IPCClient.udsCall)

    private func rpc(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        guard let ipc = ipc else {
            eventBridgeLog.error("rpc before IPCClient wired: \(method, privacy: .public)")
            throw EventError.daemonDown
        }
        do {
            return try await ipc.udsCall(socketPath: socketPath, method: method, params: params, timeoutSecs: 8)
        } catch let ipcErr as IPCError {
            if case .disconnected = ipcErr { throw EventError.daemonDown }
            if case .rpcError(let code, let msg) = ipcErr { throw EventError.rpcError(code: code, message: msg) }
            throw EventError.invalidResponse
        } catch {
            throw EventError.daemonDown
        }
    }
}
