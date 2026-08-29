// ARCH-1 / F-A1: MLX Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published models 仍存 AgentBridge (extension 不可声明存储属性), 本文件只搬方法体, 行为零变。
// models 29 外部 SwiftUI 读 (SettingsView/ChatSessionStore/ArtifactsPanel/CodeMainView/ProjectsPanel/
// UnifiedChatView/FusionModelPicker/DesignChatPanel/AgentConfigViews), @Published 留主类, extension 写 self.models, 观察链不变。
// 耦合未迁: mlxSettingsJsonApiKey/gatewayConfigApiKey/mlxSelfHealKeyCandidates 3 个 nonisolated static 留 AgentBridge.swift
//   (Project Chat selfHealApiKeyForInfer 跨域调用 Self.mlxSelfHealKeyCandidates, internal 跨文件可达, 不需同文件)。
//   gatewayConfigApiKey 内部用 agentBridgeStaticLog (文件级 private logger), 留主类同文件方可访问。

import Foundation
import os.log

private let agentMlxLog = Logger(subsystem: "com.fusion.studio", category: "AgentMlxService")

extension AgentBridge {

    // MARK: - MLX Operations

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
                    if let fallback = await Self.mlxSettingsJsonApiKey(), !fallback.isEmpty, fallback != apiKey {
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
            self.mlxState.models = parsed
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
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty {
            params["model"] = model
        }
        return try await client.call(method: RPCMethod.mlxStart, params: params)
    }

    func stopMLX() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxStop)
    }

    func restartMLX(model: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty { params["model"] = model }
        return try await client.call(method: RPCMethod.mlxRestart, params: params)
    }

    func mlxStatus() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxStatus)
    }

    func mlxSetModel(model: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.mlxSetModel, params: ["model": model])
    }

    // F-A2子3: 周期轮询 mlx.status, 解析 running/port/models 填 @Published。30s TTL 守卫防重叠。
    func pollMlxStatus() async {
        if let t = mlxStatusFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        mlxStatusFetchedAt = Date()
        do {
            let st = try await mlxStatus()
            // 审计0827 #16: AgentMlxService 为 @MainActor AgentBridge extension, pollMlxStatus 已在 MainActor, MainActor.run 冗余, 直接赋值。
            self.mlxState.mlxRunning = st["running"] as? Bool ?? false
            self.mlxState.mlxPort = st["port"] as? Int ?? 0
            if let arr = st["models"] as? [String] {
                self.mlxState.mlxLoadedModels = arr
            } else if let arr = st["models"] as? [[String: Any]] {
                self.mlxState.mlxLoadedModels = arr.compactMap { $0["id"] as? String }
            } else {
                self.mlxState.mlxLoadedModels = []
            }
            agentMlxLog.info("F-A2子3 pollMlxStatus: running=\(self.mlxState.mlxRunning) models=\(self.mlxState.mlxLoadedModels.count) port=\(self.mlxState.mlxPort)")
        } catch {
            agentMlxLog.debug("F-A2子3 pollMlxStatus failed: \(error.localizedDescription)")
        }
    }

    // F-A2子3: 30s 周期轮询 + 首次立即。复用 F-A9 scenePhase 启停模式。
    func startMlxStatusPolling() {
        mlxStatusTimer?.invalidate()
        mlxStatusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.pollMlxStatus() }
        }
        Task { await pollMlxStatus() }
    }

    func stopMlxStatusPolling() {
        mlxStatusTimer?.invalidate()
        mlxStatusTimer = nil
    }
}
