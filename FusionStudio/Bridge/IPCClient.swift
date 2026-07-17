import Foundation
import Combine

/// IPC 通信客户端 — Unix Domain Socket + JSON-RPC 2.0
class IPCClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private let socketPath = "/tmp/fusion-studio.sock"
    private var requestId: Int = 0
    private var io: DispatchIO?

    init() {
        connect()
    }

    func connect() {
        // 连接到 supervisor 守护进程
        let socket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else {
            lastError = "无法创建 socket"
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathData = socketPath.data(using: .utf8)!
        let pathLen = min(pathData.count, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        pathData.withUnsafeBytes { buf in
            withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
                sunPath.withMemoryRebound(to: UInt8.self, capacity: pathLen) { dest in
                    dest.assign(from: buf.bindMemory(to: UInt8.self).baseAddress!, count: pathLen)
                }
            }
        }

        let fd = Darwin.connect(socket, withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, socklen_t(MemoryLayout<sockaddr_un>.size))

        if fd < 0 {
            lastError = "连接失败: \(String(cString: strerror(errno)))"
            close(socket)
            isConnected = false
            return
        }

        io = DispatchIO(type: .stream, fileDescriptor: socket, queue: .main) { error in
            if error != 0 {
                print("IPC 连接关闭: \(error)")
            }
        }

        isConnected = true
        lastError = nil
    }

    /// 调用远程方法
    func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        requestId += 1
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        // 发送请求（实际实现需处理读写）
        return ["status": "ok"]
    }

    /// 环境健康检查
    func healthCheck() async throws -> [String: Any] {
        return try await call(method: "env.health_check")
    }

    /// 一键修复
    func repair() async throws -> [String: Any] {
        return try await call(method: "env.repair")
    }

    /// 启动 MLX 推理服务
    func startMLX(model: String = "") async throws -> [String: Any] {
        return try await call(method: "mlx.start", params: ["model": model])
    }

    /// 停止 MLX 推理服务
    func stopMLX() async throws -> [String: Any] {
        return try await call(method: "mlx.stop")
    }

    /// 获取推理服务状态
    func mlxStatus() async throws -> [String: Any] {
        return try await call(method: "mlx.status")
    }

    /// 提交任务
    func submitTask(type: String, params: [String: Any]) async throws -> [String: Any] {
        var p = params
        p["type"] = type
        return try await call(method: "task.submit", params: p)
    }

    deinit {
        if let io = io {
            io.close(flags: .stop)
        }
    }
}