// Callers: DesignChatPanel (screenshot import button), DesignBridge (importScreenshot)
// Affected API: DesignBridge.importScreenshot(_:), ScreenshotImporter.openPanel/batchImport/extractDominantColors
// Data schemas: ScreenshotImportResult (extractedHTML/designTokens/detectedComponents/confidence/dominantColors), NSImage→base64 PNG
// User instruction: "继续实施Phase 6"

import AppKit
import UniformTypeIdentifiers
import os.log

private let screenshotLog = Logger(subsystem: "com.fusion.studio", category: "ScreenshotImporter")

struct ScreenshotImportResult {
    var extractedHTML: String
    var designTokens: [String: String]
    var detectedComponents: [String]
    var confidence: Double
    var dominantColors: [String] = []
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

        let colors = extractDominantColors(from: llmOutput)
        screenshotLog.info("ScreenshotImporter: parsed — \(html.count) chars HTML, \(tokens.count) tokens, \(components.count) components, \(colors.count) colors, confidence=\(confidence)")
        return ScreenshotImportResult(
            extractedHTML: html,
            designTokens: tokens,
            detectedComponents: components,
            confidence: confidence,
            dominantColors: colors
        )
    }

    static func openPanel() -> [NSImage] {
        let panel = NSOpenPanel()
        panel.title = "选择截图文件"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif, .webP]
        guard panel.runModal() == .OK else { return [] }
        var images: [NSImage] = []
        for url in panel.urls {
            if let img = NSImage(contentsOf: url) {
                images.append(img)
            }
        }
        screenshotLog.info("ScreenshotImporter: openPanel selected \(images.count) images")
        return images
    }

    static func batchImport(images: [NSImage], additionalContext: String = "") -> [ScreenshotImportResult] {
        images.compactMap { img in
            guard let req = buildImportRequest(image: img, additionalContext: additionalContext) else { return nil }
            return ScreenshotImportResult(
                extractedHTML: "",
                designTokens: [:],
                detectedComponents: [],
                confidence: 0,
                dominantColors: extractDominantColors(fromImage: img)
            )
        }
    }

    static func extractDominantColors(from llmOutput: String) -> [String] {
        var colors: [String] = []
        let hexPattern = try? NSRegularExpression(pattern: "#[0-9a-fA-F]{6}")
        if let regex = hexPattern {
            let range = NSRange(llmOutput.startIndex..., in: llmOutput)
            for match in regex.matches(in: llmOutput, range: range) {
                if let r = Range(match.range, in: llmOutput) {
                    let hex = String(llmOutput[r])
                    if !colors.contains(hex) { colors.append(hex) }
                }
            }
        }
        return Array(colors.prefix(8))
    }

    static func extractDominantColors(fromImage image: NSImage) -> [String] {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return [] }
        var colorCounts: [String: Int] = [:]
        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh
        let step = max(1, min(w, h) / 20)
        for x in stride(from: 0, to: w, by: step) {
            for y in stride(from: 0, to: h, by: step) {
                if let color = bitmap.colorAt(x: x, y: y) {
                    let r = Int(color.redComponent * 255)
                    let g = Int(color.greenComponent * 255)
                    let b = Int(color.blueComponent * 255)
                    let qr = (r / 32) * 32
                    let qg = (g / 32) * 32
                    let qb = (b / 32) * 32
                    let hex = String(format: "#%02X%02X%02X", qr, qg, qb)
                    colorCounts[hex, default: 0] += 1
                }
            }
        }
        let sorted = colorCounts.sorted { $0.value > $1.value }
        let results = sorted.prefix(8).map { $0.key }
        screenshotLog.info("ScreenshotImporter: extracted \(results.count) dominant colors from image")
        return results
    }
}
