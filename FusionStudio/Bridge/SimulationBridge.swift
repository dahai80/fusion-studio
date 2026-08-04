// Callers: FusionStudioApp (@StateObject injection), SimulationWorkbenchView (@EnvironmentObject).
// Affected API: SimulationBridge - HTTP client to fusion-sim FastAPI dashboard (:11455 /api/*).
// Data schemas: SimStatusDTO, SimStepResultDTO, SimActionResponseDTO, SimEnvCheckComponent.
// User instruction: "和~/fusion/fuison-simulation项目集成起来，包括GUI和workflow，usercase，全面集成"

import Foundation
import Combine
import os.log

private let simBridgeLog = Logger(subsystem: "com.fusion.studio", category: "SimulationBridge")

class SimulationBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var isLoading: Bool = false
    @Published var status: SimStatusDTO?
    @Published var lastStepResult: SimStepResultDTO?
    @Published var envCheck: [String: SimEnvCheckComponent] = [:]
    @Published var observations: [String: [String: Any]] = [:]
    @Published var agents: [SimEntityInfo] = []
    @Published var sensors: [SimEntityInfo] = []

    private let baseURL: String
    private let session: URLSession
    private var reconnectTimer: Timer?

    init(baseURL: String = FusionConfig.shared.simulationBaseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        checkHealth()
    }

    deinit {
        reconnectTimer?.invalidate()
    }

    // MARK: - Health & Reconnect

    func checkHealth() {
        get("/api/health") { [weak self] (result: Result<SimStatusDTO, Error>) in
            switch result {
            case .success(let dto):
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                    self?.status = dto
                    self?.reconnectTimer?.invalidate()
                    self?.reconnectTimer = nil
                }
            case .failure(let err):
                self?.handleHealthFailure(err)
            }
        }
    }

    private func handleHealthFailure(_ error: Error) {
        let msg = error.localizedDescription
        simBridgeLog.error("SimulationBridge health failed: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.lastError = "health: \(msg)"
            self?.scheduleReconnect()
        }
    }

    // 对齐 IPCClient 3s 重连策略：健康探测失败后每 3s 重试，成功即停止
    private func scheduleReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.checkHealth()
            }
        }
    }

    // MARK: - Status & Observations

    func fetchStatus() {
        get("/api/status") { [weak self] (result: Result<SimStatusDTO, Error>) in
            switch result {
            case .success(let dto):
                DispatchQueue.main.async { self?.status = dto }
            case .failure(let err):
                self?.handleError(err, context: "status")
            }
        }
    }

    func envCheckRequest() {
        get("/api/env_check") { [weak self] (result: Result<[String: SimEnvCheckComponent], Error>) in
            switch result {
            case .success(let comps):
                DispatchQueue.main.async { self?.envCheck = comps }
            case .failure(let err):
                self?.handleError(err, context: "env_check")
            }
        }
    }

    func fetchObservations() {
        guard let url = URL(string: "\(baseURL)/api/observations") else {
            handleError(SimulationBridgeError.invalidURL, context: "observations"); return
        }
        session.dataTask(with: url) { [weak self] data, _, error in
            if let err = error {
                self?.handleError(err, context: "observations"); return
            }
            guard let data = data else {
                self?.handleError(SimulationBridgeError.noData, context: "observations"); return
            }
            do {
                let parsed = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] ?? [:]
                DispatchQueue.main.async { self?.observations = parsed }
            } catch {
                simBridgeLog.error("Observations parse failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Control (query-param POSTs)

    func initSim(completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/init", query: [:]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func step(numSteps: Int, completion: ((Result<SimStepResultDTO, Error>) -> Void)? = nil) {
        DispatchQueue.main.async { self.isLoading = true }
        postQuery("/api/step", query: ["num_steps": String(numSteps)]) { [weak self] (result: Result<SimStepResultDTO, Error>) in
            DispatchQueue.main.async { self?.isLoading = false }
            switch result {
            case .success(let step):
                DispatchQueue.main.async { self?.lastStepResult = step }
                completion?(.success(step))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func reset(completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/reset", query: [:]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.lastError = resp.error
                    self?.lastStepResult = nil
                }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func pause(completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/pause", query: [:]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func resume(completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/resume", query: [:]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func loadScene(name: String, completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/load_scene", query: ["name": name]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func addSensor(type: String, name: String, entityId: String, completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        let q = ["type": type, "name": name, "entity_id": entityId]
        postQuery("/api/add_sensor", query: q) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.lastError = resp.error
                    if resp.error == nil {
                        self?.sensors.append(SimEntityInfo(name: name, kind: type, detail: entityId))
                    }
                }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func addAgent(name: String, role: String, actionDim: Int, entityId: String, modelName: String, completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        let q: [String: String] = [
            "name": name, "role": role, "action_dim": String(actionDim),
            "entity_id": entityId, "model_name": modelName,
        ]
        postQuery("/api/add_agent", query: q) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.lastError = resp.error
                    if resp.error == nil {
                        self?.agents.append(SimEntityInfo(name: name, kind: role, detail: modelName))
                    }
                }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func saveSnapshot(name: String, completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/save_snapshot", query: ["name": name]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    func restoreSnapshot(snapshotId: String, completion: ((Result<SimActionResponseDTO, Error>) -> Void)? = nil) {
        postQuery("/api/restore_snapshot", query: ["snapshot_id": snapshotId]) { [weak self] (result: Result<SimActionResponseDTO, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.lastError = resp.error }
                completion?(.success(resp))
                self?.fetchStatus()
            case .failure(let err):
                completion?(.failure(err))
            }
        }
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(SimulationBridgeError.invalidURL)); return
        }
        session.dataTask(with: url) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(SimulationBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder.sim.decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                simBridgeLog.error("Decode failed for \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // fusion-sim POST 端点使用 query 参数（非 JSON body），故提供 query-param POST helper
    private func postQuery<T: Decodable>(_ path: String, query: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            completion(.failure(SimulationBridgeError.invalidURL)); return
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            completion(.failure(SimulationBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(SimulationBridgeError.noData)); return }
            do {
                let decoded = try JSONDecoder.sim.decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                simBridgeLog.error("Decode failed for POST \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        simBridgeLog.error("SimulationBridge error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
            if msg.contains("connect") || msg.contains("refused") {
                self?.isConnected = false
                self?.checkHealth()
            }
        }
    }
}

// MARK: - DTOs

extension JSONDecoder {
    static let sim: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

struct SimStatusDTO: Decodable {
    var status: String?
    var initialized: Bool?
    var running: Bool?
    var state: String?
    var simTime: Double?
    var frameCount: Int?
    var entityCount: Int?
    var realTimeFactor: Double?
    var paused: Bool?
}

struct SimStepResultDTO: Decodable {
    var simTime: Double
    var frameCount: Int
    var physicsStepMs: Double
    var sensorCollectMs: Double
    var agentDecideMs: Double
    var renderMs: Double
    var totalMs: Double
}

struct SimActionResponseDTO: Decodable {
    var status: String?
    var name: String?
    var snapshotId: String?
    var restored: Bool?
    var result: String?
    var error: String?
}

struct SimEnvCheckComponent: Decodable {
    var available: Bool
    var version: String?
}

struct SimEntityInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let kind: String
    let detail: String
}

enum SimulationBridgeError: Error, LocalizedError {
    case invalidURL
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data returned"
        }
    }
}
