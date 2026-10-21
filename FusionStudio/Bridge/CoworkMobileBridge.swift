import Foundation
import os.log

// #418 Mobile Cowork panel: fusion-cowork web API (/api/mobile/overview,
// /api/permissions/pending, /api/runs/{id}/{pause,resume,directive,artifacts}).
// Static key auth mirrors gateway injection: Bearer + x-api-key from
// FUSION_COWORK_WEB_API_KEY; empty key means the upstream runs unauthenticated.
private let coworkMobileLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Mobile")

enum CoworkMobileError: LocalizedError {
    case badURL
    case http(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid fusion-cowork web URL"
        case .http(let status, let message): return "HTTP \(status): \(message)"
        case .invalidResponse: return "Invalid fusion-cowork web response"
        }
    }
}

struct CoworkMobileBridge {
    let host: String
    let port: Int
    let apiKey: String
    private let session: URLSession

    init(host: String = FusionConfig.shared.coworkHost,
         port: Int = FusionConfig.shared.coworkWebPort,
         apiKey: String = ProcessInfo.processInfo.environment["FUSION_COWORK_WEB_API_KEY"] ?? "") {
        self.host = host
        self.port = port
        self.apiKey = apiKey
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func overview() async throws -> CoworkMobileOverview {
        let result = try await request(method: "GET", path: "/api/mobile/overview")
        return CoworkMobileOverview.from(result)
    }

    func confirm(actionId: String, approved: Bool, scope: String = "*") async throws -> [String: Any] {
        let body: [String: Any] = ["approved": approved, "scope": scope]
        return try await request(
            method: "POST",
            path: "/api/permissions/pending/\(escaped(actionId))/confirm",
            body: body
        )
    }

    func pause(runId: String) async throws -> [String: Any] {
        return try await request(method: "POST", path: "/api/runs/\(escaped(runId))/pause", body: [:])
    }

    func resume(runId: String) async throws -> [String: Any] {
        return try await request(method: "POST", path: "/api/runs/\(escaped(runId))/resume", body: [:])
    }

    func directive(runId: String, body: [String: Any]) async throws -> [String: Any] {
        return try await request(method: "POST", path: "/api/runs/\(escaped(runId))/directive", body: body)
    }

    func artifacts(runId: String) async throws -> [[String: Any]] {
        let result = try await request(method: "GET", path: "/api/runs/\(escaped(runId))/artifacts")
        return result["artifacts"] as? [[String: Any]] ?? []
    }

    private func escaped(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    }

    private func request(method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var components = URLComponents()
        components.scheme = FusionConfig.shared.schemeForHost(host)
        components.host = host
        components.port = port
        components.path = path
        guard let url = components.url else {
            coworkMobileLog.error("bad URL host=\(self.host, privacy: .public):\(self.port) path=\(path, privacy: .public)")
            throw CoworkMobileError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        coworkMobileLog.info("\(method, privacy: .public) \(path, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = Self.errorMessage(from: data)
            coworkMobileLog.error("HTTP \(status) path=\(path, privacy: .public) msg=\(message, privacy: .public)")
            throw CoworkMobileError.http(status: status, message: message)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoworkMobileError.invalidResponse
        }
        return object
    }

    private static func errorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "unknown error"
        }
        if let detail = object["detail"] as? [String: Any] {
            if let message = detail["message"] as? String { return message }
            if let code = detail["code"] as? String { return code }
        }
        if let detail = object["detail"] as? String { return detail }
        return object["message"] as? String ?? "unknown error"
    }
}

struct CoworkMobileOverview {
    let runs: [[String: Any]]
    let pendingApprovals: [[String: Any]]
    let generatedAt: Double

    static func from(_ object: [String: Any]) -> CoworkMobileOverview {
        CoworkMobileOverview(
            runs: object["runs"] as? [[String: Any]] ?? [],
            pendingApprovals: object["pending_approvals"] as? [[String: Any]] ?? [],
            generatedAt: object["generated_at"] as? Double ?? 0
        )
    }
}
