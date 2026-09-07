import Foundation
import os.log

// ARCH-1 Phase 4 (audit-product-0907 P2-2): DocGraph 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchGraph/addPageLink/graphSemanticSearch/graphTraverse/graphCluster/fetchGraphNode call site 0 改)。
//   @Published (graph) 现属 DocGraphState (fetchGraph 直写 self.graph); addPageLink 虽在 MARK Links 下
//   但属本域 (页面链接 = 图边)。HTTP 经 bridge?.get/post; 错误经 bridge?.handleError。

private let docGraphLog = Logger(subsystem: "com.fusion.studio", category: "DocGraphService")

extension DocGraphState {

    func fetchGraph() {
        bridge?.get("/api/graph") { [weak self] (result: Result<DocGraph, Error>) in
            switch result {
            case .success(let g):
                DispatchQueue.main.async { self?.graph = g }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "graph")
            }
        }
    }

    func addPageLink(sourceId: String, targetId: String, linkType: String = "reference") {
        struct LinkResp: Decodable { var id: String? }
        bridge?.post("/api/pages/\(sourceId)/links", body: ["target_page_id": targetId, "link_type": linkType]) { [weak self] (result: Result<LinkResp, Error>) in
            switch result {
            case .success:
                docGraphLog.info("Link added: \(sourceId) -> \(targetId)")
            case .failure(let error):
                self?.bridge?.handleError(error, context: "addLink")
            }
        }
    }

    func graphSemanticSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        docGraphLog.info("graphSemanticSearch: query=\(query.prefix(50))")
        bridge?.post("/api/graph/search", body: ["query": query], completion: completion)
    }

    func graphTraverse(startId: String, direction: String = "both", maxDepth: Int = 3, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        docGraphLog.info("graphTraverse: start=\(startId) depth=\(maxDepth)")
        bridge?.post("/api/graph/traverse", body: ["start_id": startId, "direction": direction, "max_depth": maxDepth], completion: completion)
    }

    func graphCluster(algorithm: String = "louvain", completion: @escaping (Result<[String: [[String]]], Error>) -> Void) {
        docGraphLog.info("graphCluster: algorithm=\(algorithm)")
        bridge?.post("/api/graph/cluster", body: ["algorithm": algorithm], completion: completion)
    }

    func fetchGraphNode(id: String, completion: @escaping (Result<DocGraphNode, Error>) -> Void) {
        bridge?.get("/api/graph/\(id)", completion: completion)
    }
}

extension DocBridge {

    func fetchGraph() { graphState.fetchGraph() }

    func addPageLink(sourceId: String, targetId: String, linkType: String = "reference") {
        graphState.addPageLink(sourceId: sourceId, targetId: targetId, linkType: linkType)
    }

    func graphSemanticSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        graphState.graphSemanticSearch(query: query, completion: completion)
    }

    func graphTraverse(startId: String, direction: String = "both", maxDepth: Int = 3, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        graphState.graphTraverse(startId: startId, direction: direction, maxDepth: maxDepth, completion: completion)
    }

    func graphCluster(algorithm: String = "louvain", completion: @escaping (Result<[String: [[String]]], Error>) -> Void) {
        graphState.graphCluster(algorithm: algorithm, completion: completion)
    }

    func fetchGraphNode(id: String, completion: @escaping (Result<DocGraphNode, Error>) -> Void) {
        graphState.fetchGraphNode(id: id, completion: completion)
    }
}
