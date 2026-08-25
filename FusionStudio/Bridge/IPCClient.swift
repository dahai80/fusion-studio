import Foundation
import Combine
import os.log

let ipcLog = Logger(subsystem: "com.fusion.studio", category: "IPCClient")

/// IPC 通信客户端 — Unix Domain Socket + JSON-RPC 2.0
class IPCClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?
    // F-A16: RPC schema 协商。connect 后调 rpc.discover 缓存上游 method 集,
    // 检查关键方法存在性, schema 漂移时 error 日志 + 标志暴露, 防 B7 静默崩。
    // nil=未知(未discover/discover失败/旧上游无此方法), true=关键方法齐, false=缺关键方法。
    @Published var schemaCompatible: Bool? = nil
    @Published var availableMethods: [String] = []
    // 客户端依赖的关键方法子集 — 任一缺失即 schemaCompatible=false (schema 漂移)。
    private let criticalMethods: Set<String> = [
        "ping", "agent.execute", "task.submit", "env.health_check", "mlx.status"
    ]

    private let socketPath: String
    private var requestId: Int = 0
    private var socketFd: Int32 = -1
    private let queue = DispatchQueue(label: "com.fusion-studio.ipc", qos: .userInitiated)
    // 读取循环独占的 queue, 不能与发送/超时共用串行 queue, 否则 while 死循环会饿死所有 call() 导致续体永不 resume (Workflows 转圈根因)
    private let readQueue = DispatchQueue(label: "com.fusion-studio.ipc.read", qos: .userInitiated)
    private var reconnectTimer: Timer?
    // 续体直接存储：handleResponse / 超时 / 断连 三处 removeValue 取出并 resume，保证恰好一次
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private let lock = NSLock()
    // F-A4: pending 容量上限, 防高频 onAppear fetch 风暴 + daemon 慢响应堆续体致 OOM。
    // 超限直接 reject 抛错并日志, 不注册新续体 (8s 窗口内狂切 Tab 可堆数千 pending)。
    private let pendingCap = 100

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
        // F-A16: 连接建立后异步协商 schema, 不阻塞连接 (旧上游无 rpc.discover 时容错降级)。
        Task { [weak self] in await self?.discoverSchema() }
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
                // F-A16: 断连清 schema 状态, 重连后重新 discover。
                self.schemaCompatible = nil
                self.availableMethods = []
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

    /// 原子自增请求 id。call() 跑在串行 queue, udsCall() 跑在并发 global queue, 共用同一计数器必须加锁, 否则并发 udsCall 同毫秒时间戳撞 id (PERF-2)
    private func nextRequestId() -> Int {
        lock.lock()
        requestId += 1
        let id = requestId
        lock.unlock()
        return id
    }

    /// 调用远程方法
    @discardableResult
    func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                let reqId = self.nextRequestId()

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

                // 注册续体
                self.lock.lock()
                // F-A4: pending 容量上限, daemon 慢响应/断连 + 狂切 Tab 堆续体致 OOM。超限直接 reject。
                if self.pendingRequests.count >= self.pendingCap {
                    self.lock.unlock()
                    ipcLog.error("IPC pending cap exceeded (\(self.pendingCap, privacy: .public)), reject method=\(method, privacy: .public) id=\(reqId)")
                    continuation.resume(throwing: IPCError.pendingFull)
                    return
                }
                self.pendingRequests[reqId] = continuation
                self.lock.unlock()

                // 超时保护：8s 无响应即失败，避免 daemon 不回包时续体泄露、调用永久挂起 (bug3/bug4)
                self.queue.asyncAfter(deadline: .now() + 8) { [weak self] in
                    guard let self = self else { return }
                    self.lock.lock()
                    let pending = self.pendingRequests.removeValue(forKey: reqId)
                    self.lock.unlock()
                    if let pending = pending {
                        ipcLog.warning("IPC call timeout: method=\(method, privacy: .public) id=\(reqId)")
                        pending.resume(throwing: IPCError.timeout)
                    }
                }

                // 发送数据
                var writeBuf = data
                writeBuf.append(0x0A) // 换行符作为消息分隔符
                writeBuf.withUnsafeBytes { ptr in
                    Darwin.write(self.socketFd, ptr.baseAddress, writeBuf.count)
                }
            }
        }
    }

    // MARK: - 通用 UDS 调用 (非主 socket 上游: project-svc / cowork desk_rpc)

    // Callers: projectCall / spaceCall. Affected API: udsCall(socketPath:method:params:) -> [String:Any].
    // 每次新建短连接, 换行分隔 JSON-RPC 2.0; 结果归一化: dict 原样 / array 包成 ["items":...] / 标量包成 ["_result":...]
    @discardableResult
    func udsCall(socketPath: String, method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_UNIX, SOCK_STREAM, 0)
                guard sock >= 0 else {
                    continuation.resume(throwing: IPCError.invalidRequest)
                    return
                }
                defer { close(sock) }
                var tv = timeval(tv_sec: 8, tv_usec: 0)
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
                    ipcLog.warning("udsCall connect failed path=\(socketPath, privacy: .public) method=\(method, privacy: .public)")
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }
                var request: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": self.nextRequestId(),
                    "method": method,
                ]
                if !params.isEmpty { request["params"] = params }
                guard let data = try? JSONSerialization.data(withJSONObject: request) else {
                    continuation.resume(throwing: IPCError.invalidRequest)
                    return
                }
                var writeBuf = data
                writeBuf.append(0x0A)
                writeBuf.withUnsafeBytes { ptr in
                    _ = Darwin.write(sock, ptr.baseAddress, writeBuf.count)
                }
                var respData = Data()
                var buf = [UInt8](repeating: 0, count: 8192)
                while true {
                    let n = buf.withUnsafeMutableBufferPointer { Darwin.read(sock, $0.baseAddress!, $0.count) }
                    if n > 0 {
                        respData.append(contentsOf: buf[0..<n])
                        if respData.last == 0x0A { break }
                    } else {
                        break
                    }
                }
                guard !respData.isEmpty,
                      let nlIdx = respData.firstIndex(of: 0x0A),
                      let json = try? JSONSerialization.jsonObject(with: respData.subdata(in: 0..<nlIdx)) as? [String: Any] else {
                    ipcLog.warning("udsCall invalid response method=\(method, privacy: .public) path=\(socketPath, privacy: .public)")
                    continuation.resume(throwing: IPCError.invalidResponse)
                    return
                }
                if let error = json["error"] as? [String: Any] {
                    let code = error["code"] as? Int ?? -1
                    let msg = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: IPCError.rpcError(code: code, message: msg))
                    return
                }
                if let result = json["result"] as? [String: Any] {
                    continuation.resume(returning: result)
                } else if let arr = json["result"] as? [Any] {
                    continuation.resume(returning: ["items": arr])
                } else if json["result"] != nil {
                    continuation.resume(returning: ["_result": json["result"]!])
                } else {
                    continuation.resume(returning: [:])
                }
            }
        }
    }

    // MARK: - 读取循环

    private func startReading() {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            var buffer = Data()
            // 4KB 块读 + 0x0A 分割。单字节 read 每字节一次 syscall, 大响应 (model.list/model.detail) 上千次 read, 系统调用风暴 (PERF-1)
            var readBuf = [UInt8](repeating: 0, count: 4096)

            while self.socketFd >= 0 {
                let n = readBuf.withUnsafeMutableBufferPointer { Darwin.read(self.socketFd, $0.baseAddress!, $0.count) }
                if n > 0 {
                    // 块内按 0x0A 切分, 一次 read 可能含多条消息
                    for i in 0..<n {
                        let byte = readBuf[i]
                        if byte == 0x0A {
                            self.handleResponse(buffer)
                            buffer = Data()
                        } else {
                            buffer.append(byte)
                        }
                    }
                } else if n == 0 {
                    self.drainPending()
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                } else if errno == EAGAIN {
                    Thread.sleep(forTimeInterval: 0.01)
                } else {
                    self.drainPending()
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                }
            }
        }
    }

    private func handleResponse(_ data: Data) {
        // F-R5: 旧 try? 吞 JSON 解码错无日志, malformed 帧静默丢, 无 RPC 契约诊断。
        // 改 do/catch: 解码失败记日志 (数据片段截断 200B), 早退 (无 id 无法匹配续体)。
        var json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<bin>"
                ipcLog.error("handleResponse JSON not a dict: \(snippet, privacy: .public)")
                return
            }
            json = parsed
        } catch {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<bin>"
            ipcLog.error("handleResponse JSON decode failed: \(error.localizedDescription, privacy: .public) data=\(snippet, privacy: .public)")
            return
        }
        guard let id = json["id"] as? Int else {
            ipcLog.warning("handleResponse missing id, dropping frame")
            return
        }

        lock.lock()
        let cont = pendingRequests.removeValue(forKey: id)
        lock.unlock()
        guard let cont = cont else {
            ipcLog.warning("handleResponse no pending continuation for id=\(id)")
            return
        }

        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "未知错误"
            cont.resume(throwing: IPCError.rpcError(code: code, message: msg))
        } else if let result = json["result"] {
            // F-R5: 旧 `as? [String: Any] ?? [:]` 静默吞非 dict result (array/scalar 降级空 dict)。
            // array 包 items, scalar 包 _result, dict 原样, 其他记日志再降级。
            if let dict = result as? [String: Any] {
                cont.resume(returning: dict)
            } else if let arr = result as? [Any] {
                cont.resume(returning: ["items": arr])
            } else {
                ipcLog.warning("handleResponse result non-dict/array id=\(id), wrapping _result")
                cont.resume(returning: ["_result": result])
            }
        } else {
            ipcLog.warning("handleResponse no result field id=\(id), returning empty")
            cont.resume(returning: [:])
        }
    }

    /// 断连时排空所有挂起请求，resume 为 .disconnected，避免续体泄露 (bug3/bug4)
    private func drainPending() {
        lock.lock()
        let pending = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()
        guard !pending.isEmpty else { return }
        ipcLog.warning("IPC drain \(pending.count, privacy: .public) pending requests on disconnect")
        for (_, cont) in pending {
            cont.resume(throwing: IPCError.disconnected)
        }
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

    // F-A16: 调 rpc.discover 缓存上游 method 集 + 关键方法存在性检查。
    // 失败/旧上游无此方法 → schemaCompatible=nil (乐观降级, 不阻断连接), 仅 warning 日志。
    // 成功: 缺关键方法 → schemaCompatible=false + error 日志列缺失方法 (schema 漂移预警)。
    private func discoverSchema() async {
        do {
            let result = try await call(method: "rpc.discover")
            let methods = (result["methods"] as? [String]) ?? []
            await MainActor.run {
                self.availableMethods = methods
                let methodSet = Set(methods)
                let missing = criticalMethods.subtracting(methodSet)
                if methods.isEmpty {
                    self.schemaCompatible = nil
                    ipcLog.warning("F-A16 discover: empty method list, schema unknown")
                } else if missing.isEmpty {
                    self.schemaCompatible = true
                    ipcLog.info("F-A16 discover: schema OK, \(methods.count) methods available")
                } else {
                    self.schemaCompatible = false
                    ipcLog.error("F-A16 discover: SCHEMA DRIFT — missing critical methods: \(missing.sorted().joined(separator: ", ")) — upstream RPC 不兼容, 调用这些方法将失败")
                }
            }
        } catch {
            await MainActor.run {
                self.schemaCompatible = nil
                ipcLog.warning("F-A16 discover: rpc.discover failed (\(error.localizedDescription)), schema unknown (旧上游?)")
            }
        }
    }

    // F-A16: 调用前可选守卫 — 已 discover 则查存在性, 未 discover 乐观放行 (兼容旧上游)。
    func responds(to method: String) -> Bool {
        if availableMethods.isEmpty { return true }
        return availableMethods.contains(method)
    }

    // MARK: - 辅助方法

    private func setError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = msg
            self?.isConnected = false
            // F-A16: 断连清 schema 状态, 重连后重新 discover。
            self?.schemaCompatible = nil
            self?.availableMethods = []
        }
    }

    // Callers: HubClusterView, HubLocalStorageView. Affected API: fusion-multi-node REST 34 endpoints.
    // Multi-Node methods moved to IPCMultiNodeMethods.swift extension (#74).

    deinit {
        reconnectTimer?.invalidate()
        if socketFd >= 0 {
            close(socketFd)
        }
    }
}
