// Callers: DesignChatPanel (screenshot import button), DesignBridge (importScreenshot)
// Affected API: DesignBridge.importScreenshot(_:), fusion-mlx /v1/chat/completions (multimodal image_url)
// Data schemas: ScreenshotImportResult (extractedHTML/designTokens/detectedComponents/confidence), NSImage→base64 PNG
// User instruction: "继续完成遗留和defer的任务" — Phase 3 Task #13 screenshot-to-code stub

import AppKit
import os.log

private let screenshotLog = Logger(subsystem: "com.fusion.studio", category: "ScreenshotImporter")

struct ScreenshotImportResult {
    var extractedHTML: String
    var designTokens: [String: String]
    var detectedComponents: [String]
    var confidence: Double
}

struct ScreenshotImporter {

    static let importPrompt = """
    You are a UI design reconstruction expert. Analyze the provided screenshot and generate:
    1. A complete HTML file with Tailwind CSS classes that recreates the design
    2. Extracted design tokens (colors, spacing, typography)
    3. A list of detected UI components (button, card, nav, etc.)

    Rules:
    - Use Tailwind CSS utility classes
    - Match colors as closely as possible
    - Preserve layout structure and spacing
    - Make it responsive
    - Output the HTML inside <antArtifact type="html" title="Imported Design">...</antArtifact>
    - After the artifact, output a JSON block with extracted tokens:
      ```json
      { "tokens": { "colors": {...}, "spacing": {...}, "typography": {...} }, "components": [...] }
      ```
    """

    static func buildImportRequest(image: NSImage, additionalContext: String = "") -> [String: Any]? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            screenshotLog.error("ScreenshotImporter: failed to convert NSImage to PNG")
            return nil
        }

        let base64Image = pngData.base64EncodedString()
        let imageContent: [String: Any] = [
            "type": "image_url",
            "image_url": [
                "url": "data:image/png;base64,\(base64Image)"
            ]
        ]
        let textContent: [String: Any] = [
            "type": "text",
            "text": importPrompt + (additionalContext.isEmpty ? "" : "\n\nAdditional context: \(additionalContext)")
        ]

        return [
            "role": "user",
            "content": [textContent, imageContent]
        ]
    }

    static func parseImportResult(_ llmOutput: String) -> ScreenshotImportResult {
        var html = ""
        var tokens: [String: String] = [:]
        var components: [String] = []
        var confidence = 0.0

        if let openRange = llmOutput.range(of: "<antArtifact"),
           let closeRange = llmOutput.range(of: "</antArtifact>", range: openRange.upperBound..<llmOutput.endIndex),
           let tagEnd = llmOutput.range(of: ">", range: openRange.lowerBound..<closeRange.lowerBound) {
            html = String(llmOutput[tagEnd.upperBound..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            confidence += 0.5
        }

        if html.isEmpty {
            if let startRange = llmOutput.range(of: "```html\n") {
                let codeStart = startRange.upperBound
                if let endRange = llmOutput.range(of: "```", range: codeStart..<llmOutput.endIndex) {
                    html = String(llmOutput[codeStart..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    confidence += 0.3
                }
            }
        }

        if let jsonStart = llmOutput.range(of: "```json\n"),
           let jsonEnd = llmOutput.range(of: "```", range: jsonStart.upperBound..<llmOutput.endIndex) {
            let jsonStr = String(llmOutput[jsonStart.upperBound..<jsonEnd.lowerBound])
            if let data = jsonStr.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let tokenDict = parsed["tokens"] as? [String: Any] {
                    for (key, value) in tokenDict {
                        if let nested = value as? [String: Any] {
                            for (k, v) in nested { tokens["\(key).\(k)"] = "\(v)" }
                        } else {
                            tokens[key] = "\(value)"
                        }
                    }
                }
                if let compList = parsed["components"] as? [String] {
                    components = compList
                }
                confidence += 0.3
            }
        }

        if confidence == 0 && !html.isEmpty {
            confidence = 0.4
        }

        screenshotLog.info("ScreenshotImporter: parsed — \(html.count) chars HTML, \(tokens.count) tokens, \(components.count) components, confidence=\(confidence)")
        return ScreenshotImportResult(
            extractedHTML: html,
            designTokens: tokens,
            detectedComponents: components,
            confidence: confidence
        )
    }
}
