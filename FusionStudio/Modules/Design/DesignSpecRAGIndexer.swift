import Foundation
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "DesignSpecRAGIndexer")

class DesignSpecRAGIndexer {
    static let shared = DesignSpecRAGIndexer()

    private init() {}

    func autoIndexDesignTokens() {
        let ragEngine = RAGEngine.shared
        let docId = "design-spec-tokens"
        if ragEngine.documents.contains(where: { $0.id == docId }) {
            logger.info("Design spec tokens already indexed, skipping")
            return
        }

        let content = buildTokenContent()
        let doc = RAGEngine.RAGDocument(
            id: docId,
            title: "设计规范: Token 系统",
            content: content,
            source: "StudioTheme",
            chunkCount: 0,
            indexedAt: nil,
            isIndexed: false
        )
        ragEngine.documents.append(doc)
        ragEngine.indexAll()
        logger.info("Auto-indexed design spec tokens into RAG")
    }

    func autoIndexProjectStyles(projectName: String, styles: [String: String]) {
        let ragEngine = RAGEngine.shared
        let docId = "design-spec-project-\(projectName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        if ragEngine.documents.contains(where: { $0.id == docId }) { return }

        var parts: [String] = []
        parts.append("项目样式规范: \(projectName)")
        for (key, value) in styles.sorted(by: { $0.key < $1.key }) {
            parts.append("\(key): \(value)")
        }

        let doc = RAGEngine.RAGDocument(
            id: docId,
            title: "项目样式: \(projectName)",
            content: parts.joined(separator: "\n"),
            source: "ProjectStyles",
            chunkCount: 0,
            indexedAt: nil,
            isIndexed: false
        )
        ragEngine.documents.append(doc)
        ragEngine.indexAll()
        logger.info("Auto-indexed project styles for '\(projectName)' into RAG")
    }

    private func buildTokenContent() -> String {
        let light = StudioTheme.light
        var parts: [String] = []

        parts.append("# Fusion Studio 设计 Token 规范")
        parts.append("")
        parts.append("## 间距 (Spacing)")
        parts.append("XS: \(light.spacingXS)pt")
        parts.append("S: \(light.spacingS)pt")
        parts.append("M: \(light.spacingM)pt")
        parts.append("L: \(light.spacingL)pt")
        parts.append("XL: \(light.spacingXL)pt")
        parts.append("2XL: \(light.spacing2XL)pt")
        parts.append("")
        parts.append("## 圆角 (Corner Radius)")
        parts.append("Default: \(light.cornerRadius)pt")
        parts.append("Small: \(light.cornerRadiusSmall)pt")
        parts.append("Large: \(light.cornerRadiusLarge)pt")
        parts.append("Row: \(light.rowRadius)pt")
        parts.append("")
        parts.append("## 字号 (Type Scale)")
        parts.append("Caption: \(light.captionSize)pt")
        parts.append("Footnote: \(light.footnoteSize)pt")
        parts.append("Small: \(light.smallTextSize)pt")
        parts.append("Text: \(light.textSize)pt")
        parts.append("Body: \(light.bodySize)pt")
        parts.append("Title: \(light.titleSize)pt")
        parts.append("Headline: \(light.headlineSize)pt")
        parts.append("LargeTitle: \(light.largeTitleSize)pt")
        parts.append("")
        parts.append("## 动画 (Animation)")
        parts.append("Fast: \(light.animationFast)s")
        parts.append("Normal: \(light.animationNormal)s")
        parts.append("Slow: \(light.animationSlow)s")
        parts.append("")
        parts.append("## 图标尺寸 (Icon Size)")
        parts.append("XS: \(light.iconXS)pt, S: \(light.iconS)pt, M: \(light.iconM)pt, L: \(light.iconL)pt, XL: \(light.iconXL)pt")

        return parts.joined(separator: "\n")
    }
}
