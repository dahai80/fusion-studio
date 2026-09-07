import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 5: AgentServer 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名)。
//   AgentServer 域 0 @Published — 纯方法域 (agent 端口健康/硬件查询)。
//   HTTP infra (session, agentBaseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。

private let mnAgentServerLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeAgentServerService")

extension MultiNodeAgentServerState {

    func fetchAgentHardware(completion: @escaping (Result<AgentHardwareInfo, Error>) -> Void) {
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/hardware") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        bridge?.authHeaders(&req)
        bridge?.session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(AgentHardwareInfo.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func checkAgentHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/health") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        bridge?.authHeaders(&req)
        bridge?.session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ok" {
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
