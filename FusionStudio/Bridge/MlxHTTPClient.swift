// MlxHTTPClient - fusion-mlx /admin/api/* HTTP 客户端。
// 复用自 fusion-mac Sources/Net/FusionClient.swift，适配 fusion-studio：
//   - baseURL/apiKey 来自 FusionConfig（mlxHost:mlxPort / mlxResolvedApiKey）
//   - cookie 会话 + 401 自动 /admin/api/login 重试
//   - convertTo/FromSnakeCase 编解码
// 引导（Onboarding/WelcomeView）通过此客户端下载模型、轮询进度、列出已加载模型。

import Foundation
import os.log

enum MlxHTTPError: Error, CustomStringConvertible {
    case invalidURL
    case invalidResponse
    case unauthenticated
    case http(status: Int, body: String?)

    var description: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .unauthenticated: return "Not authenticated (no API key configured)"
        case .http(let s, _): return "HTTP \(s)"
        }
    }
}

@MainActor
final class MlxHTTPClient: ObservableObject {
    private let config: FusionConfig
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let log = Logger(subsystem: "com.fusion.studio", category: "MlxHTTPClient")

    init(config: FusionConfig) {
        self.config = config

        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        cfg.timeoutIntervalForRequest = 15
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
    }

    private var host: String { config.mlxHost }
    private var port: Int { config.mlxPort }
    private var apiKey: String? {
        let k = config.mlxResolvedApiKey
        return k.isEmpty ? nil : k
    }

    // MARK: - 已加载模型池

    func listModels() async throws -> ListModelsResponse {
        try await get("/admin/api/models")
    }

    @discardableResult
    func reloadModels() async throws -> SimpleStatusResponse {
        try await postEmpty("/admin/api/reload")
    }

    // MARK: - HF 下载

    func listHFTasks() async throws -> HFTaskListResponse {
        try await get("/admin/api/hf/tasks")
    }

    func startHFDownload(repoId: String, hfToken: String = "") async throws -> StartHFDownloadResponse {
        try await post("/admin/api/hf/download", body: StartHFDownloadRequest(
            repoId: repoId, hfToken: hfToken
        ))
    }

    @discardableResult
    func cancelHFDownload(taskId: String) async throws -> SimpleStatusResponse {
        try await postEmpty("/admin/api/hf/cancel/\(taskId)")
    }

    @discardableResult
    func retryHFDownload(taskId: String) async throws -> StartHFDownloadResponse {
        try await postEmpty("/admin/api/hf/retry/\(taskId)")
    }

    @discardableResult
    func removeHFTask(taskId: String) async throws -> SimpleStatusResponse {
        try await delete("/admin/api/hf/task/\(taskId)")
    }

    func getHFRecommended(mlxOnly: Bool = true) async throws -> HFRecommendedResponse {
        try await get("/admin/api/hf/recommended", query: [
            URLQueryItem(name: "mlx_only", value: mlxOnly ? "true" : "false"),
        ])
    }

    func searchHFModels(
        query: String,
        sort: String = "trending",
        limit: Int = 20,
        mlxOnly: Bool = true
    ) async throws -> HFSearchResponse {
        try await get("/admin/api/hf/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "mlx_only", value: mlxOnly ? "true" : "false"),
        ])
    }

    // MARK: - API Key 设置

    @discardableResult
    func setupApiKey(_ key: String, confirm: String) async throws -> SimpleStatusResponse {
        try await post("/admin/api/setup-api-key", body: SetupApiKeyRequest(
            apiKey: key, apiKeyConfirm: confirm
        ))
    }

    // MARK: - 核心请求

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request("GET", path: path, query: query, body: nil)
    }

    private func post<U: Encodable, T: Decodable>(_ path: String, body: U) async throws -> T {
        let data = try encoder.encode(body)
        return try await request("POST", path: path, body: data)
    }

    private func postEmpty<T: Decodable>(_ path: String) async throws -> T {
        try await request("POST", path: path, body: nil)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request("DELETE", path: path, body: nil)
    }

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data?,
        isRetry: Bool = false
    ) async throws -> T {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            log.error("invalid url: \(path, privacy: .public)")
            throw MlxHTTPError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw MlxHTTPError.invalidResponse }

        if http.statusCode == 401, !isRetry {
            guard let key = apiKey, !key.isEmpty else {
                log.error("401 unauthenticated, no api key configured")
                throw MlxHTTPError.unauthenticated
            }
            log.info("401, retry login then resend \(method, privacy: .public) \(path, privacy: .public)")
            try await login(apiKey: key)
            return try await request(method, path: path, query: query, body: body, isRetry: true)
        }

        guard 200..<300 ~= http.statusCode else {
            let bodyStr = String(data: data, encoding: .utf8)
            log.error("\(method, privacy: .public) \(path, privacy: .public) -> HTTP \(http.statusCode, privacy: .public) \(bodyStr ?? "", privacy: .public)")
            throw MlxHTTPError.http(status: http.statusCode, body: bodyStr)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    // 审计0902 E2 (P2): login() 无重试预算, 瞬态 5xx (502/503/504) 或网络错直接抛 → 原 req 也失败。
    //   login 仅重试 1 次 (base 0.4s + jitter); 401/4xx 不重试 = 凭据错非瞬态。
    private func login(apiKey: String) async throws {
        struct LoginReq: Encodable { let apiKey: String; let remember: Bool }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/admin/api/login"
        guard let url = components.url else { throw MlxHTTPError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(LoginReq(apiKey: apiKey, remember: true))

        let maxAttempts = 2
        for attempt in 0..<maxAttempts {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw MlxHTTPError.invalidResponse }
                guard 200..<300 ~= http.statusCode else {
                    let bodyStr = String(data: data, encoding: .utf8)
                    let transient = http.statusCode == 502 || http.statusCode == 503 || http.statusCode == 504
                    if transient, attempt + 1 < maxAttempts {
                        let base = 0.4 * pow(2.0, Double(attempt))
                        let jitter = Double((attempt * 137) % 200) / 1000.0
                        let delay = base + jitter
                        log.warning("login transient \(http.statusCode), retry attempt=\(attempt) backoff=\(String(format: "%.3f", delay))s")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    log.error("login -> HTTP \(http.statusCode, privacy: .public) \(bodyStr ?? "", privacy: .public)")
                    throw MlxHTTPError.http(status: http.statusCode, body: bodyStr)
                }
                log.info("login ok")
                return
            } catch let urlErr as URLError {
                let transient = urlErr.code == .timedOut || urlErr.code == .networkConnectionLost
                    || urlErr.code == .cannotConnectToHost || urlErr.code == .notConnectedToInternet
                guard transient, attempt + 1 < maxAttempts else { throw urlErr }
                let base = 0.4 * pow(2.0, Double(attempt))
                let jitter = Double((attempt * 137) % 200) / 1000.0
                let delay = base + jitter
                log.warning("login network err \(urlErr.code.rawValue), retry attempt=\(attempt) backoff=\(String(format: "%.3f", delay))s")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw MlxHTTPError.http(status: -1, body: "login exhausted retries")
    }
}
