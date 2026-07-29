import Foundation
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "ComponentRAGIndexer")

// 设计组件 RAG 索引：本地 RAGEngine 已移除，ingest 改由 RAGAPIClient（HTTP->fusion-rag）处理。
// 保留单例与方法签名（兼容潜在调用方），实现降级为日志占位，避免引用已删除的 RAGEngine 类型。
class ComponentRAGIndexer {
    static let shared = ComponentRAGIndexer()

    private init() {}

    func indexDesignComponents() {
        logger.info("indexDesignComponents: local RAGEngine removed; design component ingest now via RAGAPIClient")
    }
}
