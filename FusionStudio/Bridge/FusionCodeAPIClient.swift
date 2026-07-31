import Foundation
import os.log

// Fusion-Code 项目级 REST API 客户端
// Layer 2 集成：封装 /api/project/context, /api/sessions, /api/memory 等 HTTP 端点
// Callers: FusionCoderBridge (获取项目上下文), UI views (会话/记忆管理)
// Affected API: getProjectContext/listSessions/getSession/listMemories/writeMemory
// Data schemas: ProjectContext/SessionSummary/SessionDetail/MemoryFile/WriteResult

private let logger = Logger(subsystem: "com.fusion.studio", category: "FusionCodeAPIClient")

struct ProjectContext: Codable {
    let cwd: String
    let files: [ProjectFile]
    struct ProjectFile: Codable {
        let path: String
        let type: String
        let content: String?
    }
}

struct SessionSummary: Codable {
    let sessionId: String
    let summary: String?
    let firstPrompt: String?
    let lastModified: Double?
    let createdAt: Double?
    let gitBranch: String?
    let cwd: String?
    let fileSize: Int?

    var id: String { sessionId }
    var preview: String { firstPrompt ?? summary ?? "" }
}

struct SessionDetail: Codable {
    let sessionId: String
    let summary: String?
    let firstPrompt: String?
    let lastModified: Double?
    let createdAt: Double?
    let gitBranch: String?
    let cwd: String?
    let messages: [SessionMessage]?
    struct SessionMessage: Codable {
        let role: String?
        let content: String?
    }
}

struct MemoryFile: Codable {
    let path: String
    let content: String?
}

// Callers: UnifiedChatView project picker. Affected API: fetchProjects→GET /api/projects. Data: FusionCodeProject (id/name/path/created_at/updated_at).
struct FusionCodeProject: Codable, Identifiable {
    let id: String
    let name: String
    let path: String?
    let createdAt: Double?
    let updatedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, path
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WriteResult: Codable {
    let ok: Bool
    let path: String?
}

actor FusionCodeAPIClient {
    private let baseURL: URL
    private let authToken: String?

    init(baseURL: URL, authToken: String? = nil) {
        self.baseURL = baseURL
        self.authToken = authToken
        logger.info("FusionCodeAPIClient initialized: \(baseURL.absoluteString)")
    }

    private func makeRequest(path: String, query: [String: String] = [:]) -> URLRequest {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 5.0
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func fetchProjects() async throws -> [FusionCodeProject] {
        let req = makeRequest(path: "/api/projects")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            logger.error("fetchProjects failed: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct ProjectsResponse: Codable { let projects: [FusionCodeProject] }
        let result = try JSONDecoder().decode(ProjectsResponse.self, from: data)
        logger.info("fetchProjects: got \(result.projects.count) projects")
        return result.projects
    }

    func getProjectContext(cwd: String) async throws -> ProjectContext {
        let req = makeRequest(path: "/api/project/context", query: ["cwd": cwd])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            logger.error("getProjectContext failed: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(ProjectContext.self, from: data)
    }

    func listSessions(cwd: String) async throws -> [SessionSummary] {
        let req = makeRequest(path: "/api/sessions", query: ["cwd": cwd])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct SessionsResponse: Codable { let sessions: [SessionSummary] }
        let result = try JSONDecoder().decode(SessionsResponse.self, from: data)
        return result.sessions
    }

    func getSession(sessionId: String, cwd: String) async throws -> SessionDetail {
        let req = makeRequest(path: "/api/sessions/\(sessionId)", query: ["cwd": cwd])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(SessionDetail.self, from: data)
    }

    func listMemories(cwd: String) async throws -> [MemoryFile] {
        let req = makeRequest(path: "/api/memory", query: ["cwd": cwd])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct MemoriesResponse: Codable { let memories: [MemoryFile] }
        let result = try JSONDecoder().decode(MemoriesResponse.self, from: data)
        return result.memories
    }

    func writeMemory(filename: String, content: String, type: String, cwd: String) async throws -> WriteResult {
        var req = makeRequest(path: "/api/memory", query: ["cwd": cwd])
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["filename": filename, "content": content, "type": type]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw FusionCodeAPIError.httpError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(WriteResult.self, from: data)
    }
}

enum FusionCodeAPIError: LocalizedError {
    case httpError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Fusion-Code API HTTP \(code)"
        case .invalidResponse: return "Fusion-Code API invalid response"
        }
    }
}
