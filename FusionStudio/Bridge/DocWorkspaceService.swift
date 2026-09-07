import Foundation
import os.log

// ARCH-1 Phase 2 (audit-product-0907 P2-2): DocWorkspace 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchWorkspaces/createWorkspace/updateWorkspace/deleteWorkspace call site 0 改)。
//   @Published (workspaces/currentWorkspace) 现属 DocWorkspaceState; HTTP 经 bridge?.get/post/put/delete;
//   错误经 bridge?.handleError; LRU cap 经 DocBridge.cap。currentWorkspace 经 computed forward 仍可直写。

private let docWorkspaceLog = Logger(subsystem: "com.fusion.studio", category: "DocWorkspaceService")

extension DocWorkspaceState {

    func fetchWorkspaces(completion: @escaping (Result<[DocWorkspace], Error>) -> Void) {
        docWorkspaceLog.info("fetchWorkspaces")
        bridge?.get("/api/workspaces") { [weak self] (result: Result<[DocWorkspace], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workspaces = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "fetchWorkspaces")
                completion(.failure(error))
            }
        }
    }

    func createWorkspace(name: String, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        docWorkspaceLog.info("createWorkspace: name=\(name)")
        var body: [String: Any] = ["name": name]
        if let desc = description { body["description"] = desc }
        bridge?.post("/api/workspaces", body: body) { [weak self] (result: Result<DocWorkspace, Error>) in
            switch result {
            case .success(let ws):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.workspaces.append(ws)
                    DocBridge.cap(&self.workspaces, 50)
                    self.currentWorkspace = ws
                }
                docWorkspaceLog.info("createWorkspace success: \(ws.id)")
                completion(.success(ws))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createWorkspace")
                completion(.failure(error))
            }
        }
    }

    func updateWorkspace(id: String, name: String? = nil, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        docWorkspaceLog.info("updateWorkspace: id=\(id)")
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let d = description { body["description"] = d }
        bridge?.put("/api/workspaces/\(id)", body: body) { [weak self] (result: Result<DocWorkspace, Error>) in
            switch result {
            case .success(let ws):
                DispatchQueue.main.async {
                    self?.workspaces = self?.workspaces.map { $0.id == ws.id ? ws : $0 } ?? []
                    if self?.currentWorkspace?.id == ws.id { self?.currentWorkspace = ws }
                }
                completion(.success(ws))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "updateWorkspace")
                completion(.failure(error))
            }
        }
    }

    func deleteWorkspace(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docWorkspaceLog.info("deleteWorkspace: id=\(id)")
        bridge?.delete("/api/workspaces/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.workspaces = self?.workspaces.filter { $0.id != id } ?? []
                    if self?.currentWorkspace?.id == id { self?.currentWorkspace = nil }
                }
                completion(.success(resp))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "deleteWorkspace")
                completion(.failure(error))
            }
        }
    }
}

extension DocBridge {

    func fetchWorkspaces(completion: @escaping (Result<[DocWorkspace], Error>) -> Void) {
        workspaceState.fetchWorkspaces(completion: completion)
    }

    func createWorkspace(name: String, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        workspaceState.createWorkspace(name: name, description: description, completion: completion)
    }

    func updateWorkspace(id: String, name: String? = nil, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        workspaceState.updateWorkspace(id: id, name: name, description: description, completion: completion)
    }

    func deleteWorkspace(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        workspaceState.deleteWorkspace(id: id, completion: completion)
    }
}
