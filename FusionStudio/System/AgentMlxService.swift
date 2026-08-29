// ARCH-1 PR1 (#359 facade-delegate): MLX Operations 从 AgentBridge God-object 迁入 MLXState 域。
//   本文件含 2 extension:
//     1) extension MLXState — 10 真实方法体 (行为落地域, 自持 ipcClient ref / mlxStatusTimer / mlxStatusFetchedAt)。
//     2) extension AgentBridge — 9 个 1 行 facade stub 委托到 mlxState.X(), 保 250 外部 call site 签名零变。
//   SwiftUI 仅观察 AgentBridge (82 @EnvironmentObject), 0 直接域观察 → 0 view 改动。永久中间人 stub。
//   models 等 @Published 仍在 MLXState 域, 49 外部读经 bridge.mlxState.X (let 稳定身份), 观察链不变。
// 耦合未迁: mlxSettingsJsonApiKey/gatewayConfigApiKey/mlxSelfHealKeyCandidates/decodeCodable 4 个 nonisolated static
//   留 AgentBridge.swift (用文件级 private agentBridgeStaticLog, 跨文件经 AgentBridge.X() 显式限定可达)。
//   probeMLXRunningStatus/selfHealApiKeyFromSettings 留主类 (用实例 logger + 私有 helper), 经 fetchModels stub 链入域。

import Foundation
import os.log

private let agentMlxLog = Logger(subsystem: "com.fusion.studio", category: "AgentMlxService")

// MARK: - MLX Operations (行为落地 MLXState 域)
extension MLXState {

    func fetchModels() async throws -> [MLXModelInfo] {
        try await fetchModels(withApiKey: FusionConfig.shared.mlxResolvedApiKey)
    }

    private func fetchModels(withApiKey apiKey: String) async throws -> [MLXModelInfo] {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                throw BridgeError.serviceUnavailable("MLX non-HTTP response")
            }
            guard httpResp.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                agentMlxLog.error("fetchModels: HTTP \(httpResp.statusCode) — \(body)")
                let code = httpResp.statusCode
                if code == 401 || code == 403 {
                    // ARCH-1 PR1: Self 现为 MLXState (无此 static), 显式限定 AgentBridge.mlxSettingsJsonApiKey()。
                    if let fallback = await AgentBridge.mlxSettingsJsonApiKey(), !fallback.isEmpty, fallback != apiKey {
                        agentMlxLog.warning("fetchModels: auth failed with resolved key (len \(apiKey.count)), retrying with settings.json key")
                        return try await fetchModels(withApiKey: fallback)
                    }
                    throw BridgeError.authFailed("MLX returned HTTP \(code)")
                }
                throw BridgeError.serviceUnavailable("MLX returned HTTP \(code)")
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelList = json["data"] as? [[String: Any]] else {
                throw BridgeError.decodeError("Invalid /v1/models response")
            }
            var parsed: [MLXModelInfo] = []
            for m in modelList {
                // F-I4: 手动 m["id"] as? String → decodeCodable 强类型解码 (init(from:) 派生 name=id, 缺键 ?? "")。
                guard let model = AgentBridge.decodeCodable(MLXModelInfo.self, from: m, context: "mlxModel") else {
                    agentMlxLog.warning("fetchModels: skip undecodable model entry, keys=\(m.keys.sorted())")
                    continue
                }
                parsed.append(model)
            }
            self.models = parsed
            agentMlxLog.info("fetchModels: received \(parsed.count) models from \(baseURL)")
            return parsed
        } catch let error as BridgeError {
            throw error
        } catch {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            agentMlxLog.error("fetchModels: \(error)")
            throw bridgeErr
        }
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty {
            params["model"] = model
        }
        return try await client.call(method: RPCMethod.mlxStart, params: params)
    }

    func stopMLX() async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxStop)
    }

    func restartMLX(model: String = "") async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty { params["model"] = model }
        return try await client.call(method: RPCMethod.mlxRestart, params: params)
    }

    func mlxStatus() async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxStatus)
    }

    func mlxSetModel(model: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxSetModel, params: ["model": model])
    }

    // F-A2子3: 周期轮询 mlx.status, 解析 running/port/models 填 @Published。30s TTL 守卫防重叠。
    func pollMlxStatus() async {
        if let t = self.mlxStatusFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.mlxStatusFetchedAt = Date()
        do {
            let st = try await self.mlxStatus()
            // 审计0827 #16: MLXState 域 @MainActor, pollMlxStatus 已在 MainActor, 直接赋值 (无冗余 MainActor.run)。
            self.mlxRunning = st["running"] as? Bool ?? false
            self.mlxPort = st["port"] as? Int ?? 0
            if let arr = st["models"] as? [String] {
                self.mlxLoadedModels = arr
            } else if let arr = st["models"] as? [[String: Any]] {
                self.mlxLoadedModels = arr.compactMap { $0["id"] as? String }
            } else {
                self.mlxLoadedModels = []
            }
            agentMlxLog.info("F-A2子3 pollMlxStatus: running=\(self.mlxRunning) models=\(self.mlxLoadedModels.count) port=\(self.mlxPort)")
        } catch {
            agentMlxLog.debug("F-A2子3 pollMlxStatus failed: \(error.localizedDescription)")
        }
    }

    // F-A2子3: 30s 周期轮询 + 首次立即。复用 F-A9 scenePhase 启停模式。
    func startMlxStatusPolling() {
        self.mlxStatusTimer?.invalidate()
        self.mlxStatusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.pollMlxStatus() }
        }
        Task { await self.pollMlxStatus() }
    }

    func stopMlxStatusPolling() {
        self.mlxStatusTimer?.invalidate()
        self.mlxStatusTimer = nil
    }
}

// MARK: - MLX Operations (facade-delegate stubs — 行为已迁 MLXState 域)
// ARCH-1 PR1: 本 extension 仅 1 行委托, 保 250 外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchModels() async throws -> [MLXModelInfo] {
        try await mlxState.fetchModels()
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        try await mlxState.startMLX(model: model)
    }

    func stopMLX() async throws -> [String: Any] {
        try await mlxState.stopMLX()
    }

    func restartMLX(model: String = "") async throws -> [String: Any] {
        try await mlxState.restartMLX(model: model)
    }

    func mlxStatus() async throws -> [String: Any] {
        try await mlxState.mlxStatus()
    }

    func mlxSetModel(model: String) async throws -> [String: Any] {
        try await mlxState.mlxSetModel(model: model)
    }

    func pollMlxStatus() async {
        await mlxState.pollMlxStatus()
    }

    func startMlxStatusPolling() {
        mlxState.startMlxStatusPolling()
    }

    func stopMlxStatusPolling() {
        mlxState.stopMlxStatusPolling()
    }
}
