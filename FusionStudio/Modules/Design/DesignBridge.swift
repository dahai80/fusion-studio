// Callers: DesignView, DesignChatPanel, DesignPreviewView — all Design module views.
// Affected API: DesignBridge @MainActor ObservableObject (published properties + async methods).
// Data schemas: DesignMessage (role/content/timestamp/artifactInfo), ArtifactParseResult (type/title/identifier/code), DesignPage (id/artifactId/title/type/code/createdAt).
// User instruction: "continue" — Phase 3 Task #34 multi-page design management

import AppKit
import Combine
import os.log

private let designBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DesignBridge")

struct DesignMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
    var artifactInfo: ArtifactParseResult?
}

struct ArtifactParseResult {
    var type: String
    var title: String
    var identifier: String
    var code: String
}

struct DesignPage: Identifiable {
    let id = UUID()
    var artifactId: String
    var title: String
    var type: String
    var code: String
    var createdAt: Date

    init(artifactId: String = "", title: String = "Untitled", type: String = "html", code: String = "") {
        self.artifactId = artifactId
        self.title = title
        self.type = type
        self.code = code
        self.createdAt = Date()
    }
}

private enum ArtifactParseState {
    case idle
    case inOpenTag
    case inCode
    case inCloseTag
}

@MainActor
class DesignBridge: ObservableObject {
    @Published var messages: [DesignMessage] = []
    @Published var currentArtifactCode: String = ""
    @Published var currentArtifactType: String = "html"
    @Published var currentArtifactTitle: String = ""
    @Published var isGenerating: Bool = false
    @Published var artifactSaved: Bool = false
    @Published var errorMessage: String?
    @Published var artifactId: String = ""
    @Published var versionHistory: [[String: Any]] = []
    @Published var isLoadingHistory: Bool = false
    @Published var pages: [DesignPage] = []
    @Published var currentPageIndex: Int = -1

    private var parseState: ArtifactParseState = .idle
    private var parseBuffer: String = ""
    private var currentIdentifier: String = ""
    private var rawAssistantContent: String = ""
    private var ipcClient: IPCClient?
    private var sessionId: String = "design-\(UUID().uuidString.prefix(8))"

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        designBridgeLog.info("DesignBridge: IPCClient injected")
    }

    // MARK: - Send Design Chat

    func sendDesignChat(_ userMessage: String) async {
        guard !userMessage.isEmpty else { return }

        let userMsg = DesignMessage(role: "user", content: userMessage, timestamp: Date())
        messages.append(userMsg)
        isGenerating = true
        artifactSaved = false
        errorMessage = nil
        parseState = .idle
        parseBuffer = ""
        rawAssistantContent = ""

        var systemPrompt = DesignPrompts.systemPrompt
        if !currentArtifactCode.isEmpty {
            systemPrompt += "\n\n当前设计代码:\n```html\n\(currentArtifactCode)\n```\n请基于此代码进行迭代修改。"
        }

        if let ragContext = await fetchRAGContext(for: userMessage), !ragContext.isEmpty {
            systemPrompt += "\n\n项目设计规范:\n\(ragContext)"
            designBridgeLog.info("DesignBridge: injected RAG context (\(ragContext.count) chars)")
        }

        var chatMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in messages where msg.role != "system" {
            chatMessages.append(["role": msg.role, "content": msg.content])
        }

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL: \(baseURL)"
            isGenerating = false
            return
        }

        var body: [String: Any] = [
            "messages": chatMessages,
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": true,
        ]
        let model = config.mlxModel
        if !model.isEmpty {
            body["model"] = model
        }

        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Failed to encode request"
            isGenerating = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                throw NSError(domain: "DesignBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "MLX streaming returned non-200"])
            }

            var assistantContent = ""
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any],
                      let token = delta["content"] as? String, !token.isEmpty else {
                    continue
                }

                assistantContent += token
                rawAssistantContent += token
                processStreamToken(token)
            }

            let finalArtifact = extractArtifactFromComplete(rawAssistantContent)
            let assistantMsg = DesignMessage(
                role: "assistant",
                content: assistantContent,
                timestamp: Date(),
                artifactInfo: finalArtifact
            )
            messages.append(assistantMsg)

            if finalArtifact != nil {
                designBridgeLog.info("DesignBridge: artifact parsed — type=\(self.currentArtifactType), title=\(self.currentArtifactTitle), \(self.currentArtifactCode.count) chars")
            } else if !currentArtifactCode.isEmpty {
                let extractedCode = extractCodeBlock(from: rawAssistantContent)
                if !extractedCode.isEmpty {
                    currentArtifactCode = extractedCode
                    designBridgeLog.info("DesignBridge: code block extracted, \(extractedCode.count) chars")
                }
            }

        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge sendDesignChat: \(error)")
        }

        isGenerating = false
    }

    // MARK: - Stream Token Parsing (antArtifact XML)

    private func processStreamToken(_ token: String) {
        parseBuffer += token

        switch parseState {
        case .idle:
            if let range = parseBuffer.range(of: "<antArtifact") {
                parseState = .inOpenTag
                let afterTag = String(parseBuffer[range.upperBound...])
                parseBuffer = afterTag
                parseOpenTagAttributes(afterTag)
            } else if parseBuffer.count > 500 {
                let keep = parseBuffer.suffix(200)
                parseBuffer = String(keep)
            }

        case .inOpenTag:
            if let range = parseBuffer.range(of: ">") {
                parseState = .inCode
                currentArtifactCode = ""
                let afterClose = String(parseBuffer[range.upperBound...])
                parseBuffer = afterClose
                parseOpenTagAttributes(parseBuffer)
                currentArtifactCode += afterClose
            }

        case .inCode:
            if let range = parseBuffer.range(of: "</antArtifact>") {
                let beforeClose = String(parseBuffer[..<range.lowerBound])
                currentArtifactCode += beforeClose
                parseState = .idle
                parseBuffer = ""
            } else {
                if parseBuffer.count > 200 {
                    let flushCount = parseBuffer.count - 100
                    let flushIdx = parseBuffer.index(parseBuffer.startIndex, offsetBy: flushCount)
                    currentArtifactCode += String(parseBuffer[..<flushIdx])
                    parseBuffer = String(parseBuffer[flushIdx...])
                } else {
                    currentArtifactCode += token
                }
            }

        case .inCloseTag:
            break
        }
    }

    private func parseOpenTagAttributes(_ text: String) {
        if let typeRange = text.range(of: "type=\"") {
            let start = typeRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentArtifactType = String(text[start..<end])
            }
        }
        if let titleRange = text.range(of: "title=\"") {
            let start = titleRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentArtifactTitle = String(text[start..<end])
            }
        }
        if let idRange = text.range(of: "identifier=\"") {
            let start = idRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentIdentifier = String(text[start..<end])
            }
        }
    }

    // MARK: - Post-hoc Artifact Extraction

    func extractArtifactFromComplete(_ content: String) -> ArtifactParseResult? {
        guard let openRange = content.range(of: "<antArtifact") else { return nil }
        guard let closeRange = content.range(of: "</antArtifact>", range: openRange.upperBound..<content.endIndex) else { return nil }

        let openTagEnd = content.range(of: ">", range: openRange.lowerBound..<closeRange.lowerBound)!
        let openTag = String(content[openRange.lowerBound..<openTagEnd.upperBound])
        let code = String(content[openTagEnd.upperBound..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

        var artType = "html"
        var artTitle = "Design"
        var artId = ""

        if let typeRange = openTag.range(of: "type=\"") {
            let start = typeRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artType = String(openTag[start..<end])
            }
        }
        if let titleRange = openTag.range(of: "title=\"") {
            let start = titleRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artTitle = String(openTag[start..<end])
            }
        }
        if let idRange = openTag.range(of: "identifier=\"") {
            let start = idRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artId = String(openTag[start..<end])
            }
        }

        currentArtifactType = artType
        currentArtifactTitle = artTitle
        currentArtifactCode = code
        currentIdentifier = artId

        return ArtifactParseResult(type: artType, title: artTitle, identifier: artId, code: code)
    }

    func extractCodeBlock(from content: String) -> String {
        let patterns = ["```html\n", "```react\n", "```jsx\n", "```\n"]
        for prefix in patterns {
            if let startRange = content.range(of: prefix) {
                let codeStart = startRange.upperBound
                if let endRange = content.range(of: "```", range: codeStart..<content.endIndex) {
                    return String(content[codeStart..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return ""
    }

    // MARK: - Save Artifact

    func saveAsArtifact() async {
        guard !currentArtifactCode.isEmpty else { return }
        guard let ipc = ipcClient else {
            errorMessage = "IPCClient not initialized"
            return
        }

        do {
            if artifactId.isEmpty {
                let result = try await ipc.artifactCreate(
                    sessionId: sessionId,
                    name: currentArtifactTitle.isEmpty ? "Design \(DateFormatter.shortDate.string(from: Date()))" : currentArtifactTitle,
                    type: currentArtifactType,
                    kind: kindForType(currentArtifactType),
                    content: currentArtifactCode
                )
                if let id = result["id"] as? String { artifactId = id }
            } else {
                _ = try await ipc.artifactUpdate(
                    artifactId: artifactId,
                    content: currentArtifactCode,
                    changeLog: "Updated via Design"
                )
            }
            artifactSaved = true
            if pages.indices.contains(currentPageIndex) {
                pages[currentPageIndex].artifactId = artifactId
                pages[currentPageIndex].code = currentArtifactCode
                pages[currentPageIndex].title = currentArtifactTitle
                pages[currentPageIndex].type = currentArtifactType
            } else if !artifactId.isEmpty {
                let page = DesignPage(artifactId: artifactId, title: currentArtifactTitle, type: currentArtifactType, code: currentArtifactCode)
                pages.append(page)
                currentPageIndex = pages.count - 1
            }
            designBridgeLog.info("DesignBridge: artifact saved — \(self.currentArtifactTitle), id=\(self.artifactId)")
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge saveAsArtifact: \(error)")
        }
    }

    func kindForType(_ type: String) -> String {
        switch type.lowercased() {
        case "html", "react": return "app"
        case "markdown": return "document"
        default: return "code"
        }
    }

    // MARK: - Utility

    func clearConversation() {
        messages = []
        currentArtifactCode = ""
        currentArtifactTitle = ""
        currentArtifactType = "html"
        artifactSaved = false
        artifactId = ""
        versionHistory = []
        pages = []
        currentPageIndex = -1
        errorMessage = nil
        parseState = .idle
        parseBuffer = ""
        rawAssistantContent = ""
        sessionId = "design-\(UUID().uuidString.prefix(8))"
    }

    // MARK: - Multi-Page Management

    func addPage() {
        let page = DesignPage(title: "Page \(pages.count + 1)")
        pages.append(page)
        switchToPage(at: pages.count - 1)
        designBridgeLog.info("DesignBridge: added page '\(page.title)', total=\(self.pages.count)")
    }

    func deletePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let wasCurrent = index == currentPageIndex
        pages.remove(at: index)
        if pages.isEmpty {
            currentPageIndex = -1
            currentArtifactCode = ""
            currentArtifactTitle = ""
            currentArtifactType = "html"
            artifactId = ""
        } else if wasCurrent {
            let newIndex = min(index, pages.count - 1)
            switchToPage(at: newIndex)
        } else if currentPageIndex > index {
            currentPageIndex -= 1
        }
        designBridgeLog.info("DesignBridge: deleted page at \(index), remaining=\(self.pages.count)")
    }

    func switchToPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        saveCurrentPageState()
        currentPageIndex = index
        let page = pages[index]
        currentArtifactCode = page.code
        currentArtifactTitle = page.title
        currentArtifactType = page.type
        artifactId = page.artifactId
        versionHistory = []
        designBridgeLog.info("DesignBridge: switched to page '\(page.title)' at \(index)")
    }

    func renamePage(at index: Int, newTitle: String) {
        guard pages.indices.contains(index) else { return }
        pages[index].title = newTitle
        if index == currentPageIndex {
            currentArtifactTitle = newTitle
        }
        designBridgeLog.info("DesignBridge: renamed page at \(index) to '\(newTitle)'")
    }

    func saveCurrentPageState() {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex].code = currentArtifactCode
        pages[currentPageIndex].title = currentArtifactTitle
        pages[currentPageIndex].type = currentArtifactType
        pages[currentPageIndex].artifactId = artifactId
    }

    // MARK: - Version History

    func loadVersionHistory() async {
        guard !artifactId.isEmpty, let ipc = ipcClient else { return }
        isLoadingHistory = true
        do {
            let result = try await ipc.artifactVersionList(artifactId: artifactId)
            if let versions = result["versions"] as? [[String: Any]] {
                versionHistory = versions
            } else if let versions = result["data"] as? [[String: Any]] {
                versionHistory = versions
            }
            designBridgeLog.info("DesignBridge: loaded \(self.versionHistory.count) versions for \(self.artifactId)")
        } catch {
            designBridgeLog.error("DesignBridge loadVersionHistory: \(error)")
        }
        isLoadingHistory = false
    }

    func rollbackToVersion(_ targetVersion: Int) async {
        guard !artifactId.isEmpty, let ipc = ipcClient else { return }
        do {
            _ = try await ipc.artifactVersionRollback(artifactId: artifactId, targetVersion: targetVersion)
            let contentResult = try await ipc.artifactGetContent(artifactId: artifactId)
            if let content = contentResult["content"] as? String {
                currentArtifactCode = content
                artifactSaved = false
            }
            designBridgeLog.info("DesignBridge: rolled back to version \(targetVersion)")
            await loadVersionHistory()
        } catch {
            errorMessage = "Rollback failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge rollbackToVersion: \(error)")
        }
    }

    func copyCurrentCode() {
        guard !currentArtifactCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentArtifactCode, forType: .string)
        designBridgeLog.info("DesignBridge: code copied to clipboard")
    }

    // MARK: - Design RAG

    func fetchRAGContext(for query: String) async -> String? {
        guard let ipc = ipcClient else { return nil }
        do {
            let result = try await ipc.knowledgeSearch(query: query, limit: 3)
            if let entries = result["results"] as? [[String: Any]] {
                let chunks = entries.compactMap { $0["content"] as? String }
                if chunks.isEmpty { return nil }
                return chunks.joined(separator: "\n---\n")
            }
        } catch {
            designBridgeLog.warning("DesignBridge RAG search failed: \(error.localizedDescription)")
        }
        return nil
    }

    func ingestDesignTokens() async {
        guard let ipc = ipcClient else { return }
        let _ = StudioTheme.dark
        let tokenDoc = """
        # Fusion Studio Design Tokens
        ## Colors
        - accent: #007AFF
        - accentDestructive: red
        - greenDot: success green
        - amberDot: warning amber
        - redDot: error red
        ## Spacing (4pt grid)
        - XS: 4pt, S: 8pt, M: 12pt, L: 16pt, XL: 24pt, 2XL: 32pt
        ## Typography
        - caption: 12pt, footnote: 13pt, small: 14pt, text: 15pt, body: 16pt, title: 19pt, headline: 22pt, largeTitle: 30pt
        ## Radius
        - small: 8pt, default: 12pt, large: 16pt
        ## Animation
        - fast: 0.15s, normal: 0.25s, slow: 0.35s
        """
        let scope = "design:tokens"
        do {
            _ = try await ipc.knowledgeIngest(content: tokenDoc, scope: scope, metadata: ["type": "design_tokens"])
            designBridgeLog.info("DesignBridge: design tokens ingested to RAG")
        } catch {
            designBridgeLog.warning("DesignBridge token ingest failed: \(error.localizedDescription)")
        }
    }

    // MARK: - SwiftUI Export

    @Published var exportedSwiftUICode: String = ""
    @Published var isExportingSwiftUI: Bool = false

    func exportAsSwiftUI() async {
        guard !currentArtifactCode.isEmpty else { return }
        guard ipcClient != nil else {
            errorMessage = "IPCClient not initialized"
            return
        }

        isExportingSwiftUI = true
        let request = SwiftUIExporter.buildConversionRequest(
            htmlCode: currentArtifactCode,
            title: currentArtifactTitle
        )

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL"
            isExportingSwiftUI = false
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.mlxModel,
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 4096,
            "stream": false
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                exportedSwiftUICode = SwiftUIExporter.extractSwiftUICode(from: content)
                designBridgeLog.info("DesignBridge: SwiftUI export done, \(self.exportedSwiftUICode.count) chars")
            }
        } catch {
            errorMessage = "SwiftUI export failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge exportAsSwiftUI: \(error)")
        }
        isExportingSwiftUI = false
    }

    func copyExportedSwiftUI() {
        guard !exportedSwiftUICode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedSwiftUICode, forType: .string)
        designBridgeLog.info("DesignBridge: SwiftUI code copied")
    }

    // MARK: - Artifact ↔ File Sync

    @Published var syncFolderPath: String = ""
    @Published var isFileSyncEnabled: Bool = false

    func enableFileSync(to folderPath: String) {
        syncFolderPath = folderPath
        isFileSyncEnabled = true
        designBridgeLog.info("DesignBridge: file sync enabled to \(folderPath)")
    }

    func disableFileSync() {
        isFileSyncEnabled = false
        syncFolderPath = ""
        designBridgeLog.info("DesignBridge: file sync disabled")
    }

    func syncArtifactToFile() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty, !currentArtifactCode.isEmpty else {
            designBridgeLog.warning("DesignBridge: syncArtifactToFile — preconditions not met")
            return
        }

        let ext = currentArtifactType == "react" ? "jsx" : currentArtifactType
        let fileName = currentArtifactTitle.isEmpty ? "design.\(ext)" : "\(sanitizeFileName(currentArtifactTitle)).\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)

        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "artifact_to_file")
                designBridgeLog.info("DesignBridge: artifact synced via API — \(result)")
            } catch {
                designBridgeLog.warning("DesignBridge: API sync failed, falling back to file write — \(error.localizedDescription)")
                do {
                    try currentArtifactCode.write(toFile: filePath, atomically: true, encoding: .utf8)
                    designBridgeLog.info("DesignBridge: artifact synced to file \(filePath) (fallback)")
                } catch {
                    designBridgeLog.error("DesignBridge: file sync failed — \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try currentArtifactCode.write(toFile: filePath, atomically: true, encoding: .utf8)
                designBridgeLog.info("DesignBridge: artifact synced to file \(filePath)")
            } catch {
                designBridgeLog.error("DesignBridge: file sync failed — \(error.localizedDescription)")
            }
        }
    }

    func syncFileToArtifact() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty else {
            designBridgeLog.warning("DesignBridge: syncFileToArtifact — preconditions not met")
            return
        }

        let ext = currentArtifactType == "react" ? "jsx" : currentArtifactType
        let fileName = currentArtifactTitle.isEmpty ? "design.\(ext)" : "\(sanitizeFileName(currentArtifactTitle)).\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)

        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "file_to_artifact")
                if let content = result["content"] as? String, content != currentArtifactCode {
                    currentArtifactCode = content
                    artifactSaved = false
                    designBridgeLog.info("DesignBridge: file synced to artifact via API (\(content.count) chars)")
                }
                return
            } catch {
                designBridgeLog.warning("DesignBridge: API sync failed, falling back to file read — \(error.localizedDescription)")
            }
        }

        guard FileManager.default.fileExists(atPath: filePath) else {
            designBridgeLog.info("DesignBridge: no file to sync at \(filePath)")
            return
        }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            if content != currentArtifactCode {
                currentArtifactCode = content
                artifactSaved = false
                designBridgeLog.info("DesignBridge: file synced to artifact (\(content.count) chars)")
            }
        } catch {
            designBridgeLog.error("DesignBridge: file→artifact sync failed — \(error.localizedDescription)")
        }
    }

    func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - Screenshot Import (blocked by fusion-mlx multimodal)

    @Published var isImportingScreenshot: Bool = false

    func importScreenshot(_ image: NSImage) async {
        guard let message = ScreenshotImporter.buildImportRequest(image: image) else {
            errorMessage = "Failed to process screenshot image"
            return
        }

        isImportingScreenshot = true
        designBridgeLog.info("DesignBridge: starting screenshot import")

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL"
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
            "model": config.mlxModel,
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
                errorMessage = "Screenshot import requires multimodal model support (not yet available in fusion-mlx)"
                designBridgeLog.warning("DesignBridge: screenshot import blocked — multimodal not supported (422)")
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
                    designBridgeLog.info("DesignBridge: screenshot imported — \(result.extractedHTML.count) chars, confidence=\(result.confidence)")
                }
            } else {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                errorMessage = "Screenshot import failed: HTTP \(httpResp.statusCode) — \(body.prefix(200))"
                designBridgeLog.error("DesignBridge: screenshot import failed — HTTP \(httpResp.statusCode)")
            }
        } catch {
            errorMessage = "Screenshot import error: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge importScreenshot: \(error)")
        }

        isImportingScreenshot = false
    }

    // MARK: - Figma Import (blocked by Figma-Context-MCP)

    func importFromFigma(fileKey: String) async {
        let figmaBridge = FigmaBridge()
        guard let design = await figmaBridge.fetchDesign(fileKey: fileKey) else {
            errorMessage = "Figma import not yet available (requires Figma-Context-MCP)"
            designBridgeLog.warning("DesignBridge: Figma import blocked — MCP not available")
            return
        }

        let html = figmaBridge.convertDesignToHTML(design)
        currentArtifactCode = html
        currentArtifactType = "html"
        currentArtifactTitle = design.fileName
        artifactSaved = false
        designBridgeLog.info("DesignBridge: Figma design imported — \(html.count) chars")
    }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
