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
    // F-I3: 引用 RPCMethod 常量, 单一来源, 防拼写漂移。
    private let criticalMethods: Set<String> = [
        RPCMethod.ping, RPCMethod.agentExecute, RPCMethod.taskSubmit, RPCMethod.envHealthCheck, RPCMethod.mlxStatus
    ]

    private let socketPath: String
    private var requestId: Int = 0
    private var socketFd: Int32 = -1
    private let queue = DispatchQueue(label: "com.fusion-studio.ipc", qos: .userInitiated)
    // 读取循环独占的 queue, 不能与发送/超时共用串行 queue, 否则 while 死循环会饿死所有 call() 导致续体永不 resume (Workflows 转圈根因)
    private let readQueue = DispatchQueue(label: "com.fusion-studio.ipc.read", qos: .userInitiated)
    private var reconnectTimer: Timer?
    // 审计0827 §2.4 (P1): 重连固定 3s repeats, daemon 挂时多 Bridge 每 3s 齐刷重连 = 雷群。
    // 改指数退避 + jitter: base 2s × 2^min(attempt,5) 封顶 60s, + 确定性 jitter (attempt×137)%1000 ms。
    // 连接成功复位 attempt=0 (performConnect 主线程块)。
    private var reconnectAttempt: Int = 0
    // 审计0827 §2.6 (P1): IPC 级熔断器。AgentBridge.backendCircuitOpen 只护 taskExecuteImmediate 一条,
    // 其余 ~15 RPC (taskSubmit/cronRegister/executeGraph/KV ops/tool CRUD) 裸奔 — daemon 慢响应时
    // 连锁 8s 超时堆 pending (叠加 pendingCap 截断) 行为不一致难诊断。
    // 此熔断全局护所有 call(): 连续 N 次超时/断连开路, 新 call fast-fail 抛 circuitOpen;
    // 任一成功复位 (half-open 探测)。与 AgentBridge 熔断并存: IPC 级防 pending 雪崩, task 级控重试预算。
    private let circuitThreshold: Int = 5
    private var circuitConsecutiveFailures: Int = 0
    private var circuitOpen: Bool = false
    // half-open: 开路 30s 后允许一个探测 call 穿透, 成功则复位 closed, 失败则重开并续计时。
    private let circuitRecoverySec: Double = 30
    private var circuitOpenedAt: Double = 0
    private var circuitHalfOpenProbing: Bool = false
    // 续体直接存储：handleResponse / 超时 / 断连 三处 removeValue 取出并 resume，保证恰好一次
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private let lock = NSLock()
    // F-A4: pending 容量上限, 防高频 onAppear fetch 风暴 + daemon 慢响应堆续体致 OOM。
    // 超限直接 reject 抛错并日志, 不注册新续体 (8s 窗口内狂切 Tab 可堆数千 pending)。
    // 审计0827 P0-2: 100 在稳态期 (健康轮询 + 多 Tab fetch + 狂切) 触顶, 写操作静默失败。
    // 提升到 500: 稳态并发约 80-120, 突发 3-4x 仍 < 500; 单续体 ~0.4KB, 500 项 < 200KB 内存可接受。
    private let pendingCap = 500
    // 审计0902 A5 (P2): inflightReads 每 key waiter cap (见 call 合并块)。
    private let inflightWaiterCap = 100
    // F-R4: 方法级 in-flight 去重 (同 method 在途不重发)。仅对幂等读 (空 params + *.list/status/ping/health_check)
    // 合并: 第一个 caller 驱动 socket, 后续 caller 续体挂 inflightReads 等结果 fan-out, 不重发。
    // 变更类 (mlx.stop/agent.create/*.delete/env.repair_all 等) 永不合并 — 幂等性不同, 重发是正确语义。
    private var inflightReads: [String: [CheckedContinuation<[String: Any], Error>]] = [:]
    private var reqIdToMethod: [Int: String] = [:]

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

    // F-A18 (#23): UDS 客户端 sock 文件权限校验。审计 0827 #23 — 客户端无鉴权代码,
    // 安全性全依赖服务端 sock 文件权限。连接前校验 stat(socketPath).st_mode:
    // 拒 group/other 可写 (防 0666 被替换或放松), 允 owner-only (0600) 或 owner+group (0660)。
    // 服务端侧 (daemon_server.py chmod+peer-uid) 跨工程, 已提上游 issue 对齐。
    // 返回 nil=通过, 非 nil=拒绝原因 (含实际 mode 八进制, 便日志定位)。
    // 参数化 path: 主 socket (performConnect) 与短连接通道 (udsCall) 复用同一校验 (审计0827 P0-1)。
    // F-I4: private → internal, 便 @testable import IPCClientTests 直接验权限矩阵 (0666 拒/0600 过/0644 过)。
    internal func validateSocketPermission(_ path: String) -> String? {
        // 用 FileManager 取 posix 权限, 避 Darwin stat()/struct stat 命名冲突。
        let url = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            // sock 不存在 = 服务未起, 非权限问题, 交 connect() 报 errno。
            return nil
        }
        guard let perm = attrs[.posixPermissions] as? NSNumber else { return nil }
        let permBits = perm.int16Value & 0o777
        // 拒 group/other 写位 (防 0666/0664/0646 等), 仅允 owner 写 (0600) 或 owner+group (0660)。
        if permBits & 0o022 != 0 {
            let octal = String(permBits, radix: 8)
            ipcLog.error("IPC sock perm reject: path=\(path, privacy: .public) mode=0\(octal) (group/other writable)")
            return "socket 权限过松 (mode 0\(octal), 须 owner-only 0600 或 0660)"
        }
        return nil
    }

    private func performConnect() {
        // 关闭旧连接
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }

        // F-A18 (#23): 连接前校验 sock 文件权限, 拒 group/other 可写 (防服务端 sock 被改 0666/替换)。
        if let permErr = validateSocketPermission(socketPath) {
            setError(permErr)
            scheduleReconnect()
            return
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
            // 审计0827 §2.4: 连接成功复位重连退避计数。
            self?.reconnectAttempt = 0
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
            // 审计0827 §2.4: 指数退避 + 确定性 jitter (无 Math.random — 避雷群 + 避长挂)。
            // base 2s × 2^min(attempt,5) 封顶 60s, jitter (attempt×137)%1000 ms 解同步。
            let attempt = self.reconnectAttempt
            let base = 2.0 * pow(2.0, Double(min(attempt, 5)))
            let capped = min(base, 60.0)
            let jitterMs = Double((attempt * 137) % 1000) / 1000.0
            let delay = capped + jitterMs
            if attempt > 0 {
                ipcLog.info("IPC reconnect backoff: attempt=\(attempt) delay=\(String(format: "%.2f", delay))s")
            }
            self.reconnectAttempt = attempt + 1
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect()
                // 连接失败会再次 scheduleReconnect 续退避; 成功 performConnect 复位 attempt。
            }
        }
    }

    // MARK: - JSON-RPC 调用

    /// 原子自增请求 id。call() 跑在串行 queue, udsCall() 跑在并发 global queue, 共用同一计数器必须加锁, 否则并发 udsCall 同毫秒时间戳撞 id (PERF-2)。
    /// 审计0827 §3.9.5 (P2): 原各 raw-socket 站 (spaceChatStreamEvents/multiNodeCall/artifactsCall) 用
    /// Int(Date().timeIntervalSince1970*1000) 生成 id, 同毫秒并发撞 id → 响应错配跨空间泄漏。
    /// 改统一经此原子计数器, 故由 private 升 internal 供跨文件 extension 共用。
    func nextRequestId() -> Int {
        lock.lock()
        requestId += 1
        let id = requestId
        lock.unlock()
        return id
    }

    // F-R4: 幂等读判定 — 同 method 在途可合并。空 params + 读动词 (后缀 .list 或 ping/mlx.status/env.health_check)。
    // 变更类 (stop/create/delete/update/register/repair_all 等) 即使空 params 也绝不合并 (幂等性不同)。
    private func isCoalesceableRead(_ method: String) -> Bool {
        if method == RPCMethod.ping || method == RPCMethod.mlxStatus || method == RPCMethod.envHealthCheck {
            return true
        }
        if method.hasSuffix(".list") {
            return true
        }
        return false
    }

    // F-R4: fan-out 同 method 在途读的挂起续体。handleResponse/timeout/drainPending 三路完成时调。
    private func resumeInflightReads(_ method: String, result: Result<[String: Any], Error>) {
        lock.lock()
        let waiters = inflightReads.removeValue(forKey: method)
        reqIdToMethod = reqIdToMethod.filter { $0.value != method }
        lock.unlock()
        guard let waiters = waiters, !waiters.isEmpty else { return }
        ipcLog.debug("IPC inflight coalesce fan-out method=\(method, privacy: .public) waiters=\(waiters.count)")
        for w in waiters {
            switch result {
            case .success(let v): w.resume(returning: v)
            case .failure(let e): w.resume(throwing: e)
            }
        }
    }

    // 审计0827 §2.6 (P1): half-open 探测闸 — 开路满 circuitRecoverySec 后放一个 call 穿透试探。
    // 返 true = 已转 half-open 放行该 call; false = 仍 closed-open fast-fail。跑在串行 queue 无需锁。
    // 审计0830 P2-IPC-2: 旧实现 `if circuitHalfOpenProbing { return true }` → 探测 call 在途时, 后续所有 call 也被放行,
    //   half-open 退化为批量重放 (后端仍故障则再次雪崩开路)。修复: 探测在途时后续 call fast-fail (返 false),
    //   仅发起探测的那一个 call 穿透, 等 circuitOnSuccess/Failure 解除在途标志后才放下一个。
    private func maybeHalfOpenProbe() -> Bool {
        let now = Date().timeIntervalSince1970
        // 探测已在途: 后续 call fast-fail, 等探测结果 (成功复位 / 失败重开) 再决定。
        if circuitHalfOpenProbing { return false }
        if now - circuitOpenedAt >= circuitRecoverySec {
            circuitHalfOpenProbing = true
            return true
        }
        return false
    }

    // 熔断成功复位 (half-open 探测成功 or 正常成功清连续失败)。
    private func circuitOnSuccess() {
        if circuitOpen || circuitHalfOpenProbing {
            ipcLog.info("IPC circuit closed (recovered) failures=\(self.circuitConsecutiveFailures)")
        }
        circuitConsecutiveFailures = 0
        circuitOpen = false
        circuitHalfOpenProbing = false
    }

    // 熔断失败计数 + 达阈值开路。half-open 探测失败立即重开并续计时。
    private func circuitOnFailure() {
        circuitConsecutiveFailures += 1
        circuitHalfOpenProbing = false
        if circuitConsecutiveFailures >= circuitThreshold && !circuitOpen {
            circuitOpen = true
            circuitOpenedAt = Date().timeIntervalSince1970
            ipcLog.error("IPC circuit OPEN failures=\(self.circuitConsecutiveFailures) — fast-fail pending calls until backend recovers")
        } else if circuitOpen {
            // 已开路 (half-open 探测失败): 续计时, 下个 recovery 窗口再试。
            circuitOpenedAt = Date().timeIntervalSince1970
        }
    }

    /// 调用远程方法
    @discardableResult
    func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            // 审计0902 A1 (P1) 写侧头阻塞缓解: JSONSerialization (大参数 graph.execute/design.export/
            //   model.list) 移出串行 queue, 在调用方并发上下文完成。旧在 queue.async 内序列化, 一个胖
            //   参数拖垮其后全部 call() 注册 → 全 App IPC 串行卡顿。reqId 原子自增 (lock) 可安全在
            //   queue 外取; writeAll + pending 注册仍串行保帧不交错。
            //   读侧头阻塞 (单 reader + 大响应挡道) 需请求级 socket 池, 大改, 后续 deferred。
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
            var writeBuf = data
            writeBuf.append(0x0A) // 换行符作为消息分隔符

            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                // 审计0827 §2.6 (P1): 熔断开路 fast-fail, 不注册续体不堆 pending。
                // half-open 探测: 每 30s 放一个 call 穿透试探后端是否恢复 (open 计时达 30s 即半开)。
                if self.circuitOpen {
                    if self.maybeHalfOpenProbe() {
                        ipcLog.info("IPC circuit half-open probe: method=\(method, privacy: .public)")
                    } else {
                        ipcLog.warning("IPC circuit open fast-fail: method=\(method, privacy: .public)")
                        continuation.resume(throwing: IPCError.circuitOpen)
                        return
                    }
                }

                // F-R4: 幂等读 in-flight 合并。同 method 已在途 (首个 caller 驱动) → 挂当前续体等结果, 不重发。
                // 仅对空 params 读 (params.isEmpty 守卫: 带参读如 tool.get/cron.list_executions 不合并, 入参不同结果不同)。
                // 注 (A1): reqId 已在 queue 外预分配, 合并命中时该 id 废弃 — 合并仅针对空 params 读 (序列化本廉价), 可接受。
                // 审计0902 A5 (P2): inflightReads 按 method key (受限于 ~20 个可合并读动词, 键非无界), 但每 key 下
                //   waiter 列表无 cap — 1000 并发 mlxStatus 全挂同一 in-flight 读 → 无界续体堆。cap 每 key waiter 100,
                //   超限直接 fast-fail (不挂不重发), 与 pendingCap 同语义防 OOM。
                if params.isEmpty && self.isCoalesceableRead(method) {
                    self.lock.lock()
                    if self.inflightReads[method] != nil {
                        if self.inflightReads[method]!.count >= self.inflightWaiterCap {
                            self.lock.unlock()
                            ipcLog.warning("IPC inflight waiter cap exceeded (\(self.inflightWaiterCap)) method=\(method, privacy: .public), fast-fail")
                            continuation.resume(throwing: IPCError.pendingFull)
                            return
                        }
                        self.inflightReads[method, default: []].append(continuation)
                        self.lock.unlock()
                        ipcLog.debug("IPC inflight coalesce: skip re-fire method=\(method, privacy: .public) id=\(reqId), awaiting in-flight")
                        return
                    }
                    self.inflightReads[method] = []
                    self.reqIdToMethod[reqId] = method
                    self.lock.unlock()
                }


                guard self.socketFd >= 0 else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                // 注册续体
                self.lock.lock()
                // 审计0827 P0-2: 接近上限 (≥80%) 即预警, 早于硬拒暴露拥塞趋势, 便定位瓶颈 method。
                if self.pendingRequests.count >= self.pendingCap * 4 / 5 {
                    ipcLog.warning("IPC pending near cap: \(self.pendingRequests.count)/\(self.pendingCap) method=\(method, privacy: .public)")
                }
                // F-A4: pending 容量上限, daemon 慢响应/断连 + 狂切 Tab 堆续体致 OOM。超限直接 reject。
                if self.pendingRequests.count >= self.pendingCap {
                    self.lock.unlock()
                    ipcLog.error("IPC pending cap exceeded (\(self.pendingCap, privacy: .public)), reject method=\(method, privacy: .public) id=\(reqId)")
                    continuation.resume(throwing: IPCError.pendingFull)
                    return
                }
                self.pendingRequests[reqId] = continuation
                self.lock.unlock()

                // 超时保护：避免 daemon 不回包时续体泄露、调用永久挂起 (bug3/bug4)。
                // 审计0830 P2-IPC-1: 旧统一 8s, 但 graph.execute/task.execute/mlx.start/design.export
                //   可达 120s+ (模型加载/长推理/导出) → 长任务被误杀超时计入熔断 (P0-3 熔断器雪崩)。
                //   分级: 长 RPC 120s, 默认 8s。复用 RPCMethod 常量匹配, 避免裸字符串漂移。
                let timeoutSecs = Self.rpcTimeout(for: method)
                self.queue.asyncAfter(deadline: .now() + timeoutSecs) { [weak self] in
                    guard let self = self else { return }
                    self.lock.lock()
                    let pending = self.pendingRequests.removeValue(forKey: reqId)
                    self.lock.unlock()
                    if let pending = pending {
                        ipcLog.warning("IPC call timeout: method=\(method, privacy: .public) id=\(reqId)")
                        pending.resume(throwing: IPCError.timeout)
                    }
                    // F-R4: 合并读超时也 fan-out 给挂起的在途 waiters
                    self.resumeInflightReads(method, result: .failure(IPCError.timeout))
                    // 审计0827 §2.6 (P1): 超时 = 后端慢/挂, 计入熔断失败; 达阈值开路防 pending 雪崩。
                    self.circuitOnFailure()
                }

                // 发送数据 (A1: writeBuf 已在 queue 外预序列化, queue 内仅写)
                Self.writeAll(fd: self.socketFd, writeBuf)
            }
        }
    }

    // MARK: - 通用 UDS 调用 (非主 socket 上游: project-svc / cowork desk_rpc)

    // Callers: projectCall / spaceCall. Affected API: udsCall(socketPath:method:params:) -> [String:Any].
    // 每次新建短连接, 换行分隔 JSON-RPC 2.0; 结果归一化: dict 原样 / array 包成 ["items":...] / 标量包成 ["_result":...]
    @discardableResult
    func udsCall(socketPath: String, method: String, params: [String: Any] = [:], timeoutSecs: Int = 8) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_UNIX, SOCK_STREAM, 0)
                guard sock >= 0 else {
                    continuation.resume(throwing: IPCError.invalidRequest)
                    return
                }
                defer { close(sock) }
                // 审计0827 P0-1: 短连接通道 (project-svc/cowork/guard/event 短连) 连前校验 sock 权限,
                // 与主 socket performConnect 复用同一守卫, 堵 0666 冒充守护绕过门禁。
                if let permErr = self.validateSocketPermission(socketPath) {
                    ipcLog.error("udsCall perm reject: path=\(socketPath, privacy: .public) method=\(method, privacy: .public) reason=\(permErr, privacy: .public)")
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }
                var tv = timeval(tv_sec: timeoutSecs, tv_usec: 0)
                _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                // 审计0902 R4 (P1): SO_SNDTIMEO 防写端永久阻塞 (对端慢消费/窗口满)。旧仅设 RCFTIMEO,
                //   writeAll 阻塞写可挂死整个短连通道。与 RCFTIMEO 对称设发送超时。
                _ = setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
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
                Self.writeAll(fd: sock, writeBuf)
                var respData = Data()
                var buf = [UInt8](repeating: 0, count: 8192)
                while true {
                    let n = buf.withUnsafeMutableBufferPointer { Darwin.read(sock, $0.baseAddress!, $0.count) }
                    if n > 0 {
                        respData.append(contentsOf: buf[0..<n])
                        if respData.last == 0x0A { break }
                    } else if n == 0 {
                        break // EOF: 对端关闭
                    } else {
                        // 审计0902 R4 (P1): n<0 分类 errno。SO_RCVTIMEO 超时返 EAGAIN/EWOULDBLOCK,
                        //   旧代码统一 break → 残缺/空 respData → invalidResponse (语义错, 实为超时)。
                        //   EINTR → 信号打断重试; EAGAIN/EWOULDBLOCK → 读超时 (已收部分或全未收), 报断连非非法响应;
                        //   其他 errno → 真故障, break 走 invalidResponse 兜底。
                        let rerr = errno
                        if rerr == EINTR { continue }
                        if rerr == EAGAIN || rerr == EWOULDBLOCK {
                            ipcLog.warning("udsCall read timeout method=\(method, privacy: .public) path=\(socketPath, privacy: .public) got=\(respData.count)B")
                            continuation.resume(throwing: IPCError.disconnected)
                            return
                        }
                        ipcLog.warning("udsCall read error method=\(method, privacy: .public) errno=\(rerr)")
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
                    // 审计0827 §3.8 (P2): Thread.sleep(0.01) busy-poll 钉死 GCD worker thread 空转,
                    // daemon 慢响应时多 Bridge 并发耗尽线程池。改 poll() 让线程在内核阻塞等可读,
                    // 不占 CPU; 1s 超时给 socketFd>=0 检查点 (shutdown 响应), 空闲时 1 syscall/s vs 旧 100/s。
                    var pfd = pollfd(fd: self.socketFd, events: Int16(POLLIN), revents: 0)
                    _ = withUnsafeMutablePointer(to: &pfd) { ptr in
                        Darwin.poll(ptr, 1, 1000)
                    }
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
        let coalescedMethod = reqIdToMethod.removeValue(forKey: id)
        lock.unlock()
        guard let cont = cont else {
            ipcLog.warning("handleResponse no pending continuation for id=\(id)")
            return
        }

        // F-R5: 旧 `as? [String: Any] ?? [:]` 静默吞非 dict result (array/scalar 降级空 dict)。
        // array 包 items, scalar 包 _result, dict 原样, 其他记日志再降级。
        let outcome: Result<[String: Any], Error>
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "未知错误"
            outcome = .failure(IPCError.rpcError(code: code, message: msg))
        } else if let result = json["result"] {
            if let dict = result as? [String: Any] {
                outcome = .success(dict)
            } else if let arr = result as? [Any] {
                outcome = .success(["items": arr])
            } else {
                ipcLog.warning("handleResponse result non-dict/array id=\(id), wrapping _result")
                outcome = .success(["_result": result])
            }
        } else {
            ipcLog.warning("handleResponse no result field id=\(id), returning empty")
            outcome = .success([:])
        }
        switch outcome {
        case .success(let v):
            cont.resume(returning: v)
            // 审计0827 §2.6 (P1): 成功复位熔断 (含 half-open 探测成功 → closed)。
            self.circuitOnSuccess()
        case .failure(let e):
            cont.resume(throwing: e)
            // 审计0830 P0-3: rpcError = 后端业务错 (4xx 鉴权/参数/404), 非后端不可达故障。
            //   旧逻辑把业务 4xx 计入熔断失败 → 连续 5 次鉴权失败误开路, 屏蔽全部 RPC 包括健康检查。
            //   修复: 仅传输层/解码故障 (timeout/disconnected/invalidResponse) 计入熔断, rpcError 透传不计。
            if let ipcErr = e as? IPCError, case .rpcError = ipcErr {
                ipcLog.info("handleResponse rpcError (business) id=\(id) — 不计入熔断 (P0-3)")
            } else {
                self.circuitOnFailure()
            }
        }
        // F-R4: 合并读 (coalescedMethod 非 nil) → fan-out 同 method 在途 waiters
        if let method = coalescedMethod {
            resumeInflightReads(method, result: outcome)
        }
    }

    /// 断连时排空所有挂起请求，resume 为 .disconnected，避免续体泄露 (bug3/bug4)
    private func drainPending() {
        lock.lock()
        let pending = pendingRequests
        pendingRequests.removeAll()
        // F-R4: 同步排空合并读的挂起 waiters
        let coalesced = inflightReads
        inflightReads.removeAll()
        reqIdToMethod.removeAll()
        lock.unlock()
        guard !pending.isEmpty || !coalesced.isEmpty else { return }
        ipcLog.warning("IPC drain \(pending.count, privacy: .public) pending + \(coalesced.count, privacy: .public) coalesced reads on disconnect")
        for (_, cont) in pending {
            cont.resume(throwing: IPCError.disconnected)
        }
        for (_, waiters) in coalesced {
            for w in waiters {
                w.resume(throwing: IPCError.disconnected)
            }
        }
        // 审计0827 §2.6 (P1): 断连 = 后端不可达, 计入熔断失败; drain 可能排空多个 pending 但只计一次失败
        // (一次断连事件一个失败信号, 非 N 个 pending = N 次失败, 否则单次断连即撞阈值开路)。
        self.circuitOnFailure()
    }

    // MARK: - 便捷方法

    // 审计0830 P2-IPC-1: RPC 超时分级。默认 8s; 长 RPC (graph.execute/agent.execute/mlx.start/stop)
    //   可达 120s+ (模型加载/长推理/导出), 统一 8s 误杀长任务 → 超时计入熔断 (P0-3) 雪崩。
    //   复用 RPCMethod 常量匹配, 避免裸字符串漂移。
    private static let defaultRpcTimeout: Double = 8
    private static let longRpcTimeout: Double = 120
    private static let longRpcMethods: Set<String> = [
        RPCMethod.graphExecute, RPCMethod.agentExecute, RPCMethod.agentExecuteStream,
        RPCMethod.mlxStart, RPCMethod.mlxStop, RPCMethod.agentSubmitCodeTask,
    ]
    private static func rpcTimeout(for method: String) -> Double {
        longRpcMethods.contains(method) ? longRpcTimeout : defaultRpcTimeout
    }

    // 审计0830 P0-8 + 审计0902 R4 (P1): Darwin.write 非阻塞 fd 可短写 (内核缓冲满返 < count),
    //   旧代码忽略返回值 → RPC payload 静默截断 → 后端收残缺 JSON 解析失败 → 客户端超时计入熔断级联。
    //   循环写直到全量写出。written<=0 分类 errno:
    //     EAGAIN/EWOULDBLOCK → poll(POLLOUT) 等缓冲可写后重试 (复用主 socket 读循环 EAGAIN 范式);
    //     EINTR → 信号打断, 直接重试;
    //     其他 → 真故障 (fd 断/对端关), 记日志后放弃。SO_SNDTIMEO (udsCall 设) 兜底防永久阻塞。
    private static func writeAll(fd: Int32, _ data: Data) {
        var remaining = data.count
        var offset = 0
        while remaining > 0 {
            let written = data.withUnsafeBytes { ptr -> Int in
                guard let base = ptr.baseAddress else { return -1 }
                return Darwin.write(fd, base.advanced(by: offset), remaining)
            }
            if written > 0 {
                offset += written
                remaining -= written
                continue
            }
            // written <= 0: 分类 errno
            let err = errno
            if err == EAGAIN || err == EWOULDBLOCK {
                var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                let pr = withUnsafeMutablePointer(to: &pfd) { ptr in Darwin.poll(ptr, 1, 5000) }
                if pr > 0 { continue } // 缓冲可写, 重试 write
                ipcLog.error("writeAll: poll POLLOUT fd=\(fd) ret=\(pr) errno=\(err) (R4 超时/故障, 放弃)")
                return
            }
            if err == EINTR { continue } // 信号打断, 重试
            ipcLog.error("writeAll: fault write fd=\(fd) offset=\(offset) remaining=\(remaining) ret=\(written) errno=\(err) (P0-8/R4 真故障, 放弃)")
            return
        }
    }

    func healthCheck() async throws -> [String: Any] {
        return try await call(method: RPCMethod.envHealthCheck)
    }

    func repair(itemId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.envRepair, params: ["item_id": itemId])
    }

    func repairAll() async throws -> [String: Any] {
        return try await call(method: RPCMethod.envRepairAll)
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        return try await call(method: RPCMethod.mlxStart, params: ["model": model])
    }

    func stopMLX() async throws -> [String: Any] {
        return try await call(method: RPCMethod.mlxStop)
    }

    func mlxStatus() async throws -> [String: Any] {
        return try await call(method: RPCMethod.mlxStatus)
    }

    func hardwareMetrics() async throws -> [String: Any] {
        return try await call(method: RPCMethod.hardwareMetrics)
    }

    func submitTask(type: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p = params
        p["type"] = type
        return try await call(method: RPCMethod.taskSubmit, params: p)
    }

    func ping() async throws -> Bool {
        let result = try await call(method: RPCMethod.ping)
        return result["pong"] as? Bool ?? false
    }

    // F-A16: 调 rpc.discover 缓存上游 method 集 + 关键方法存在性检查。
    // 失败/旧上游无此方法 → schemaCompatible=nil (乐观降级, 不阻断连接), 仅 warning 日志。
    // 成功: 缺关键方法 → schemaCompatible=false + error 日志列缺失方法 (schema 漂移预警)。
    private func discoverSchema() async {
        do {
            let result = try await call(method: RPCMethod.rpcDiscover)
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
