import Foundation
import Combine

/// IPC 通信客户端 — Unix Domain Socket + JSON-RPC 2.0
class IPCClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private let socketPath: String
    private var requestId: Int = 0
    private var socketFd: Int32 = -1
    private let queue = DispatchQueue(label: "com.fusion-studio.ipc", qos: .userInitiated)
    private var reconnectTimer: Timer?
    private var pendingRequests: [Int: (Data) -> Void] = [:]
    private let lock = NSLock()

    init(socketPath: String = "/tmp/fusion-studio.sock") {
        self.socketPath = socketPath
        connect()
    }

    // MARK: - 连接管理

    func connect() {
        queue.async { [weak self] in
            self?.performConnect()
        }
    }

    private func performConnect() {
        // 关闭旧连接
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }

        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            setError("无法创建 socket: \(String(cString: strerror(errno)))")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCString = socketPath.utf8CString
        let pathLen = min(pathCString.count, MemoryLayout.size(ofValue: addr.sun_path))
        _ = pathCString.withUnsafeBufferPointer { src in
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst.copyMemory(from: UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(src.baseAddress!),
                    count: pathLen
                ))
            }
        }

        let fd = Darwin.connect(sock, withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, socklen_t(MemoryLayout<sockaddr_un>.size))

        guard fd >= 0 else {
            close(sock)
            let errMsg = String(cString: strerror(errno))
            setError("连接失败 (\(errMsg))")
            scheduleReconnect()
            return
        }

        // 设置非阻塞
        var flags = fcntl(sock, F_GETFL, 0)
        fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        socketFd = sock
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.lastError = nil
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = nil
        }
        startReading()
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.socketFd >= 0 {
                close(self.socketFd)
                self.socketFd = -1
            }
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.connect()
            }
        }
    }

    // MARK: - JSON-RPC 调用

    /// 调用远程方法
    @discardableResult
    func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                self.requestId += 1
                let reqId = self.requestId

                var request: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": reqId,
                    "method": method,
                ]
                if !params.isEmpty {
                    request["params"] = params
                }

                guard let data = try? JSONSerialization.data(withJSONObject: request) else {
                    continuation.resume(throwing: IPCError.invalidRequest)
                    return
                }

                guard self.socketFd >= 0 else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                // 注册等待回调
                self.lock.lock()
                self.pendingRequests[reqId] = { responseData in
                    do {
                        if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                            if let error = json["error"] as? [String: Any] {
                                let code = error["code"] as? Int ?? -1
                                let msg = error["message"] as? String ?? "未知错误"
                                continuation.resume(throwing: IPCError.rpcError(code: code, message: msg))
                            } else if let result = json["result"] {
                                continuation.resume(returning: result as? [String: Any] ?? [:])
                            } else {
                                continuation.resume(returning: [:])
                            }
                        } else {
                            continuation.resume(throwing: IPCError.invalidResponse)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                self.lock.unlock()

                // 发送数据
                var writeBuf = data
                writeBuf.append(0x0A) // 换行符作为消息分隔符
                writeBuf.withUnsafeBytes { ptr in
                    Darwin.write(self.socketFd, ptr.baseAddress, writeBuf.count)
                }
            }
        }
    }

    // MARK: - 读取循环

    private func startReading() {
        queue.async { [weak self] in
            guard let self = self else { return }
            var buffer = Data()

            while self.socketFd >= 0 {
                var byte: UInt8 = 0
                let n = Darwin.read(self.socketFd, &byte, 1)
                if n > 0 {
                    if byte == 0x0A {
                        // 完整消息
                        self.handleResponse(buffer)
                        buffer = Data()
                    } else {
                        buffer.append(byte)
                    }
                } else if n == 0 {
                    // 连接关闭
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                } else if errno != EAGAIN {
                    // 错误
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                }
                // EAGAIN = 无数据可读，继续循环
            }
        }
    }

    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else { return }

        lock.lock()
        let handler = pendingRequests.removeValue(forKey: id)
        lock.unlock()

        handler?(data)
    }

    // MARK: - 便捷方法

    func healthCheck() async throws -> [String: Any] {
        return try await call(method: "env.health_check")
    }

    func repair(itemId: String) async throws -> [String: Any] {
        return try await call(method: "env.repair", params: ["item_id": itemId])
    }

    func repairAll() async throws -> [String: Any] {
        return try await call(method: "env.repair_all")
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        return try await call(method: "mlx.start", params: ["model": model])
    }

    func stopMLX() async throws -> [String: Any] {
        return try await call(method: "mlx.stop")
    }

    func mlxStatus() async throws -> [String: Any] {
        return try await call(method: "mlx.status")
    }

    func hardwareMetrics() async throws -> [String: Any] {
        return try await call(method: "hardware.metrics")
    }

    func submitTask(type: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p = params
        p["type"] = type
        return try await call(method: "task.submit", params: p)
    }

    func ping() async throws -> Bool {
        let result = try await call(method: "ping")
        return result["pong"] as? Bool ?? false
    }

    // MARK: - Artifacts Engine (HTTP JSON-RPC on port 8900)

    private let artifactsEngineURL = "http://127.0.0.1:8900"

    private func artifactsCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000),
            "method": method,
        ]
        if !params.isEmpty {
            request["params"] = params
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: request) else {
            throw IPCError.invalidRequest
        }
        guard let url = URL(string: artifactsEngineURL) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "Unknown error"
            throw IPCError.rpcError(code: code, message: msg)
        }
        return json["result"] as? [String: Any] ?? [:]
    }

    func artifactCreate(sessionId: String, name: String, type: String, content: String, summary: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [
            "session_id": sessionId,
            "name": name,
            "type": type,
            "content": content,
        ]
        if let s = summary { params["summary"] = s }
        return try await artifactsCall(method: "artifact.create", params: params)
    }

    func artifactGet(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.get", params: ["artifact_id": artifactId])
    }

    func artifactGetContent(artifactId: String, version: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId]
        if let v = version { params["version"] = v }
        return try await artifactsCall(method: "artifact.get_content", params: params)
    }

    func artifactList(sessionId: String, includeDeleted: Bool = false) async throws -> [String: Any] {
        var params: [String: Any] = ["session_id": sessionId]
        if includeDeleted { params["include_deleted"] = true }
        return try await artifactsCall(method: "artifact.list", params: params)
    }

    func artifactDelete(artifactId: String, hard: Bool = false) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.delete", params: ["artifact_id": artifactId, "hard": hard])
    }

    func artifactUpdate(artifactId: String, content: String, changeLog: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId, "content": content]
        if let cl = changeLog { params["change_log"] = cl }
        return try await artifactsCall(method: "artifact.update", params: params)
    }

    func artifactVersionList(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_list", params: ["artifact_id": artifactId])
    }

    func artifactVersionRollback(artifactId: String, targetVersion: Int) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_rollback", params: ["artifact_id": artifactId, "target_version": targetVersion])
    }

    func artifactInject(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.inject", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactCheckSafety(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.check_safety", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactExport(artifactId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export", params: ["artifact_id": artifactId, "format": format])
    }

    func artifactExportSession(sessionId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export_session", params: ["session_id": sessionId, "format": format])
    }

    func artifactImport(data: [String: Any]) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.import", params: ["data": data])
    }

    func artifactPing() async throws -> Bool {
        let result = try await artifactsCall(method: "ping", params: [:])
        return result["pong"] as? Bool ?? false
    }

    // MARK: - 辅助方法

    private func setError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = msg
            self?.isConnected = false
        }
    }

    deinit {
        reconnectTimer?.invalidate()
        if socketFd >= 0 {
            close(socketFd)
        }
    }
}

// MARK: - 错误类型

enum IPCError: Error, LocalizedError {
    case disconnected
    case invalidRequest
    case invalidResponse
    case rpcError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .disconnected:      return "IPC 未连接"
        case .invalidRequest:    return "无效的请求"
        case .invalidResponse:   return "无效的响应"
        case .rpcError(_, let m): return "RPC 错误: \(m)"
        }
    }
}