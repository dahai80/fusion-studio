import AppKit
import Foundation
import os.log

// ARCH-1 Phase 3 (审计product-0906 P1): DesignArtifact 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignChatPanel.saveAsArtifact + DesignArtifactExporter.sanitizeFileName 0 改)。
//   跨域写 (page: pages/currentPageIndex; chat: errorMessage) 经 self.bridge?.X reach-through。
//   sessionId 迁本域 (saveAsArtifact 唯一读, clearConversation 重置)。
//   Self.sanitizeErrorBody 留 DesignBridge → 显式 DesignBridge.sanitizeErrorBody 调用。

private let designArtifactLog = Logger(subsystem: "com.fusion.studio", category: "DesignArtifactService")

extension DesignArtifactState {

    func saveAsArtifact() async {
        guard !currentArtifactCode.isEmpty else { return }
        guard let ipc = ipcClient else {
            bridge?.errorMessage = "IPCClient not initialized"
            return
        }

        do {
            let projectId = FusionProjectManager.shared.activeProject?.id
            let designMetadata: [String: Any] = [
                "component_name": currentArtifactTitle,
                "framework": currentArtifactType,
                "layout_type": "responsive",
                "source": "fusion-design"
            ]
            if artifactId.isEmpty {
                let result = try await ipc.artifactCreate(
                    sessionId: sessionId,
                    name: currentArtifactTitle.isEmpty ? "Design \(DateFormatter.shortDate.string(from: Date()))" : currentArtifactTitle,
                    type: currentArtifactType,
                    kind: kindForType(currentArtifactType),
                    content: currentArtifactCode,
                    projectId: projectId,
                    metadata: designMetadata
                )
                if let id = result["id"] as? String { artifactId = id }
            } else {
                _ = try await ipc.artifactUpdate(
                    artifactId: artifactId,
                    content: currentArtifactCode,
                    changeLog: "Updated via Design",
                    projectId: projectId,
                    metadata: designMetadata
                )
            }
            artifactSaved = true
            if let pages = bridge?.pages, let curIdx = bridge?.currentPageIndex, pages.indices.contains(curIdx) {
                bridge?.pages[curIdx].artifactId = artifactId
                bridge?.pages[curIdx].code = currentArtifactCode
                bridge?.pages[curIdx].title = currentArtifactTitle
                bridge?.pages[curIdx].type = currentArtifactType
            } else if !artifactId.isEmpty {
                let page = DesignPage(artifactId: artifactId, title: currentArtifactTitle, type: currentArtifactType, code: currentArtifactCode)
                bridge?.pages.append(page)
                bridge?.currentPageIndex = (bridge?.pages.count ?? 1) - 1
            }
            designArtifactLog.info("DesignArtifact: artifact saved — \(self.currentArtifactTitle), id=\(self.artifactId)")
        } catch {
            bridge?.errorMessage = "Save failed: \(error.localizedDescription)"
            designArtifactLog.error("DesignArtifact saveAsArtifact: \(error)")
        }
    }

    func kindForType(_ type: String) -> String {
        switch type.lowercased() {
        case "html", "react": return "app"
        case "markdown": return "document"
        default: return "code"
        }
    }

    func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - Screenshot Import (requires fusion-mlx VLM model, e.g. Qwen2.5-VL)

    func importScreenshot(_ image: NSImage) async {
        guard let message = ScreenshotImporter.buildImportRequest(image: image) else {
            bridge?.errorMessage = "Failed to process screenshot image"
            return
        }

        isImportingScreenshot = true
        designArtifactLog.info("DesignArtifact: starting screenshot import")

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            bridge?.errorMessage = "Invalid MLX URL"
            isImportingScreenshot = false
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.defaultModel(for: .code),
            "messages": [message],
            "temperature": 0.3,
            "max_tokens": 4096,
            "stream": false
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResp = response as? HTTPURLResponse else {
                throw NSError(domain: "DesignBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResp.statusCode == 422 {
                bridge?.errorMessage = "Screenshot import requires a VLM model (e.g. Qwen2.5-VL). Current model does not support image input."
                designArtifactLog.warning("DesignArtifact: screenshot import — model does not support image input (422)")
            } else if httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let content = choices.first?["message"] as? [String: Any],
                   let text = content["content"] as? String {
                    let result = ScreenshotImporter.parseImportResult(text)
                    currentArtifactCode = result.extractedHTML
                    currentArtifactType = "html"
                    currentArtifactTitle = "Imported Screenshot"
                    artifactSaved = false
                    designArtifactLog.info("DesignArtifact: screenshot imported — \(result.extractedHTML.count) chars, confidence=\(result.confidence)")
                }
            } else {
                // BUG-13: 原始 body 原样插 UI 可泄密钥 — 服务端错误体可回显请求头 (Authorization/Bearer/api_key),
                // .prefix(200) 限长拦不住密钥子串。渲染前过 sanitizeErrorBody 剥敏感子串。
                let rawBody = String(data: data, encoding: .utf8) ?? "unknown"
                let safeBody = DesignBridge.sanitizeErrorBody(rawBody)
                bridge?.errorMessage = "Screenshot import failed: HTTP \(httpResp.statusCode) — \(safeBody.prefix(200))"
                designArtifactLog.error("DesignArtifact: screenshot import failed — HTTP \(httpResp.statusCode)")
            }
        } catch {
            bridge?.errorMessage = "Screenshot import error: \(error.localizedDescription)"
            designArtifactLog.error("DesignArtifact importScreenshot: \(error)")
        }

        isImportingScreenshot = false
    }
}
