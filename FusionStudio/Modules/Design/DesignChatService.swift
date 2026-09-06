import Foundation
import os.log

// ARCH-1 Phase 2 (审计product-0906 P1): DesignChat 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   测试 + DesignWorkflowOrchestrator.parseHtmlViaCLI + sendDesignChat 协调器 0 改)。
//   跨域写 (artifact: currentArtifactCode/Type/Title) 经 self.bridge?.artifactState.X reach-through。
//   Self.sanitizeHtml / resolveCLIPath / runCLIProcess 留 DesignBridge → 显式 DesignBridge.X 调用。

private let designChatLog = Logger(subsystem: "com.fusion.studio", category: "DesignChatService")

extension DesignChatState {

    // PERF-4 (审计product-0905 P2): messages 无界, 长会话内存涨。LRU cap。
    static let maxMessages = 200

    func capMessages() {
        guard messages.count > Self.maxMessages else { return }
        let drop = messages.count - Self.maxMessages
        messages.removeFirst(drop)
        designChatLog.info("DesignChat capMessages: drop \(drop) oldest (count > \(Self.maxMessages))")
    }

    // 调用 fusion-design parse-html CLI 将 HTML 转为 PenDocument JSON。
    func parseHtmlViaCLI(_ html: String) async -> String? {
        // HIGH-6: currentArtifactCode 来自 LLM 不可信输出, 可被 prompt 注入操纵 emit 含
        // <script> 的 HTML。送 CLI 解析 + 后续 wasm 渲染 = XSS 等价, 可调原生 bridge 读本地资源。
        // 渲染前净化 (纵深防御, 与 CLI 解析侧校验正交): 剥 <script>/<iframe>/<object>/<embed>,
        // 剥 on* 事件处理器属性, 剥 javascript:/vbscript: URL, 净化 <style> 内 CSS XSS 向量。
        // <style> 块本体保留 (合法 :root 设计 token + 自定义 class), 仅剥 expression/url-js/@import。
        // PERF-2: CLI 调用移出 MainActor (Task.detached), 避免阻塞 UI。
        let safe = DesignBridge.sanitizeHtml(html)
        let page = (bridge?.currentArtifactTitle.isEmpty ?? true) ? "Page" : (bridge?.currentArtifactTitle ?? "Page")
        guard let cliPath = bridge?.resolveCLIPath() else {
            designChatLog.error("DesignChat: parseHtmlViaCLI — CLI path resolve failed (bridge nil?)")
            return nil
        }
        let result = await Task.detached(priority: .userInitiated) {
            DesignBridge.runCLIProcess(cliPath: cliPath, args: ["parse-html", "--page", page], stdin: safe)
        }.value
        guard result.exitCode == 0 else {
            designChatLog.warning("DesignChat: parse-html failed: \(result.error)")
            return nil
        }
        return result.output.isEmpty ? nil : result.output
    }

    func parseHtmlFromPenOutput(_ output: String) -> String? {
        if output.contains("<html") || output.contains("<!DOCTYPE") {
            return output
        }
        if output.contains("<antArtifact") {
            let pattern = try? NSRegularExpression(pattern: "<antArtifact[^>]*>([\\s\\S]*?)</antArtifact>")
            if let match = pattern?.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                return String(output[range])
            }
        }
        return nil
    }

    // MARK: - Stream Token Parsing (antArtifact XML)

    func processStreamToken(_ token: String) {
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
                bridge?.artifactState.currentArtifactCode = ""
                let afterClose = String(parseBuffer[range.upperBound...])
                parseBuffer = afterClose
                parseOpenTagAttributes(parseBuffer)
                bridge?.artifactState.currentArtifactCode = (bridge?.artifactState.currentArtifactCode ?? "") + afterClose
            }

        case .inCode:
            if let range = parseBuffer.range(of: "</antArtifact>") {
                let beforeClose = String(parseBuffer[..<range.lowerBound])
                bridge?.artifactState.currentArtifactCode = (bridge?.artifactState.currentArtifactCode ?? "") + beforeClose
                parseState = .idle
                parseBuffer = ""
            } else {
                if parseBuffer.count > 200 {
                    let flushCount = parseBuffer.count - 100
                    let flushIdx = parseBuffer.index(parseBuffer.startIndex, offsetBy: flushCount)
                    bridge?.artifactState.currentArtifactCode = (bridge?.artifactState.currentArtifactCode ?? "") + String(parseBuffer[..<flushIdx])
                    parseBuffer = String(parseBuffer[flushIdx...])
                } else {
                    bridge?.artifactState.currentArtifactCode = (bridge?.artifactState.currentArtifactCode ?? "") + token
                }
            }

        case .inCloseTag:
            break
        }
    }

    func parseOpenTagAttributes(_ text: String) {
        if let typeRange = text.range(of: "type=\"") {
            let start = typeRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                bridge?.artifactState.currentArtifactType = String(text[start..<end])
            }
        }
        if let titleRange = text.range(of: "title=\"") {
            let start = titleRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                bridge?.artifactState.currentArtifactTitle = String(text[start..<end])
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
        guard let openTagEnd = content.range(of: ">", range: openRange.upperBound..<content.endIndex) else { return nil }

        let openTag = String(content[openRange.lowerBound..<openTagEnd.upperBound])
        var code: String
        if let closeRange = content.range(of: "</antArtifact>", range: openTagEnd.upperBound..<content.endIndex) {
            code = String(content[openTagEnd.upperBound..<closeRange.lowerBound])
        } else {
            code = String(content[openTagEnd.upperBound..<content.endIndex])
            designChatLog.warning("DesignChat: antArtifact open tag found but close tag missing (likely truncated by max_tokens), extracting partial code")
        }
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)

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

        bridge?.artifactState.currentArtifactType = artType
        bridge?.artifactState.currentArtifactTitle = artTitle
        bridge?.artifactState.currentArtifactCode = code
        currentIdentifier = artId

        return ArtifactParseResult(type: artType, title: artTitle, identifier: artId, code: code)
    }

    func extractCodeBlock(from content: String) -> String {
        let fenceOpeners = ["```html", "```react", "```jsx", "```"]
        for opener in fenceOpeners {
            guard let startRange = content.range(of: opener) else { continue }
            let codeStart = content.index(after: startRange.upperBound)
            let codeStartAdjusted = codeStart < content.endIndex && content[codeStart] == "\n"
                ? content.index(after: codeStart)
                : codeStart
            if let endRange = content.range(of: "```", range: codeStartAdjusted..<content.endIndex) {
                return String(content[codeStartAdjusted..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(content[codeStartAdjusted..<content.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}
