// Callers: SecurityView + 子视图 (@StateObject SecurityBridge.shared), FusionStudioApp 注入可选。
// Affected API: SecurityBridge - HTTP client to fusion-security FastAPI (:11454 /api/v1/*)。
// Data schemas: SecSystemInfoDTO, SecProjectDTO, SecScanDTO, SecVulnDTO, SecPatchDTO, SecDashboardDTO, SecGateResultDTO, SecCvssDTO, SecRuleDTO。
// User instruction: "深度洞察claude security，结合fusion-security的能力，进行集成，要求fusion-security竞争力比claude security能力强，在fusion-studio增加security菜单"

import Foundation
import Combine
import os.log

private let secBridgeLog = Logger(subsystem: "com.fusion.studio", category: "SecurityBridge")

// MARK: - SecurityBridge

class SecurityBridge: ObservableObject {
    static let shared = SecurityBridge()

    @Published var isConnected: Bool = false
    @Published var lastError: String?

    @Published var systemInfo: SecSystemInfoDTO?
    @Published var projects: [SecProjectDTO] = []
    @Published var scans: [SecScanDTO] = []
    @Published var vulnerabilities: [SecVulnDTO] = []
    @Published var patches: [SecPatchDTO] = []
    @Published var dashboard: SecDashboardDTO?
    @Published var vulnStats: SecVulnStatsDTO?
    @Published var rules: [SecRuleDTO] = []
    @Published var customRules: [SecCustomRuleDTO] = []
    @Published var isScanning: Bool = false
    @Published var isLoading: Bool = false

    private let session: URLSession
    private var baseURL: String {
        "http://127.0.0.1:\(FusionConfig.shared.securityPort)"
    }

    // 审计0902 R5 (P2): 无重连定时器 (仅 checkHealth 翻状态, 无自动重试), fusion-security 宕 = 永久
    //   isConnected=false 无自愈。对齐 IPCClient/SimulationBridge 退避: base 2s × 2^min(attempt,5)
    //   封顶 60s + jitter, 成功复位 attempt=0。
    private var reconnectTimer: Timer?
    private var reconnectAttempt: Int = 0

    // #373: 规则 CRUD 委托 fusion-guard UDS (guard 为规则匹配 SSOT), SAST 仍走 HTTP :11454。
    // 注入点: FusionStudioApp 注入与 guardBridge.shared 同一实例。缺席则 fail-open 空 (规则管理非主门控)。
    weak var guardBridge: GuardBridge?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    deinit {
        reconnectTimer?.invalidate()
    }

    // 审计0902 R5 (P2): 指数退避 + jitter。base 2s × 2^min(attempt,5) 封顶 60s, jitter (attempt×137)%1000ms;
    //   单次 fire (非 repeats) 每次重算 interval, 成功复位 attempt=0。
    private func scheduleReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer?.invalidate()
            let attempt = self.reconnectAttempt
            let base = 2.0 * pow(2.0, Double(min(attempt, 5)))
            let interval = min(base, 60.0) + Double((attempt * 137) % 1000) / 1000.0
            self.reconnectAttempt += 1
            secBridgeLog.warning("SecurityBridge reconnect backoff: attempt=\(attempt) interval=\(String(format: "%.2f", interval))s")
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.checkHealth()
            }
        }
    }

    // MARK: - Health

    func checkHealth(completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/system/health") else {
            completion?(false); return
        }
        session.dataTask(with: url) { [weak self] data, response, error in
            let ok = error == nil
                && (response as? HTTPURLResponse)?.statusCode == 200
                && data != nil
            DispatchQueue.main.async {
                self?.isConnected = ok
                if ok {
                    self?.reconnectTimer?.invalidate()
                    self?.reconnectTimer = nil
                    self?.reconnectAttempt = 0
                } else {
                    secBridgeLog.error("SecurityBridge health failed: \(error?.localizedDescription ?? "no response")")
                    self?.scheduleReconnect()
                }
                completion?(ok)
            }
        }.resume()
    }

    // MARK: - System

    func fetchSystemInfo() {
        get("/api/v1/system/info") { [weak self] (result: Result<SecSystemInfoDTO, Error>) in
            switch result {
            case .success(let dto):
                DispatchQueue.main.async { self?.systemInfo = dto }
            case .failure(let error):
                self?.handleError(error, context: "system/info")
            }
        }
    }

    func fetchRules() {
        get("/api/v1/system/rules") { [weak self] (result: Result<SecRulesResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.rules = resp.rules }
            case .failure(let error):
                self?.handleError(error, context: "system/rules")
            }
        }
    }

    // MARK: - Projects

    func fetchProjects() {
        get("/api/v1/projects") { [weak self] (result: Result<[SecProjectDTO], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.projects = list }
            case .failure(let error):
                self?.handleError(error, context: "projects")
            }
        }
    }

    func createProject(name: String, localPath: String, techStack: String, completion: ((Result<SecProjectDTO, Error>) -> Void)? = nil) {
        let body: [String: Any] = [
            "name": name,
            "local_path": localPath,
            "tech_stack": techStack,
            "default_branch": "main",
        ]
        postJSON("/api/v1/projects", body: body, completion: completion)
    }

    func deleteProject(id: String, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/projects/\(id)") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion?(.failure(error)); return
            }
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion?(.success(ok == 200 || ok == 204))
        }.resume()
    }

    // MARK: - Scans

    func fetchScans() {
        get("/api/v1/scans") { [weak self] (result: Result<[SecScanDTO], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.scans = list }
            case .failure(let error):
                self?.handleError(error, context: "scans")
            }
        }
    }

    func createScan(projectId: String, path: String, useAi: Bool, completion: ((Result<SecScanDTO, Error>) -> Void)? = nil) {
        DispatchQueue.main.async { self.isScanning = true }
        let body: [String: Any] = [
            "project_id": projectId,
            "path": path,
            "scan_type": "full",
            "use_ai": useAi,
            "trigger": "manual",
            "severity_threshold": "low",
        ]
        postJSON("/api/v1/scans", body: body) { [weak self] (result: Result<SecScanDTO, Error>) in
            DispatchQueue.main.async { self?.isScanning = false }
            switch result {
            case .success(let scan):
                DispatchQueue.main.async {
                    self?.scans.insert(scan, at: 0)
                }
                // 后台扫描完成后刷新
                DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
                    self?.fetchScans()
                    self?.fetchVulnerabilities()
                    self?.fetchDashboard()
                }
                completion?(.success(scan))
            case .failure(let error):
                self?.handleError(error, context: "scans/create")
                completion?(.failure(error))
            }
        }
    }

    // MARK: - Vulnerabilities

    func fetchVulnerabilities() {
        get("/api/v1/vulnerabilities?limit=200") { [weak self] (result: Result<[SecVulnDTO], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.vulnerabilities = list }
            case .failure(let error):
                self?.handleError(error, context: "vulnerabilities")
            }
        }
    }

    func fetchVulnStats() {
        get("/api/v1/vulnerabilities/stats/summary") { [weak self] (result: Result<SecVulnStatsDTO, Error>) in
            switch result {
            case .success(let stats):
                DispatchQueue.main.async { self?.vulnStats = stats }
            case .failure(let error):
                self?.handleError(error, context: "vuln/stats")
            }
        }
    }

    func updateVulnStatus(id: String, status: String, completion: ((Result<SecVulnDTO, Error>) -> Void)? = nil) {
        let body: [String: Any] = ["status": status]
        guard let url = URL(string: "\(baseURL)/api/v1/vulnerabilities/\(id)/status") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let dto = try JSONDecoder.sec.decode(SecVulnDTO.self, from: data)
                completion?(.success(dto))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    func markFalsePositive(id: String, reason: String, completion: ((Result<SecVulnDTO, Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/vulnerabilities/\(id)/false-positive?reason=\(percentEncode(reason))") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let dto = try JSONDecoder.sec.decode(SecVulnDTO.self, from: data)
                completion?(.success(dto))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    // MARK: - Patches (AI 修复)

    func fetchPatches() {
        get("/api/v1/patches") { [weak self] (result: Result<[SecPatchDTO], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.patches = list }
            case .failure(let error):
                self?.handleError(error, context: "patches")
            }
        }
    }

    func generatePatch(vulnId: String, completion: ((Result<[SecPatchRefDTO], Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/patches/generate/\(vulnId)") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        DispatchQueue.main.async { self.isLoading = true }
        session.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async { self?.isLoading = false }
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let resp = try JSONDecoder.sec.decode(SecPatchGenerateResponseDTO.self, from: data)
                completion?(.success(resp.patches))
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self?.fetchPatches()
                }
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    func applyPatch(id: String, completion: ((Result<SecPatchDTO, Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/patches/\(id)/apply") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let dto = try JSONDecoder.sec.decode(SecPatchDTO.self, from: data)
                completion?(.success(dto))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    func verifyPatch(id: String, completion: ((Result<SecPatchDTO, Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/patches/\(id)/verify") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let dto = try JSONDecoder.sec.decode(SecPatchDTO.self, from: data)
                completion?(.success(dto))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    // MARK: - Dashboard & Integrations (质量门禁)

    func fetchDashboard() {
        get("/api/v1/integrations/dashboard") { [weak self] (result: Result<SecDashboardDTO, Error>) in
            switch result {
            case .success(let dto):
                DispatchQueue.main.async { self?.dashboard = dto }
            case .failure(let error):
                self?.handleError(error, context: "dashboard")
            }
        }
    }

    func evaluateGate(vulnerabilities: [[String: Any]], completion: ((Result<SecGateResultDTO, Error>) -> Void)? = nil) {
        guard let url = URL(string: "\(baseURL)/api/v1/integrations/gate") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: vulnerabilities)
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion?(.failure(error)); return }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let dto = try JSONDecoder.sec.decode(SecGateResultDTO.self, from: data)
                completion?(.success(dto))
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }

    // #373: 规则 CRUD 迁移至 guard UDS。guard.rule.list → GuardRule[] → SecCustomRuleDTO[]。
    // guard 无 severity, 用 risk_level 反向映射; SecCustomRuleDTO.id ← GuardRule.name (guard 按 name 寻址)。
    // 守卫缺席/失败 fail-open 返回空 (规则管理非主门控, SAST 主门控仍走 HTTP 不受影响)。
    func fetchCustomRules() {
        guard let guardBridge = guardBridge else {
            secBridgeLog.warning("fetchCustomRules: guardBridge nil, fail-open empty customRules")
            DispatchQueue.main.async { self.customRules = [] }
            return
        }
        Task { @MainActor in
            let (rules, _) = await guardBridge.listRules()
            let mapped = rules.map { r in
                SecCustomRuleDTO(
                    id: r.name,
                    name: r.reason.isEmpty ? r.name : r.reason,
                    pattern: r.pattern,
                    severity: GuardBridge.riskLevelToSeverity(r.risk_level),
                    language: nil,
                    enabled: true
                )
            }
            self.customRules = mapped
            secBridgeLog.info("fetchCustomRules via guard.rule.list: \(mapped.count) rules")
        }
    }

    // #373: guard.rule.add。映射 severity→risk_level, action=block, stage=regex, scope=command, reason←name。
    // completion 签名保留兼容 UI 调用方 (SecurityService L663), 成功回填构造 DTO。
    func createCustomRule(id: String, name: String, pattern: String, severity: String, completion: ((Result<SecCustomRuleDTO, Error>) -> Void)? = nil) {
        guard let guardBridge = guardBridge else {
            secBridgeLog.warning("createCustomRule: guardBridge nil, fail-open skip")
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        let rule = GuardBridge.GuardRuleCodable(
            name: id,
            pattern: pattern,
            stage: "regex",
            action: "block",
            risk_level: GuardBridge.severityToRiskLevel(severity),
            reason: name.isEmpty ? id : name,
            scope: "command"
        )
        Task { @MainActor in
            let ok = await guardBridge.addRule(rule)
            if ok {
                let dto = SecCustomRuleDTO(
                    id: id, name: name, pattern: pattern, severity: severity, language: nil, enabled: true
                )
                completion?(.success(dto))
            } else {
                completion?(.failure(SecurityBridgeError.noData))
            }
        }
    }

    // #373: guard.rule.remove。guard 按 name 寻址 = SecCustomRuleDTO.id。
    func deleteCustomRule(id: String, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard let guardBridge = guardBridge else {
            secBridgeLog.warning("deleteCustomRule: guardBridge nil, fail-open skip")
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        Task { @MainActor in
            let ok = await guardBridge.removeRule(name: id)
            completion?(.success(ok))
        }
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(SecurityBridgeError.invalidURL)); return
        }
        session.dataTask(with: url) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let code = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(code) {
                secBridgeLog.error("SecurityBridge HTTP \(code) (不解码响应体, 避免掩盖真实故障)")
                completion(.failure(SecurityBridgeError.httpError(code))); return
            }
            guard let data = data else { completion(.failure(SecurityBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder.sec.decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                secBridgeLog.error("Decode failed for \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], completion: ((Result<T, Error>) -> Void)?) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion?(.failure(SecurityBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion?(.failure(error)); return }
            if let code = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(code) {
                secBridgeLog.error("SecurityBridge POST HTTP \(code) (不解码响应体, 避免掩盖真实故障)")
                completion?(.failure(SecurityBridgeError.httpError(code))); return
            }
            guard let data = data else { completion?(.failure(SecurityBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder.sec.decode(T.self, from: data)
                completion?(.success(decoded))
            } catch {
                secBridgeLog.error("Decode failed for POST \(path): \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        secBridgeLog.error("SecurityBridge error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
        }
    }

    private func percentEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}

// MARK: - DTOs

extension JSONDecoder {
    static let sec: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

struct SecSystemInfoDTO: Decodable {
    var name: String?
    var version: String?
    var platform: String?
    var architecture: String?
    var pythonVersion: String?
}

struct SecProjectDTO: Identifiable, Decodable {
    var id: String
    var name: String
    var repoUrl: String?
    var techStack: String?
    var defaultBranch: String?
    var rulesetId: String?
    var localPath: String?
    var status: String?
}

struct SecScanDTO: Identifiable, Decodable {
    var id: String
    var projectId: String?
    var scanType: String?
    var status: String
    var severityThreshold: String?
    var useAi: Bool?
    var model: String?
    var trigger: String?
    var filesScanned: Int?
    var filesSkipped: Int?
    var durationMs: Double?
    var totalVulnerabilities: Int?
    var critical: Int?
    var high: Int?
    var medium: Int?
    var low: Int?
    var summary: String?
}

struct SecVulnDTO: Identifiable, Decodable {
    var id: String
    var title: String
    var description: String?
    var severity: String
    var confidence: Double?
    var filePath: String?
    var lineNumber: Int?
    var codeSnippet: String?
    var ruleId: String?
    var cweId: String?
    var fixSuggestion: String?
    var verified: Bool?
    var status: String?
    var dataFlowPath: String?
}

struct SecVulnStatsDTO: Decodable {
    var total: Int?
    var bySeverity: [String: Int]?
    var byStatus: [String: Int]?
}

struct SecPatchDTO: Identifiable, Decodable {
    var id: String
    var vulnId: String?
    var scanId: String?
    var diffContent: String?
    var originalCode: String?
    var patchedCode: String?
    var description: String?
    var status: String?
    var strategy: String?
    var verified: Bool?
}

struct SecPatchRefDTO: Decodable {
    var id: String
    var strategy: String?
}

struct SecPatchGenerateResponseDTO: Decodable {
    var patches: [SecPatchRefDTO]
}

struct SecDashboardDTO: Decodable {
    var totalScans: Int?
    var totalVulnerabilities: Int?
    var severityCounts: SecSeverityCountsDTO?
    var topRules: [SecTopRuleDTO]?
    var projectsCount: Int?
    var avgScanDurationMs: Double?
}

struct SecSeverityCountsDTO: Decodable {
    var critical: Int?
    var high: Int?
    var medium: Int?
    var low: Int?
}

struct SecTopRuleDTO: Decodable {
    var ruleId: String?
    var count: Int?
}

struct SecGateResultDTO: Decodable {
    var passed: Bool
    var policy: String?
    var totalVulnerabilities: Int?
    var severityCounts: SecSeverityCountsDTO?
    var blockedBy: [String]?
}

struct SecRulesResponseDTO: Decodable {
    var total: Int?
    var rules: [SecRuleDTO]
}

struct SecRuleDTO: Identifiable, Decodable {
    var id: String
    var name: String?
    var description: String?
    var severity: String?
    var cweId: String?
    var category: String?
    var language: String?
}

struct SecCustomRuleDTO: Identifiable, Decodable {
    var id: String
    var name: String?
    var pattern: String?
    var severity: String?
    var language: String?
    var enabled: Bool?
}

enum SecurityBridgeError: Error, LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效 URL"
        case .noData: return "无数据返回"
        case .httpError(let code):
            switch code {
            case 401: return "Unauthorized (401): fusion-security 鉴权失败"
            case 403: return "Forbidden (403): 无权限"
            case 404: return "Not Found (404): 端点或资源不存在"
            case 500...599: return "Server error (\(code)): fusion-security 服务端故障"
            default: return "HTTP \(code)"
            }
        }
    }
}
