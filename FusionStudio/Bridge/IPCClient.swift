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