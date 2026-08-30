import Foundation
import Combine
import os.log

private let pluginBridgeLog = Logger(subsystem: "com.fusion.studio", category: "PluginBridge")

enum PluginBridgeError: LocalizedError {
    case invalidURL
    case noData
    case rpcError(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效 URL"
        case .noData: return "无响应数据"
        case .rpcError(let msg): return "RPC 错误: \(msg)"
        case .notConnected: return "插件服务未连接"
        }
    }
}

class PluginBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var plugins: [PluginListItem] = []
    @Published var config: EcosystemConfig?
    @Published var pluginStates: [PluginStateInfo] = []
    @Published var tokenRecords: [TokenRecord] = []
    @Published var vramUsage: VRAMUsage?
    @Published var mcpSessions: [MCPSession] = []
    @Published var logEntries: [PluginLogEntry] = []

    static let shared = PluginBridge()

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? "http://\(FusionConfig.shared.coworkHost):\(FusionConfig.shared.coworkMcpPort)"
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Health

    func checkHealth() {
        rpc("plugins.ping", params: [:]) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                }
            case .failure(let error):
                self?.handleError(error, context: "health")
            }
        }
    }

    // MARK: - List Plugins (#78)

    func listPlugins(category: String? = nil, completion: @escaping (Result<[PluginListItem], Error>) -> Void = { _ in }) {
        var params: [String: Any] = [:]
        if let cat = category { params["category"] = cat }
        rpc("plugins/list", params: params) { [weak self] result in
            switch result {
            case .success(let resp):
                let items = (resp["plugins"] as? [[String: Any]] ?? []).compactMap { PluginListItem.fromDict($0) }
                DispatchQueue.main.async { self?.plugins = Array(items.suffix(200)) }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Install/Uninstall (#78)

    func installPlugin(pluginId: String, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        rpc("plugins/install", params: ["plugin_id": pluginId]) { result in
            switch result {
            case .success: completion(.success(true))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    func uninstallPlugin(pluginId: String, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        rpc("plugins/uninstall", params: ["plugin_id": pluginId]) { result in
            switch result {
            case .success: completion(.success(true))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    // MARK: - Config (#79)

    func getConfig(completion: @escaping (Result<EcosystemConfig, Error>) -> Void = { _ in }) {
        rpc("plugins/config.get", params: [:]) { [weak self] result in
            switch result {
            case .success(let resp):
                let c = EcosystemConfig.fromDict(resp)
                DispatchQueue.main.async { self?.config = c }
                completion(.success(c))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func setConfig(key: String, value: Any, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        rpc("plugins/config.set", params: [key: value]) { result in
            switch result {
            case .success: completion(.success(true))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    // MARK: - States (#80)

    func listStates(completion: @escaping (Result<[PluginStateInfo], Error>) -> Void = { _ in }) {
        rpc("plugins/states", params: [:]) { [weak self] result in
            switch result {
            case .success(let resp):
                let states = (resp["states"] as? [[String: Any]] ?? []).compactMap { PluginStateInfo.fromDict($0) }
                DispatchQueue.main.async { self?.pluginStates = Array(states.suffix(200)) }
                completion(.success(states))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getState(pluginId: String, completion: @escaping (Result<PluginStateInfo, Error>) -> Void = { _ in }) {
        rpc("plugins/state.get", params: ["plugin_id": pluginId]) { result in
            switch result {
            case .success(let resp):
                if let info = PluginStateInfo.fromDict(resp) {
                    completion(.success(info))
                } else {
                    completion(.failure(PluginBridgeError.rpcError("解析状态失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func listByState(state: String, completion: @escaping (Result<[PluginStateInfo], Error>) -> Void = { _ in }) {
        rpc("plugins/state.list", params: ["state": state]) { result in
            switch result {
            case .success(let resp):
                let items = (resp["plugins"] as? [[String: Any]] ?? []).compactMap { PluginStateInfo.fromDict($0) }
                completion(.success(items))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Token (#81)

    func tokenRecords(pluginId: String? = nil, completion: @escaping (Result<[TokenRecord], Error>) -> Void = { _ in }) {
        var params: [String: Any] = [:]
        if let pid = pluginId { params["plugin_id"] = pid }
        rpc("plugins/token.records", params: params) { [weak self] result in
            switch result {
            case .success(let resp):
                let records = (resp["records"] as? [[String: Any]] ?? []).compactMap { TokenRecord.fromDict($0) }
                DispatchQueue.main.async { self?.tokenRecords = Array(records.suffix(200)) }
                completion(.success(records))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func tokenPrune(maxAge: Int = 3600, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        rpc("plugins/token.prune", params: ["max_age_seconds": maxAge]) { result in
            switch result {
            case .success: completion(.success(true))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    // MARK: - VRAM (#82)

    func vramUsage(completion: @escaping (Result<VRAMUsage, Error>) -> Void = { _ in }) {
        rpc("plugins/vram.usage", params: [:]) { [weak self] result in
            switch result {
            case .success(let resp):
                let usage = VRAMUsage.fromDict(resp)
                DispatchQueue.main.async { self?.vramUsage = usage }
                completion(.success(usage))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Logs (#83)

    func fetchLogs(pluginId: String? = nil, level: String? = nil, completion: @escaping (Result<[PluginLogEntry], Error>) -> Void = { _ in }) {
        var params: [String: Any] = [:]
        if let pid = pluginId { params["plugin_id"] = pid }
        if let lv = level { params["level"] = lv }
        rpc("plugins/logs.stream", params: params) { [weak self] result in
            switch result {
            case .success(let resp):
                let entries = (resp["entries"] as? [[String: Any]] ?? []).compactMap { PluginLogEntry.fromDict($0) }
                DispatchQueue.main.async { self?.logEntries = Array(entries.suffix(500)) }
                completion(.success(entries))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - MCP (#84)

    func mcpSessions(completion: @escaping (Result<[MCPSession], Error>) -> Void = { _ in }) {
        rpc("plugins/mcp.sessions", params: [:]) { [weak self] result in
            switch result {
            case .success(let resp):
                let sessions = (resp["sessions"] as? [[String: Any]] ?? []).compactMap { MCPSession.fromDict($0) }
                DispatchQueue.main.async { self?.mcpSessions = Array(sessions.suffix(200)) }
                completion(.success(sessions))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func mcpPrune(maxAge: Int = 3600, completion: @escaping (Result<Bool, Error>) -> Void = { _ in }) {
        rpc("plugins/mcp.sessions.prune", params: ["max_age_seconds": maxAge]) { result in
            switch result {
            case .success: completion(.success(true))
            case .failure(let error): completion(.failure(error))
            }
        }
    }

    // MARK: - Generic JSON-RPC

    private func rpc(_ method: String, params: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/rpc") else {
            completion(.failure(PluginBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...99999),
            "method": method,
            "params": params
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        pluginBridgeLog.info("PluginBridge RPC: \(method)")
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(PluginBridgeError.noData)); return }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(PluginBridgeError.rpcError("非 JSON 对象"))); return
                }
                if let errorDict = json["error"] as? [String: Any],
                   let msg = errorDict["message"] as? String {
                    completion(.failure(PluginBridgeError.rpcError(msg))); return
                }
                guard let result = json["result"] as? [String: Any] else {
                    completion(.failure(PluginBridgeError.rpcError("无 result 字段"))); return
                }
                completion(.success(result))
            } catch {
                pluginBridgeLog.error("PluginBridge decode failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        pluginBridgeLog.error("PluginBridge error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
            if context == "health" { self?.isConnected = false }
        }
    }
}
