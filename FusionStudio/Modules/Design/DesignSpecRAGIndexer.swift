import Foundation
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "DesignSpecRAGIndexer")

// 设计规范 RAG 索引：本地 RAGEngine 已移除，ingest 改由 RAGAPIClient（HTTP->fusion-rag）/ DesignBridge.ingestDesignTokens 处理。
// 保留单例与方法签名（兼容潜在调用方），实现降级为日志占位，避免引用已删除的 RAGEngine 类型。
class DesignSpecRAGIndexer {
    static let shared = DesignSpecRAGIndexer()

    private init() {}

    func autoIndexDesignTokens() {
        logger.info("autoIndexDesignTokens: local RAGEngine removed; design token ingest now via DesignBridge.ingestDesignTokens (RAGAPIClient)")
    }

    func autoIndexProjectStyles(projectName: String, styles: [String: String]) {
        logger.info("autoIndexProjectStyles: projectName=\(projectName, privacy: .public) styles=\(styles.count) -> via RAGAPIClient")
    }
}
