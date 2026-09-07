import Foundation
import os.log

// ARCH-1 Phase 3 (audit-product-0907 P2-2): DocVersion 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchVersions/createVersion/fetchDiff call site 0 改)。@Published (versions) 现属 DocVersionState;
//   restoreVersion 留 DocBridge (协调器: 成功后调 libraryState.fetchPage 回填页面, 跨域写)。

private let docVersionLog = Logger(subsystem: "com.fusion.studio", category: "DocVersionService")

extension DocVersionState {

    func fetchVersions(pageId: String) {
        bridge?.get("/api/pages/\(pageId)/versions") { [weak self] (result: Result<[DocVersion], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.versions = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "versions")
            }
        }
    }

    func createVersion(pageId: String, title: String, content: String) {
        bridge?.post("/api/pages/\(pageId)/versions", body: ["title": title, "content": content]) { [weak self] (result: Result<DocVersion, Error>) in
            switch result {
            case .success(let v):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.versions.append(v)
                    DocBridge.cap(&self.versions, 200)
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createVersion")
            }
        }
    }

    func fetchDiff(pageId: String, v1: Int, v2: Int, completion: @escaping (Result<DocDiffResult, Error>) -> Void) {
        bridge?.get("/api/pages/\(pageId)/diff?v1=\(v1)&v2=\(v2)") { result in
            completion(result)
        }
    }
}

extension DocBridge {

    func fetchVersions(pageId: String) { versionState.fetchVersions(pageId: pageId) }

    func createVersion(pageId: String, title: String, content: String) {
        versionState.createVersion(pageId: pageId, title: title, content: content)
    }

    func fetchDiff(pageId: String, v1: Int, v2: Int, completion: @escaping (Result<DocDiffResult, Error>) -> Void) {
        versionState.fetchDiff(pageId: pageId, v1: v1, v2: v2, completion: completion)
    }
}
