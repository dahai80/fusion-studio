import Foundation
import Combine
import os.log

private let healthBridgeLog = Logger(subsystem: "com.fusion.studio", category: "HealthBridge")

struct HealthServiceStatus: Codable {
    let status: String
    let service: String
    let version: String
    let model: String
}

struct HealthChatResponse: Codable {
    let session_id: String
    let response: String
    let error: String?
}

struct HealthChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

class HealthBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var serviceStatus: HealthServiceStatus?
    @Published var chatMessages: [HealthChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var ehrSummary: String?

    private var baseURL: String
    private let session: URLSession
    private var sessionId: String = ""

    init(baseURL: String = FusionConfig.shared.healthBaseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // 审计0827 §2.8 (P1): chatMessages 无界 append, 长问诊会话单调增长 OOM。cap 500 复用 PERF-3 范式。
    private static let maxChatMessages = 500
    private func capChatMessages() {
        if chatMessages.count > Self.maxChatMessages {
            let drop = chatMessages.count - Self.maxChatMessages
            chatMessages.removeFirst(drop)
            healthBridgeLog.info("capChatMessages: drop \(drop) oldest (count > \(Self.maxChatMessages))")
        }
    }

    func refreshBaseURL() {
        baseURL = FusionConfig.shared.healthBaseURL
    }

    private func apiKey() -> String {
        ProcessInfo.processInfo.environment["FUSION_HEALTH_API_KEY"] ?? ""
    }

    private func applyAuth(_ req: inout URLRequest) {
        let key = apiKey()
        if !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // MARK: - Health

    func checkHealth(completion: @escaping (Bool) -> Void = { _ in }) {
        healthBridgeLog.info("checkHealth: GET \(self.baseURL, privacy: .public)/api/v1/health")
        guard let url = URL(string: "\(baseURL)/api/v1/health") else {
            handleError(NSError(domain: "HealthBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]), context: "health")
            completion(false)
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyAuth(&req)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            if let error = error {
                self?.handleError(error, context: "health")
                completion(false)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self?.handleError(NSError(domain: "HealthBridge", code: -2, userInfo: nil), context: "health")
                completion(false)
                return
            }
            healthBridgeLog.info("checkHealth: HTTP \(http.statusCode)")
            let ok = (200..<300).contains(http.statusCode)
            DispatchQueue.main.async {
                self?.isConnected = ok
                if ok { self?.lastError = nil }
                if ok, let data = data {
                    self?.serviceStatus = try? JSONDecoder().decode(HealthServiceStatus.self, from: data)
                }
            }
            completion(ok)
        }
        task.resume()
    }

    // MARK: - Chat

    func startChat(systemPrompt: String = "你是 fusion-health 医疗助手，提供健康咨询与病历分析。") {
        healthBridgeLog.info("startChat: session")
        guard let url = URL(string: "\(baseURL)/api/v1/chat/start") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        let sid = sessionId.isEmpty ? "studio-\(UUID().uuidString.prefix(8))" : sessionId
        let body: [String: Any] = ["session_id": sid, "system_prompt": systemPrompt]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { [weak self] data, _, _ in
            if let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let returned = obj["session_id"] as? String {
                DispatchQueue.main.async { self?.sessionId = returned }
                healthBridgeLog.info("startChat: session_id=\(returned, privacy: .public)")
            }
        }
        task.resume()
    }

    func sendChat(_ message: String) {
        guard !message.isEmpty else { return }
        DispatchQueue.main.async {
            self.chatMessages.append(HealthChatMessage(role: "user", content: message))
            self.capChatMessages()
            self.isGenerating = true
        }
        guard let url = URL(string: "\(baseURL)/api/v1/chat/message") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        let body: [String: Any] = ["session_id": sessionId, "message": message]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        healthBridgeLog.info("sendChat: POST message session=\(self.sessionId, privacy: .public) len=\(message.count)")
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async { self?.isGenerating = false }
            if let error = error {
                self?.handleError(error, context: "chat")
                DispatchQueue.main.async {
                    self?.chatMessages.append(HealthChatMessage(role: "assistant", content: "请求失败: \(error.localizedDescription)"))
                    self?.capChatMessages()
                }
                return
            }
            guard let data = data, let resp = try? JSONDecoder().decode(HealthChatResponse.self, from: data) else {
                DispatchQueue.main.async {
                    self?.chatMessages.append(HealthChatMessage(role: "assistant", content: "解析回复失败"))
                    self?.capChatMessages()
                }
                return
            }
            let text = resp.error != nil ? "错误: \(resp.error!)" : resp.response
            DispatchQueue.main.async {
                self?.chatMessages.append(HealthChatMessage(role: "assistant", content: text))
                self?.capChatMessages()
            }
            healthBridgeLog.info("sendChat: response len=\(text.count)")
        }
        task.resume()
    }

    // MARK: - EHR Summary

    func generateEhrSummary(clinicalNotes: String, completion: @escaping (Result<String, Error>) -> Void = { _ in }) {
        healthBridgeLog.info("generateEhrSummary: notes len=\(clinicalNotes.count)")
        guard let url = URL(string: "\(baseURL)/api/v1/ehr/summary") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        let body: [String: Any] = ["clinical_notes": clinicalNotes]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            if let error = error {
                self?.handleError(error, context: "ehr-summary")
                completion(.failure(error))
                return
            }
            guard let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "HealthBridge", code: -3, userInfo: nil)))
                return
            }
            let summary = (obj["summary"] as? String) ?? (obj["error"] as? String) ?? "无摘要"
            DispatchQueue.main.async { self?.ehrSummary = summary }
            completion(.success(summary))
        }
        task.resume()
    }

    // MARK: - Vitals

    func extractVitals(text: String, completion: @escaping (Result<[String: String], Error>) -> Void = { _ in }) {
        healthBridgeLog.info("extractVitals: text len=\(text.count)")
        guard let url = URL(string: "\(baseURL)/api/v1/ehr/vitals") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(&req)
        let body: [String: Any] = ["text": text]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "HealthBridge", code: -4, userInfo: nil)))
                return
            }
            let vitals = (obj["vitals"] as? [String: String]) ?? [:]
            completion(.success(vitals))
        }
        task.resume()
    }

    private func handleError(_ error: Error, context: String) {
        healthBridgeLog.error("HealthBridge \(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        DispatchQueue.main.async {
            self.lastError = "\(context): \(error.localizedDescription)"
            self.isConnected = false
        }
    }
}
