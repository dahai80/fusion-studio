import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 4: Sync 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名)。
//   跨域写: 0 (纯本域 @Published: clusterSyncStatus)。
//   HTTP infra (get, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   triggerIncrementalSync 用原生 session.dataTask (非 engine.get 模板), 经 bridge?.session / bridge?.baseURL /
//   bridge?.authHeaders reach-through。

private let mnSyncLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeSyncService")

extension MultiNodeSyncState {

    func fetchClusterSyncStatus() {
        bridge?.get("/api/cluster/status") { [weak self] (result: Result<ClusterSyncStatus, Error>) in
            switch result {
            case .success(let status):
                DispatchQueue.main.async { self?.clusterSyncStatus = status }
            case .failure:
                mnSyncLog.debug("Cluster sync status not available")
            }
        }
    }

    func triggerIncrementalSync(modelName: String, sourceHost: String, sourcePort: Int? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let baseURL = bridge?.baseURL,
              let url = URL(string: "\(baseURL)/api/sync/incremental") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bridge?.authHeaders(&request)
        let body: [String: Any] = [
            "model_name": modelName,
            "source_host": sourceHost,
            "source_port": sourcePort ?? FusionConfig.shared.multiNodePort,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        bridge?.session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                mnSyncLog.info("Incremental sync triggered for \(modelName)")
                completion(.success(json))
            } else {
                completion(.failure(EngineError.noData))
            }
        }.resume()
    }
}
