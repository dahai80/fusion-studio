// ARCH-1 PR7 (#359 facade-delegate): Project Chat 行为从 AgentBridge God-object 迁入 ProjectChatState 域。
//   本文件含 2 extension:
//     1) extension ProjectChatState — 6 真实方法体 (clearChat/infer/inferStream + 3 private helper)。
//        全纯 HTTP (URLSession.shared + FusionConfig), 0 IPC, 0 跨域读 → 无 ipcClient ref。
//     2) extension AgentBridge — sendProjectChat (跨域协调器读 mlxState.models, 留主类) + capChatMessages
//        (static, 仅 sendProjectChat 调) + 3 个 1 行 facade stub 委托到 projectChatState.X(), 保外部 call site 签名零变。
//   @Published self.projectChatState.chatMessages/isInferring 在 ProjectChatState 域 (SwiftUI 读), 经
//     bridge.projectChatState.X 不变。本域 extension 内 self = ProjectChatState, self.X 直读。
//   耦合未迁: Self.mlxSelfHealKeyCandidates (internal static 留 AgentBridge.swift),
//     selfHealApiKeyForInfer 跨文件调 → 显式 AgentBridge.mlxSelfHealKeyCandidates (Self 现为 ProjectChatState)。
//   Logger: 本文件自有 agentProjectChatLog 替代主类 private logger (跨文件不可达)。
//   Callers (infer/inferStream 跨域读, facade stub 保签名): ChatSessionStore/ArtifactsPanel/
//     ProjectModuleView/CodeEditorView/FusionCodeView/sendProjectChat。

import Foundation
import os.log

private let agentProjectChatLog = Logger(subsystem: "com.fusion.studio", category: "AgentProjectChatService")

// MARK: - Project Chat Operations (行为落地 ProjectChatState 域)
extension ProjectChatState {

    // MARK: - Project Chat Operations

    func clearChat() {
        self.chatMessages = []
        FusionProjectManager.shared.activeSession = nil
    }

    func infer(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false) async throws -> String {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        // F-A8 ③: 推理直连 mlxBaseURL (默认 :11434 直连 MLX, 零多节点路由)。
        // 多节点推理路由须经 fusion-gateway(:11432, FUSION_GATEWAY_URL env), 非本 MultiNodeEngine 路由策略。
        agentProjectChatLog.info("infer: route=direct-mlx baseURL=\(baseURL, privacy: .public) (gateway routing only via FUSION_GATEWAY_URL env)")
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
        ]
        if !model.isEmpty {
            body["model"] = model
        }
        if !effort.isEmpty {
            body["reasoning_effort"] = effort
        }
        if thinking {
            body["chat_template_kwargs"] = ["enable_thinking": true]
        }
        if webSearch {
            body["web_search"] = true
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw BridgeError.ipcError("Failed to encode request")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
        request.timeoutInterval = 120
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw BridgeError.serviceUnavailable("MLX non-HTTP response")
        }
        guard httpResp.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            agentProjectChatLog.error("infer: HTTP \(httpResp.statusCode) — \(responseBody)")
            let code = httpResp.statusCode
            if code == 401 || code == 403 {
                // 自愈：env key 常过期（gateway 拒），回退候选 key 重试一次
                if let healed = await selfHealApiKeyForInfer(currentURL: url, routeKey: apiKey) {
                    var retryReq = request
                    retryReq.setValue("Bearer \(healed)", forHTTPHeaderField: "Authorization")
                    let (d2, r2) = try await URLSession.shared.data(for: retryReq)
                    guard let h2 = r2 as? HTTPURLResponse, h2.statusCode == 200 else {
                        throw BridgeError.authFailed("MLX inference returned HTTP \(code) (self-heal retry HTTP \((r2 as? HTTPURLResponse)?.statusCode ?? -1))")
                    }
                    return try parseInferResponse(data: d2, thinking: thinking)
                }
                throw BridgeError.authFailed("MLX inference returned HTTP \(code)")
            }
            throw BridgeError.serviceUnavailable("MLX inference returned HTTP \(code)")
        }
        return try parseInferResponse(data: data, thinking: thinking)
    }

    // 探测候选 key（gateway config.yaml > settings.json > fg-admin-key），首个 200 的持久化并返回。
    private func selfHealApiKeyForInfer(currentURL: URL, routeKey: String) async -> String? {
        let cfg = FusionConfig.shared
        let candidates = await AgentBridge.mlxSelfHealKeyCandidates(currentResolved: routeKey)
        if candidates.isEmpty {
            // 审计0830 P1-错误-6: 区分"无候选 key"(配置缺失) 与"探针失败"(鉴权/网络), 旧实现全静默 continue→nil 不可区分。
            agentProjectChatLog.warning("infer selfHeal: no candidate keys available (config has no mlx api key)")
            return nil
        }
        for key in candidates {
            guard let probeURL = URL(string: "\(cfg.mlxBaseURL)/v1/models") else {
                agentProjectChatLog.warning("infer selfHeal: bad probe URL \(cfg.mlxBaseURL, privacy: .public)/v1/models, skip candidate")
                continue
            }
            var req = URLRequest(url: probeURL)
            req.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 10
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if code == 200 {
                    cfg.mlxApiKey = key
                    agentProjectChatLog.info("infer selfHeal: persisted key (len \(key.count))")
                    return key
                }
                // 审计0830 P1-错误-6/7: 非 200 (含 500) 旧实现静默 continue; 401/403 鉴权失败尤其不可观测。
                if code == 401 || code == 403 {
                    agentProjectChatLog.error("infer selfHeal: probe auth failed HTTP \(code) — candidate key rejected (len \(key.count))")
                } else {
                    agentProjectChatLog.warning("infer selfHeal: probe non-200 HTTP \(code), try next candidate")
                }
            } catch {
                agentProjectChatLog.warning("infer selfHeal: probe failed: \(error.localizedDescription)")
            }
        }
        agentProjectChatLog.warning("infer selfHeal: all \(candidates.count) candidate(s) rejected, self-heal failed")
        return nil
    }

    private func parseInferResponse(data: Data, thinking: Bool) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw BridgeError.decodeError("Invalid /v1/chat/completions response")
        }
        var content = message["content"] as? String ?? ""
        if thinking, let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            content = "🤖\n\(reasoning)\n\n\n\(content)"
        }
        agentProjectChatLog.info("infer: received \(content.count) chars, thinking=\(thinking)")
        return content
    }

    func inferStream(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false, onToken: @escaping (String) -> Void) async throws -> String {
        // Callers: ChatSessionStore.sendMessage, AgentBridge.sendProjectChat. Affected API: inferStream. Data: baseURL, model.
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        // F-A8 ③: 推理直连 mlxBaseURL (默认 :11434 直连 MLX, 零多节点路由)。
        // 多节点推理路由须经 fusion-gateway(:11432, FUSION_GATEWAY_URL env), 非本 MultiNodeEngine 路由策略。
        agentProjectChatLog.info("inferStream: route=direct-mlx baseURL=\(baseURL, privacy: .public) model=\(model, privacy: .public) apiKey=\(apiKey.isEmpty ? "empty" : "set", privacy: .public) webSearch=\(webSearch, privacy: .public) (gateway routing only via FUSION_GATEWAY_URL env)")
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        if webSearch {
            body["web_search"] = true
        }
        if !model.isEmpty {
            body["model"] = model
        }
        if !effort.isEmpty {
            body["reasoning_effort"] = effort
        }
        if thinking {
            body["chat_template_kwargs"] = ["enable_thinking": true]
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw BridgeError.ipcError("Failed to encode request")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
        request.timeoutInterval = 300
        // 审计0830 P2-缓存-1: 推理结果非确定性, 不应命中本地缓存 (旧 URLSession.shared 默认 .useProtocolCachePolicy
        //   可能复用陈旧响应, 同 prompt 返回旧输出)。显式 .reloadIgnoringLocalCacheData 强制每次回源。
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw BridgeError.serviceUnavailable("MLX non-HTTP response")
        }
        if httpResp.statusCode == 401 || httpResp.statusCode == 403 {
            agentProjectChatLog.error("inferStream: auth failed HTTP \(httpResp.statusCode), baseURL=\(baseURL), apiKeyLen=\(apiKey.count), route=studio")
            // 自愈：env key 常过期（gateway 拒），回退候选 key 重试一次（流式重发）
            if let healed = await selfHealApiKeyForInfer(currentURL: url, routeKey: apiKey) {
                var retryReq = request
                retryReq.setValue("Bearer \(healed)", forHTTPHeaderField: "Authorization")
                let (b2, r2) = try await URLSession.shared.bytes(for: retryReq)
                guard let h2 = r2 as? HTTPURLResponse, h2.statusCode == 200 else {
                    throw BridgeError.authFailed("MLX returned HTTP \(httpResp.statusCode) (self-heal retry HTTP \((r2 as? HTTPURLResponse)?.statusCode ?? -1))")
                }
                return try await drainStream(bytes: b2, thinking: thinking, onToken: onToken)
            }
            throw BridgeError.authFailed("MLX returned HTTP \(httpResp.statusCode)")
        }
        guard httpResp.statusCode == 200 else {
            // F-ft-8: 区分 404 (模型/端点不存在) vs 5xx (服务端错误) vs 其他 4xx, 语义化错误便于定位。
            let code = httpResp.statusCode
            if code == 404 {
                throw BridgeError.serviceUnavailable("MLX endpoint/model not found (HTTP 404) — check model loaded & baseURL, baseURL=\(baseURL)")
            } else if (500...599).contains(code) {
                throw BridgeError.serviceUnavailable("MLX server error (HTTP \(code)) — backend may be overloaded or crashed")
            } else {
                throw BridgeError.serviceUnavailable("MLX streaming returned HTTP \(code)")
            }
        }
        return try await drainStream(bytes: bytes, thinking: thinking, onToken: onToken)
    }

    // 消费流式响应，拼装 fullContent + thinking 前缀，逐 token 回调
    private func drainStream(bytes: URLSession.AsyncBytes, thinking: Bool, onToken: @escaping (String) -> Void) async throws -> String {
        // 审计0830 P3-缓存-1: 旧 fullContent/thinkingContent += token 在循环内逐次复制全串 = O(n²)。
        //   长输出 (10万 token) 时复制成本陡升, 主线程卡顿。改 [String] append + 末尾 join = O(n)。
        var fullParts: [String] = []
        var thinkingParts: [String] = []
        var isInThinking = thinking
        var lineCount = 0
        for try await line in bytes.lines {
            // F-ft-8: 每 64 行显式 checkCancellation, 让用户取消流时即时抛 CancellationError 而非等流自然结束。
            lineCount += 1
            if lineCount % 64 == 0 { try Task.checkCancellation() }
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any] else {
                continue
            }
            if let token = delta["content"] as? String, !token.isEmpty {
                if isInThinking {
                    thinkingParts.append(token)
                } else {
                    fullParts.append(token)
                    onToken(token)
                }
            }
            if let reasoningToken = delta["reasoning_content"] as? String, !reasoningToken.isEmpty {
                thinkingParts.append(reasoningToken)
            }
            if delta["content"] != nil || delta["reasoning_content"] != nil { continue }
            if let finishReason = firstChoice["finish_reason"] as? String, finishReason == "stop" {
                isInThinking = false
            }
        }
        let thinkingContent = thinkingParts.joined()
        var fullContent = fullParts.joined()
        if !thinkingContent.isEmpty {
            fullContent = "🤖\n\(thinkingContent)\n\n\n\(fullContent)"
        }
        agentProjectChatLog.info("inferStream: received \(fullContent.count) chars total")
        return fullContent
    }

}

// MARK: - Project Chat Operations (facade-delegate stubs — 行为已迁 ProjectChatState 域)
// ARCH-1 PR7: 本 extension 含 sendProjectChat + capChatMessages (跨域协调器/static 留主类) + 3 个 1 行委托,
//   保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    // sendProjectChat 留 AgentBridge: 跨域协调器 — 读 self.mlxState.models (MLX 域) 挑默认模型,
    // 调 inferStream stub (经 self.projectChatState.inferStream 真实体), 写 self.projectChatState.chatMessages/isInferring。
    // 同 executeGraph/taskExecuteImmediate: 跨域读写需 bridge reach-through, 不可纯落单域。
    func sendProjectChat(_ userMessage: String) async throws -> String {
        let pm = FusionProjectManager.shared
        guard let project = pm.activeProject else {
            throw BridgeError.notConnected
        }

        if pm.activeSession == nil {
            _ = pm.createSession(projectId: project.id, title: String(userMessage.prefix(40)), model: project.settings.defaultModel)
        }

        let userRecord = ChatMessageRecord(role: "user", content: userMessage)
        self.projectChatState.chatMessages.append(userRecord)
        Self.capChatMessages(&self.projectChatState.chatMessages)
        if let session = pm.activeSession {
            pm.addMessage(toSession: session.id, role: "user", content: userMessage)
        }

        let systemPrompt = await ContextAssembler.shared.assembleWithRAG(project: pm.activeProject, query: userMessage)
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for msg in self.projectChatState.chatMessages {
            messages.append(["role": msg.role, "content": msg.content])
        }

        self.projectChatState.isInferring = true
        defer { self.projectChatState.isInferring = false }

        let projectSettings = pm.activeProject?.settings ?? ProjectSettings()
        var chatModel = projectSettings.defaultModel
        if chatModel.isEmpty {
            chatModel = MLXModelInfo.preferredDefault(in: self.mlxState.models)?.name ?? ""
            agentProjectChatLog.info("sendProjectChat: default model empty, picked \(chatModel)")
        }
        // BUG-1: 旧实现流结束才在 :1049 追加 assistantRecord, 与 onToken 的流式追加竞争 ->
        // 最终 record 覆盖流式部分 (或并行 Task 乱序导致 token 丢失/错位)。修正: 流开始前预置空
        // assistant 占位, onToken 逐 token 原位追加, 流结束不再重复 append (response 即占位累计内容)。
        let assistantRecord = ChatMessageRecord(role: "assistant", content: "")
        self.projectChatState.chatMessages.append(assistantRecord)
        Self.capChatMessages(&self.projectChatState.chatMessages)
        // F-R2: 旧 onToken 每 token 一个 Task { @MainActor } = 千 token 千 Task 派发风暴。
        // 改 throttle 聚合: 累积 token 到 buffer, 距上次刷新 >50ms 才 hop 到 MainActor 写 @Published。
        // 末帧残量不单独 flush: 流结束 L984 `self.projectChatState.chatMessages[last].content = response` 用完整 response 回填占位。
        var tokenBuffer = ""
        var lastFlush = DispatchTime.now()
        let throttleNs: UInt64 = 50_000_000
        let response = try await inferStream(
            messages: messages,
            model: chatModel,
            temperature: projectSettings.temperature,
            maxTokens: projectSettings.maxTokens,
            onToken: { token in
                tokenBuffer += token
                let now = DispatchTime.now()
                if now.uptimeNanoseconds - lastFlush.uptimeNanoseconds >= throttleNs {
                    lastFlush = now
                    let snapshot = tokenBuffer
                    tokenBuffer = ""
                    Task { @MainActor in
                        if let lastIdx = self.projectChatState.chatMessages.indices.last, self.projectChatState.chatMessages[lastIdx].role == "assistant" {
                            self.projectChatState.chatMessages[lastIdx].content += snapshot
                        }
                    }
                }
            }
        )

        // 流结束: 若 inferStream 返回值与占位累计不一致 (如含 thinking 前缀), 以完整 response 回填占位记录,
        // 并持久化到 session。不再重复 append (避免双条 assistant 消息)。
        if let lastIdx = self.projectChatState.chatMessages.indices.last, self.projectChatState.chatMessages[lastIdx].role == "assistant" {
            self.projectChatState.chatMessages[lastIdx].content = response
        }
        if let session = pm.activeSession {
            pm.addMessage(toSession: session.id, role: "assistant", content: response)
        }
        agentProjectChatLog.info("sendProjectChat done: respLen=\(response.count)")
        return response
    }

    func clearChat() {
        projectChatState.clearChat()
    }

    func infer(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false) async throws -> String {
        try await projectChatState.infer(messages: messages, model: model, temperature: temperature, maxTokens: maxTokens, effort: effort, thinking: thinking, webSearch: webSearch)
    }

    func inferStream(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false, onToken: @escaping (String) -> Void) async throws -> String {
        try await projectChatState.inferStream(messages: messages, model: model, temperature: temperature, maxTokens: maxTokens, effort: effort, thinking: thinking, webSearch: webSearch, onToken: onToken)
    }

    // F-A2: self.projectChatState.chatMessages 无界 append, 长会话内存单调增长。保留最近 200 条 (LRU 语义:
    // 旧消息越早越无回看价值, 且 LLM 上下文本身有限), 超额丢弃最旧。PERF-3 ragResults 范式。
    // 留 AgentBridge static: 仅 sendProjectChat (主类) 调, Self=AgentBridge 调直接。
    static func capChatMessages(_ msgs: inout [ChatMessageRecord]) {
        let cap = 200
        if msgs.count > cap {
            let dropped = msgs.count - cap
            msgs.removeFirst(dropped)
            agentProjectChatLog.info("capChatMessages: trimmed to \(cap) (dropped \(dropped))")
        }
    }
}
