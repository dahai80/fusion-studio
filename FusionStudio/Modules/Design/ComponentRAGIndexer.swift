import Foundation
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "ComponentRAGIndexer")

class ComponentRAGIndexer {
    static let shared = ComponentRAGIndexer()

    private init() {}

    func indexDesignComponents() {
        let designSystem = FusionDesignSystem.shared
        let ragEngine = RAGEngine.shared

        var indexed = 0
        for component in designSystem.components {
            let docId = "design-component-\(component.id.uuidString)"
            if ragEngine.documents.contains(where: { $0.id == docId }) { continue }

            let content = buildComponentContent(component)
            let doc = RAGEngine.RAGDocument(
                id: docId,
                title: "组件: \(component.name)",
                content: content,
                source: "FusionDesignSystem",
                chunkCount: 0,
                indexedAt: nil,
                isIndexed: false
            )
            ragEngine.documents.append(doc)
            indexed += 1
        }

        for (template, description) in designSystem.templates {
            let docId = "design-template-\(template.rawValue)"
            if ragEngine.documents.contains(where: { $0.id == docId }) { continue }

            let content = """
            模板: \(template.rawValue)
            描述: \(description)
            类型: 设计模板
            """
            let doc = RAGEngine.RAGDocument(
                id: docId,
                title: "模板: \(template.rawValue)",
                content: content,
                source: "FusionDesignSystem",
                chunkCount: 0,
                indexedAt: nil,
                isIndexed: false
            )
            ragEngine.documents.append(doc)
            indexed += 1
        }

        logger.info("Indexed \(indexed) design documents into RAG")
        ragEngine.indexAll()
    }

    private func buildComponentContent(_ component: DesignComponent) -> String {
        var parts: [String] = []
        parts.append("组件名称: \(component.name)")
        parts.append("分类: \(component.category.rawValue)")
        parts.append("描述: \(component.description)")
        parts.append("变体: \(component.variants.map(\.rawValue).joined(separator: ", "))")
        parts.append("尺寸: \(component.sizes.map(\.displayName).joined(separator: ", "))")
        parts.append("标签: \(component.tags.joined(separator: ", "))")
        parts.append("HTML模板:")
        parts.append(component.htmlTemplate)
        return parts.joined(separator: "\n")
    }
}
