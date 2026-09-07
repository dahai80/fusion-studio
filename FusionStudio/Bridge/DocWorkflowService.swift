import Foundation
import os.log

// ARCH-1 Phase 3 (audit-product-0907 P2-2): DocWorkflow 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   10 method call site 0 改)。@Published (workflows) 现属 DocWorkflowDomainState (重命名避开
//   DocDataModels.swift:223 struct DocWorkflowState: Codable 页面工作流响应模型)。HTTP 经 bridge?.
//   get/post/delete; 错误经 bridge?.handleError; LRU cap 经 DocBridge.cap。本域纯 self.X。

private let docWorkflowLog = Logger(subsystem: "com.fusion.studio", category: "DocWorkflowService")

extension DocWorkflowDomainState {

    func fetchWorkflows() {
        bridge?.get("/api/workflows") { [weak self] (result: Result<[DocWorkflow], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workflows = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "workflows")
            }
        }
    }

    func runWorkflow(id: String, input: [String: Any]? = nil) {
        bridge?.post("/api/workflows/\(id)/run", body: input) { [weak self] (result: Result<DocWorkflowRun, Error>) in
            switch result {
            case .success:
                docWorkflowLog.info("Workflow \(id) started")
            case .failure(let error):
                self?.bridge?.handleError(error, context: "runWorkflow")
            }
        }
    }

    func fetchWorkflowRuns(id: String, completion: @escaping (Result<[DocWorkflowRun], Error>) -> Void) {
        bridge?.get("/api/workflows/\(id)/runs") { result in
            completion(result)
        }
    }

    func createWorkflow(name: String, description: String? = nil, yamlDef: String? = nil, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        var body: [String: Any] = ["name": name]
        if let d = description { body["description"] = d }
        if let y = yamlDef { body["yaml_def"] = y }
        bridge?.post("/api/workflows", body: body) { [weak self] (result: Result<DocWorkflow, Error>) in
            switch result {
            case .success(let wf):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.workflows.append(wf)
                    DocBridge.cap(&self.workflows, 200)
                }
                completion(.success(wf))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createWorkflow")
                completion(.failure(error))
            }
        }
    }

    func deleteWorkflow(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        bridge?.delete("/api/workflows/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.workflows.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "deleteWorkflow")
                completion(.failure(error))
            }
        }
    }

    func fetchWorkflowDetail(id: String, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        bridge?.get("/api/workflows/\(id)", completion: completion)
    }

    func seedWorkflows(completion: @escaping (Result<[DocWorkflow], Error>) -> Void) {
        bridge?.post("/api/workflows/seed", body: nil) { [weak self] (result: Result<[DocWorkflow], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workflows = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "seedWorkflows")
                completion(.failure(error))
            }
        }
    }

    func fetchPageWorkflowStatus(pageId: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        bridge?.get("/api/pages/\(pageId)/workflow-status", completion: completion)
    }

    func fetchPageTransitions(pageId: String, completion: @escaping (Result<[DocWorkflowTransition], Error>) -> Void) {
        bridge?.get("/api/pages/\(pageId)/transitions", completion: completion)
    }

    func executeTransition(pageId: String, transition: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        bridge?.post("/api/pages/\(pageId)/transitions", body: ["transition": transition], completion: completion)
    }
}

extension DocBridge {

    func fetchWorkflows() { workflowState.fetchWorkflows() }

    func runWorkflow(id: String, input: [String: Any]? = nil) {
        workflowState.runWorkflow(id: id, input: input)
    }

    func fetchWorkflowRuns(id: String, completion: @escaping (Result<[DocWorkflowRun], Error>) -> Void) {
        workflowState.fetchWorkflowRuns(id: id, completion: completion)
    }

    func createWorkflow(name: String, description: String? = nil, yamlDef: String? = nil, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        workflowState.createWorkflow(name: name, description: description, yamlDef: yamlDef, completion: completion)
    }

    func deleteWorkflow(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        workflowState.deleteWorkflow(id: id, completion: completion)
    }

    func fetchWorkflowDetail(id: String, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        workflowState.fetchWorkflowDetail(id: id, completion: completion)
    }

    func seedWorkflows(completion: @escaping (Result<[DocWorkflow], Error>) -> Void) {
        workflowState.seedWorkflows(completion: completion)
    }

    func fetchPageWorkflowStatus(pageId: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        workflowState.fetchPageWorkflowStatus(pageId: pageId, completion: completion)
    }

    func fetchPageTransitions(pageId: String, completion: @escaping (Result<[DocWorkflowTransition], Error>) -> Void) {
        workflowState.fetchPageTransitions(pageId: pageId, completion: completion)
    }

    func executeTransition(pageId: String, transition: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        workflowState.executeTransition(pageId: pageId, transition: transition, completion: completion)
    }
}
