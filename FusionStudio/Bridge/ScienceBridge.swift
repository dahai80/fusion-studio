import Foundation
import Combine
import os.log

private let bridgeLog = Logger(subsystem: "com.fusion.studio", category: "ScienceBridge")

class ScienceBridge: ObservableObject {
    @Published var sessions: [ScienceSession] = []
    @Published var currentSession: ScienceSession?
    @Published var messages: [ScienceMessage] = []
    @Published var papers: [SciencePaper] = []
    @Published var figures: [ScienceFigure] = []
    @Published var auditEntries: [ScienceAuditEntry] = []
    @Published var databases: [ScienceDatabase] = []
    @Published var isConnected: Bool = false
    @Published var lastError: String?

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "http://127.0.0.1:8200") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Health

    func checkHealth() {
        get("/api/v1/health") { [weak self] (result: Result<ScienceHealthResponse, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                }
            case .failure(let err):
                self?.handleError(err, context: "health")
            }
        }
    }

    // MARK: - Sessions

    func fetchSessions() {
        get("/api/v1/sessions") { [weak self] (result: Result<[ScienceSession], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.sessions = list }
            case .failure(let err):
                self?.handleError(err, context: "sessions")
            }
        }
    }

    func createSession(title: String, completion: @escaping (Result<ScienceSession, Error>) -> Void) {
        let body: [String: Any] = ["title": title]
        post("/api/v1/sessions", body: body) { [weak self] (result: Result<ScienceSession, Error>) in
            switch result {
            case .success(let session):
                DispatchQueue.main.async {
                    self?.sessions.insert(session, at: 0)
                    self?.currentSession = session
                    self?.messages = []
                    self?.papers = []
                    self?.figures = []
                    self?.auditEntries = []
                }
                completion(.success(session))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    func fetchSession(id: String) {
        get("/api/v1/sessions/\(id)") { [weak self] (result: Result<ScienceSession, Error>) in
            switch result {
            case .success(let session):
                DispatchQueue.main.async { self?.currentSession = session }
            case .failure(let err):
                self?.handleError(err, context: "session_detail")
            }
        }
    }

    func selectSession(_ session: ScienceSession) {
        currentSession = session
        messages = []
        papers = []
        figures = []
        auditEntries = []
        fetchSession(id: session.id)
    }

    // MARK: - Chat (non-streaming fallback)

    func sendChat(sessionId: String, message: String, completion: @escaping (Result<ScienceMessage, Error>) -> Void) {
        let body: [String: Any] = ["message": message]
        post("/api/v1/sessions/\(sessionId)/chat", body: body) { [weak self] (result: Result<ScienceMessage, Error>) in
            switch result {
            case .success(let msg):
                DispatchQueue.main.async { self?.messages.append(msg) }
                completion(.success(msg))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Search

    func searchPapers(sessionId: String, query: String, databases: [String]? = nil, completion: @escaping (Result<[SciencePaper], Error>) -> Void) {
        var body: [String: Any] = ["query": query]
        if let dbs = databases { body["databases"] = dbs }
        post("/api/v1/sessions/\(sessionId)/search", body: body) { [weak self] (result: Result<[SciencePaper], Error>) in
            switch result {
            case .success(let papers):
                DispatchQueue.main.async { self?.papers = papers }
                completion(.success(papers))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Analyze

    func analyzeData(sessionId: String, query: String, data: String? = nil, completion: @escaping (Result<[ScienceArtifact], Error>) -> Void) {
        var body: [String: Any] = ["query": query]
        if let d = data { body["data"] = d }
        post("/api/v1/sessions/\(sessionId)/analyze", body: body) { [weak self] (result: Result<[ScienceArtifact], Error>) in
            switch result {
            case .success(let artifacts):
                DispatchQueue.main.async {
                    var msgs = self?.messages ?? []
                    let msg = ScienceMessage(
                        id: UUID().uuidString,
                        sessionId: sessionId,
                        role: "assistant",
                        content: "Analysis complete",
                        createdAt: Date().timeIntervalSince1970,
                        artifacts: artifacts
                    )
                    msgs.append(msg)
                    self?.messages = msgs
                }
                completion(.success(artifacts))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Visualize

    func visualize(sessionId: String, query: String, completion: @escaping (Result<[ScienceFigure], Error>) -> Void) {
        let body: [String: Any] = ["query": query]
        post("/api/v1/sessions/\(sessionId)/visualize", body: body) { [weak self] (result: Result<[ScienceFigure], Error>) in
            switch result {
            case .success(let figures):
                DispatchQueue.main.async { self?.figures = figures }
                completion(.success(figures))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Review

    func review(sessionId: String, query: String, completion: @escaping (Result<String, Error>) -> Void) {
        let body: [String: Any] = ["query": query]
        postRaw("/api/v1/sessions/\(sessionId)/review", body: body) { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let review = json["review"] as? String {
                    completion(.success(review))
                } else if let text = String(data: data, encoding: .utf8) {
                    completion(.success(text))
                } else {
                    completion(.failure(ScienceBridgeError.noData))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Audit

    func fetchAudit(sessionId: String) {
        get("/api/v1/sessions/\(sessionId)/audit") { [weak self] (result: Result<[ScienceAuditEntry], Error>) in
            switch result {
            case .success(let entries):
                DispatchQueue.main.async { self?.auditEntries = entries }
            case .failure:
                bridgeLog.debug("Audit not available for session \(sessionId)")
            }
        }
    }

    // MARK: - Databases

    func fetchDatabases() {
        get("/api/v1/databases") { [weak self] (result: Result<[ScienceDatabase], Error>) in
            switch result {
            case .success(let dbs):
                DispatchQueue.main.async { self?.databases = dbs }
            case .failure:
                bridgeLog.debug("Databases endpoint not available")
            }
        }
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(ScienceBridgeError.invalidURL)); return
        }
        session.dataTask(with: url) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(ScienceBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                bridgeLog.error("Decode failed for \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(ScienceBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(ScienceBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                bridgeLog.error("Decode failed for POST \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func postRaw(_ path: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(ScienceBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(ScienceBridgeError.noData)); return }
            completion(.success(data))
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        bridgeLog.error("ScienceBridge error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
            if msg.contains("connect") || msg.contains("refused") {
                self?.isConnected = false
            }
        }
    }
}

enum ScienceBridgeError: Error, LocalizedError {
    case invalidURL
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data returned"
        }
    }
}
